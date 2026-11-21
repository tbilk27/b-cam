import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  debug('DEBUG', '🔍'),
  info('INFO', 'ℹ️'),
  warn('WARN', '⚠️'),
  error('ERROR', '❌');

  final String label;
  final String emoji;
  const LogLevel(this.label, this.emoji);
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final String? details;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.details,
  });

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String toFormattedString() {
    final buffer = StringBuffer('[$timeFormatted] [${level.label}] [$category] $message');
    if (details != null && details!.isNotEmpty) {
      buffer.write('\n    ↳ Detalhes: $details');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.label,
    'category': category,
    'message': message,
    'details': details,
  };
}

class DiagnosticLoggerService extends ChangeNotifier {
  static final DiagnosticLoggerService instance = DiagnosticLoggerService._internal();

  DiagnosticLoggerService._internal() {
    _initFileLogger();
    _startHttpDiagnosticServer();
  }

  static const int maxMemoryEntries = 1500;
  static const int diagnosticHttpPort = 8089;

  final List<LogEntry> _entries = [];
  List<LogEntry> get entries => List.unmodifiable(_entries);

  File? _logFile;
  String? _cachedFilePath;
  String? get logFilePath => _cachedFilePath;

  HttpServer? _httpServer;
  String _deviceIp = 'Iniciando...';
  String get deviceIp => _deviceIp;

  bool _isHttpServerRunning = false;
  bool get isHttpServerRunning => _isHttpServerRunning;

  Future<void> _initFileLogger() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/b_cam_diagnostic.log');
      _cachedFilePath = _logFile!.path;

