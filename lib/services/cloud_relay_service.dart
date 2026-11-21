import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/camera_device.dart';
import 'diagnostic_logger_service.dart';

/// Modo de conexão de rede para câmeras de vigilância
enum CloudNetworkMode {
  /// Roteamento inteligente: usa LAN direta quando em casa; roteia via Cloud Relay no 4G/5G ou fora
  auto,

  /// Força todo o tráfego a passar pela infraestrutura Google Cloud / Firebase Relay
  alwaysCloud,

  /// Apenas conexões diretas na rede local Wi-Fi (sem tráfego externo)
  localOnly,
}

/// Serviço de Roteamento e Comunicação em Nuvem (Google Cloud / Firebase Relay)
/// Garante que o usuário consiga acessar câmeras fora da rede local (4G/5G ou Wi-Fi externo)
class CloudRelayService extends ChangeNotifier {
  static final CloudRelayService instance = CloudRelayService._internal();

  CloudRelayService._internal();

  /// Endpoint padrão da infraestrutura de Cloud Relay (Google Cloud / Firebase Hosting)
  static const String defaultCloudGatewayHost = 'cloud.bilkcam.web.app';
  static const int defaultCloudGatewayPort = 8554;

  /// Cache de status de conectividade local por IP da câmera (IP -> DateTime da última verificação)
  final Map<String, bool> _localReachabilityCache = {};
  final Map<String, DateTime> _lastCheckTime = {};

  /// Modo de operação global ou preferencial
  CloudNetworkMode _globalMode = CloudNetworkMode.auto;
  CloudNetworkMode get globalMode => _globalMode;

  void setGlobalMode(CloudNetworkMode mode) {
    if (_globalMode != mode) {
      _globalMode = mode;
      DiagnosticLoggerService.instance.logInfo(
        'CLOUD_RELAY',
        'Modo de rede alterado para: ${mode.name.toUpperCase()}',
      );
      notifyListeners();
    }
  }

  /// Verifica se uma câmera está acessível na rede local ou se deve rotear via Nuvem
  Future<bool> isCameraLocallyReachable(CameraDevice camera) async {
    // Se o modo da câmera ou global for 'alwaysCloud', nunca tenta LAN direta
    if (camera.remoteAccessMode == 'remote' || _globalMode == CloudNetworkMode.alwaysCloud) {
      return false;
    }

    // Se for 'localOnly', sempre considera local
    if (camera.remoteAccessMode == 'local' || _globalMode == CloudNetworkMode.localOnly) {
      return true;
    }

    final now = DateTime.now();
    final lastCheck = _lastCheckTime[camera.ip];
    if (lastCheck != null && now.difference(lastCheck).inSeconds < 25) {
      return _localReachabilityCache[camera.ip] ?? false;
    }

    // Teste de handshake TCP rápido no IP e porta local da câmera (timeout de 1200ms)
    bool isReachable = false;
    try {
      final socket = await Socket.connect(
        camera.ip,
        camera.rtspPort,
        timeout: const Duration(milliseconds: 1200),
      );
      socket.destroy();
      isReachable = true;
    } catch (_) {
      isReachable = false;
    }

    _localReachabilityCache[camera.ip] = isReachable;
    _lastCheckTime[camera.ip] = now;

    if (!isReachable) {
      DiagnosticLoggerService.instance.logInfo(
        'CLOUD_RELAY',
        'Câmera "${camera.name}" (${camera.ip}) inacessível na LAN local. Roteando via Cloud Relay.',
      );
    }

    return isReachable;
  }

  /// Determina se a câmera deve utilizar a infraestrutura de Cloud para a conexão atual
  bool shouldRouteThroughCloud(CameraDevice camera, {bool isLocalReachable = true}) {
    if (camera.remoteAccessMode == 'remote' || _globalMode == CloudNetworkMode.alwaysCloud) {
      return true;
    }
    if (camera.remoteAccessMode == 'local' || _globalMode == CloudNetworkMode.localOnly) {
      return false;
    }
    // No modo auto: se não alcança a rede local, usa a nuvem
    return !isLocalReachable;
  }

  /// Resolve o host remoto / cloud de saída para a câmera
  String resolveCloudHost(CameraDevice camera) {
    if (camera.remoteHost != null && camera.remoteHost!.trim().isNotEmpty) {
      return camera.remoteHost!.trim();
    }
    return defaultCloudGatewayHost;
  }

  /// Resolve a porta remota / cloud de saída para a câmera
  int resolveCloudPort(CameraDevice camera) {
    if (camera.remoteRtspPort != null && camera.remoteRtspPort! > 0) {
      return camera.remoteRtspPort!;
    }
    return defaultCloudGatewayPort;
  }

  /// Constrói o fluxo RTSP roteado pela infraestrutura Cloud Relay
  String buildCloudStreamUrl(CameraDevice camera) {
    final host = resolveCloudHost(camera);
    final port = resolveCloudPort(camera);

    return camera.manufacturer.buildRtspUrl(
      ip: host,
      port: port,
      user: camera.username,
      password: camera.password,
      channel: camera.channel,
      subType: camera.subType,
      customPath: camera.customPath,
    );
  }

  /// URL de exibição com senha mascarada para o fluxo em nuvem
  String buildMaskedCloudStreamUrl(CameraDevice camera) {
    final host = resolveCloudHost(camera);
    final port = resolveCloudPort(camera);

    return camera.manufacturer.buildRtspUrl(
      ip: host,
      port: port,
      user: camera.username,
      password: camera.password.isNotEmpty ? '******' : '',
      channel: camera.channel,
      subType: camera.subType,
      customPath: camera.customPath,
    );
  }

  /// Força revalidação do cache de conectividade de uma câmera
  void invalidateCameraCache(String ip) {
    _localReachabilityCache.remove(ip);
    _lastCheckTime.remove(ip);
  }

  /// Limpa todo o cache de conectividade de rede
  void clearAllCache() {
    _localReachabilityCache.clear;
    _lastCheckTime.clear();
    notifyListeners();
  }
}
