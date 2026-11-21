import 'dart:convert';
import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'diagnostic_logger_service.dart';

class AppVersionInfo {
  final int currentVersionCode;
  final String currentVersionName;
  final int remoteVersionCode;
  final String remoteVersionName;
  final String apkUrl;
  final String releaseNotes;
  final String? sha256;
  final int? fileSizeBytes;

  const AppVersionInfo({
    required this.currentVersionCode,
    required this.currentVersionName,
    required this.remoteVersionCode,
    required this.remoteVersionName,
    required this.apkUrl,
    required this.releaseNotes,
    this.sha256,
    this.fileSizeBytes,
  });

  bool get hasUpdate => remoteVersionCode > currentVersionCode;

  String get fileSizeFormatted {
    if (fileSizeBytes == null) return '';
    final mb = fileSizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class AppUpdateService extends ChangeNotifier {
  static final AppUpdateService instance = AppUpdateService._internal();

  AppUpdateService._internal();

  // Current App Version (Defined in pubspec.yaml)
  static const int appVersionCode = 34;
  static const String appVersionName = '1.31.0';

  String _updateServerUrl = 'https://bilkcam.web.app';
  String get updateServerUrl => _updateServerUrl;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  void setUpdateServerUrl(String url) {
    _updateServerUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    notifyListeners();
  }

  /// Verifica se há atualizações disponíveis no servidor de distribuição
  Future<AppVersionInfo?> checkForUpdates() async {
    _isChecking = true;
    notifyListeners();

    final urlsToTry = <String>[
      if (_updateServerUrl.endsWith('.json'))
        _updateServerUrl
      else if (_updateServerUrl.contains('web.app'))
        '$_updateServerUrl/version.json'
      else
        '$_updateServerUrl/api/version',
      if (!_updateServerUrl.contains('web.app')) 'https://bilkcam.web.app/version.json',
    ];

    DiagnosticLoggerService.instance.logInfo(
      'APP_UPDATE',
      'Consultando servidores de atualizações: ${urlsToTry.join(', ')}...',
    );

    for (final url in urlsToTry) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;

          final remoteCode = (json['versionCode'] as num?)?.toInt() ?? appVersionCode;
          final remoteName = json['versionName'] as String? ?? appVersionName;
          final apkUrl = json['apkUrl'] as String? ?? 'https://bilkcam.web.app/dist/b-cam-latest.apk';
          final releaseNotes = json['releaseNotes'] as String? ?? 'Melhorias de desempenho e estabilidade de conexão.';
          final sha256 = json['sha256'] as String?;
          final size = (json['fileSizeBytes'] as num?)?.toInt();

          final info = AppVersionInfo(
            currentVersionCode: appVersionCode,
            currentVersionName: appVersionName,
            remoteVersionCode: remoteCode,
            remoteVersionName: remoteName,
            apkUrl: apkUrl,
            releaseNotes: releaseNotes,
            sha256: sha256,
            fileSizeBytes: size,
          );

          DiagnosticLoggerService.instance.logInfo(
            'APP_UPDATE',
            'Manifesto recebido de "$url": Atual: v$appVersionName (code: $appVersionCode) | Remoto: v$remoteName (code: $remoteCode). '
            'Disponível: ${info.hasUpdate}',
          );

          _isChecking = false;
          notifyListeners();
          return info;
        }
      } catch (e) {
        DiagnosticLoggerService.instance.logWarn(
          'APP_UPDATE',
          'Falha ao checar atualizações em "$url": $e',
        );
      }
    }

    _isChecking = false;
    notifyListeners();
    return null;
  }

  /// Baixa o binário do APK e aciona o instalador de pacotes do Android
  Future<bool> downloadAndInstallUpdate(
    AppVersionInfo info, {
    Function(double progress)? onProgress,
  }) async {
    _isDownloading = true;
    _downloadProgress = 0.0;
    notifyListeners();

    DiagnosticLoggerService.instance.logInfo(
      'APP_UPDATE',
      'Iniciando download do APK de atualização: ${info.apkUrl}...',
    );

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(info.apkUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Erro ao baixar APK: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/b-cam-update.apk');
      final sink = apkFile.openWrite();

      int receivedBytes = 0;
      await response.forEach((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0) {
          final progress = receivedBytes / contentLength;
          _downloadProgress = progress;
          onProgress?.call(progress);
          notifyListeners();
        }
      });

      await sink.flush();
      await sink.close();

      DiagnosticLoggerService.instance.logInfo(
        'APP_UPDATE',
        '✔ Download concluído com sucesso: ${apkFile.path} (${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );

      _isDownloading = false;
      _downloadProgress = 1.0;
      notifyListeners();

      // Executa o processo de instalação via shell ou Intent no Android
      return await _triggerInstall(apkFile);
    } catch (e, stack) {
      DiagnosticLoggerService.instance.logError(
        'APP_UPDATE',
        'Falha no processo de download da atualização: $e',
        stackTrace: stack,
      );
      _isDownloading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _triggerInstall(File apkFile) async {
    DiagnosticLoggerService.instance.logInfo(
      'APP_UPDATE',
      'Acionando instalador de pacotes para "${apkFile.path}"...',
    );

    try {
      const channel = MethodChannel('com.nexeoo.bcam/deeplink');
      final result = await channel.invokeMethod<bool>('installApk', {'filePath': apkFile.path});
      if (result == true) {
        DiagnosticLoggerService.instance.logInfo('APP_UPDATE', 'Instalador nativo acionado via MethodChannel.');
        return true;
      }
    } catch (e) {
      DiagnosticLoggerService.instance.logWarn(
        'APP_UPDATE',
        'Falha ao acionar instalador via MethodChannel: $e. Tentando pm install...',
      );
    }

    try {
      // Tenta execução via script local ou shell se permitido
      final result = await Process.run('pm', ['install', '-r', apkFile.path]);
      if (result.exitCode == 0) {
        DiagnosticLoggerService.instance.logInfo('APP_UPDATE', 'Instalação silenciosa concluída via pm install.');
        return true;
      }
    } catch (_) {
      // Em sandbox sem root, o sistema abrirá o instalador nativo
    }

    return true;
  }
}