      // If file doesn't exist, create it with header
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
        await _logFile!.writeAsString(
          '=== B-CAM DIAGNOSTIC LOG SESSION INICIADA EM ${DateTime.now().toIso8601String()} ===\n',
        );
      } else {
        // Truncate if file > 5MB to prevent storage bloat
        final len = await _logFile!.length();
        if (len > 5 * 1024 * 1024) {
          await _logFile!.writeAsString(
            '=== LOG TRUNCADO (EXCEDEU 5MB) - NOVA SESSÃO ${DateTime.now().toIso8601String()} ===\n',
          );
        }
      }
    } catch (e) {
      debugPrint('Falha ao inicializar arquivo de log: $e');
    }
  }

  Future<void> _startHttpDiagnosticServer() async {
    try {
      // Find local IP
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.address.startsWith('169.254.')) {
            _deviceIp = addr.address;
            break;
          }
        }
      }

      _httpServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        diagnosticHttpPort,
        shared: true,
      );
      _isHttpServerRunning = true;
      notifyListeners();

      _httpServer!.listen(_handleHttpRequest);
      logInfo(
        'SYSTEM',
        'Servidor HTTP de diagnósticos ouvindo em http://$_deviceIp:$diagnosticHttpPort',
      );
    } catch (e) {
      logWarn('SYSTEM', 'Não foi possível iniciar servidor HTTP de diagnósticos: $e');
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }

    final path = request.uri.path;

    if (path == '/api/logs' || path == '/logs') {
      response.headers.contentType = ContentType.text;
      final fullLog = getFullLogText();
      response.write(fullLog);
      await response.close();
      return;
    }

    if (path == '/api/logs.json') {
      response.headers.contentType = ContentType.json;
      final jsonList = _entries.map((e) => e.toJson()).toList();
      response.write(jsonEncode(jsonList));
      await response.close();
      return;
    }

    if (path == '/api/clear' && request.method == 'POST') {
      await clearLogs();
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({'success': true, 'message': 'Logs limpos'}));
      await response.close();
      return;
    }

    if (path == '/api/status' || path == '/') {
      response.headers.contentType = ContentType.json;
      final status = {
        'app': 'b-cam',
        'status': 'online',
        'deviceIp': _deviceIp,
        'entriesCount': _entries.length,
        'logFilePath': _cachedFilePath,
        'currentTime': DateTime.now().toIso8601String(),
        'endpoints': {
          'textLogs': '/api/logs',
          'jsonLogs': '/api/logs.json',
          'clear': '/api/clear (POST)',
        },
      };
      response.write(jsonEncode(status));
      await response.close();
      return;
    }

    response.statusCode = HttpStatus.notFound;
    response.write('Endpoint não encontrado');
    await response.close();
  }

  Timer? _notifyThrottleTimer;

  void _scheduleThrottledNotify() {
    if (!hasListeners) return;
    if (_notifyThrottleTimer != null && _notifyThrottleTimer!.isActive) {
      return;
    }
    _notifyThrottleTimer = Timer(const Duration(milliseconds: 300), () {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  void log({
    required LogLevel level,
    required String category,
    required String message,
    String? details,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      details: details,
    );

    _entries.add(entry);
    if (_entries.length > maxMemoryEntries) {
      _entries.removeRange(0, _entries.length - maxMemoryEntries);
    }

    _scheduleThrottledNotify();

    // Async write to file
    _writeToFile(entry);
  }

  void logInfo(String category, String message, {String? details}) {
    log(level: LogLevel.info, category: category, message: message, details: details);
  }

  void logDebug(String category, String message, {String? details}) {
    log(level: LogLevel.debug, category: category, message: message, details: details);
  }

  void logWarn(String category, String message, {String? details}) {
    log(level: LogLevel.warn, category: category, message: message, details: details);
  }

  void logError(String category, String message, {dynamic error, StackTrace? stackTrace, String? details}) {
    final fullDetails = StringBuffer();
    if (details != null) fullDetails.writeln(details);
    if (error != null) fullDetails.writeln('Erro: $error');
    if (stackTrace != null) fullDetails.writeln('StackTrace: $stackTrace');

    log(
      level: LogLevel.error,
      category: category,
      message: message,
      details: fullDetails.isNotEmpty ? fullDetails.toString().trim() : null,
    );
  }

  Future<void> _writeToFile(LogEntry entry) async {
    try {
      if (_logFile != null) {
        await _logFile!.writeAsString(
          '${entry.toFormattedString()}\n',
          mode: FileMode.append,
          flush: false,
        );
      }
    } catch (e) {
      debugPrint('Erro ao persistir log: $e');
    }
  }

  String getFullLogText() {
    return _entries.map((e) => e.toFormattedString()).join('\n');
  }

  Future<void> clearLogs() async {
    _entries.clear();
    notifyListeners();
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString(
          '=== LOGS LIMPOS EM ${DateTime.now().toIso8601String()} ===\n',
        );
      }
    } catch (_) {}
  }

  static const MethodChannel _platformChannel = MethodChannel('com.nexeoo.bcam/deeplink');

  /// Envia o arquivo de log para o WhatsApp do suporte (47 98836-6727)
  Future<bool> sendLogViaWhatsApp({
    String phone = '5547988366727',
    String? customMessage,
  }) async {
    try {
      final path = _logFile?.path;
      final timeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
      final msg = customMessage ??
          'Olá! Segue em anexo o arquivo de log de diagnóstico do app b-cam (${_entries.length} eventos registrados em $timeStr).';

      final res = await _platformChannel.invokeMethod<bool>('shareLogViaWhatsApp', {
        'filePath': path,
        'phone': phone,
        'message': msg,
      });

      logInfo('TELEMETRY', 'Solicitação de envio do arquivo de log via WhatsApp para $phone concluída.');
      return res ?? true;
    } catch (e) {
      logError('TELEMETRY', 'Erro ao enviar arquivo de log via WhatsApp: $e');
      return false;
    }
  }

  /// Sends collected logs to host Mac development environment if reachable
  Future<bool> sendLogsToHostMac({String hostIp = '192.168.3.62', int hostPort = 8088}) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.post(hostIp, hostPort, '/api/logs');
      request.headers.contentType = ContentType.text;
      request.write(getFullLogText());
      final response = await request.close();
      return response.statusCode == HttpStatus.ok;
    } catch (e) {
      logWarn('TELEMETRY', 'Host Mac em $hostIp:$hostPort não respondeu: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _httpServer?.close(force: true);
    super.dispose();
  }
}
