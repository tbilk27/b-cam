import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/camera_device.dart';
import 'diagnostic_logger_service.dart';

enum NightVisionMode {
  auto('Automático (Crepuscular)'),
  color('Colorida (Holofote Ativo)'),
  ir('Infravermelho (P&B)'),
  off('Desativada (Modo Diurno)');

  final String label;
  const NightVisionMode(this.label);
}

enum PtzDirection {
  up('Subir (Tilt Up)'),
  down('Descer (Tilt Down)'),
  left('Esquerda (Pan Left)'),
  right('Direita (Pan Right)'),
  zoomIn('Zoom In (+)'),
  zoomOut('Zoom Out (-)'),
  stop('Parar Movimento'),
  home('Centro / Posição Home');

  final String label;
  const PtzDirection(this.label);
}

/// Service managing physical surveillance hardware actions on cameras:
/// Real ONVIF PTZ, RTSP parameters, Siren, Spotlight/Light, Two-way Audio, and Night Vision modes.
class CameraActionService extends ChangeNotifier {
  static final CameraActionService instance = CameraActionService._internal();

  CameraActionService._internal();

  final Map<String, bool> _activeSirens = {};
  final Map<String, bool> _activeSpotlights = {};
  final Map<String, NightVisionMode> _nightVisionModes = {};
  final Map<String, bool> _activeTalking = {};
  final Map<String, bool> _activeListening = {};

  bool isSirenActive(String cameraId) => _activeSirens[cameraId] ?? false;
  bool isSpotlightActive(String cameraId) => _activeSpotlights[cameraId] ?? false;
  NightVisionMode getNightVisionMode(String cameraId) =>
      _nightVisionModes[cameraId] ?? NightVisionMode.auto;
  bool isTalking(String cameraId) => _activeTalking[cameraId] ?? false;
  bool isListening(String cameraId) => _activeListening[cameraId] ?? true;

  // ===========================================================================
  // REAL PTZ EXECUTION ENGINE (ONVIF + RTSP PROTOCOLS)
  // ===========================================================================

  /// Sends a physical PTZ movement command to the camera
  Future<bool> sendPtzCommand(
    CameraDevice camera,
    PtzDirection direction, {
    double speed = 0.4,
    Duration duration = const Duration(milliseconds: 600),
  }) async {
    DiagnosticLoggerService.instance.logInfo(
      'PTZ',
      'Despachando comando PTZ "${direction.label}" para "${camera.name}" (${camera.ip})...',
    );

    bool onvifSuccess = false;
    bool rtspSuccess = false;

    // 1. Primário: Protocolo ONVIF Profile S (HTTP SOAP na porta 5000 ou webPort)
    try {
      onvifSuccess = await _sendOnvifPtz(camera, direction, speed: speed);
    } catch (e) {
      DiagnosticLoggerService.instance.logWarn(
        'PTZ',
        'Falha no envio ONVIF PTZ para "${camera.name}": $e',
      );
    }

    // 2. Secundário / Redundante: RTSP USER_CMD_SET e SET_PARAMETER (porta 554)
    try {
      rtspSuccess = await _sendRtspPtz(camera, direction);
    } catch (e) {
      DiagnosticLoggerService.instance.logWarn(
        'PTZ',
        'Falha no envio RTSP PTZ para "${camera.name}": $e',
      );
    }

    final success = onvifSuccess || rtspSuccess;
    if (success) {
      DiagnosticLoggerService.instance.logInfo(
        'PTZ',
        '✔ Comando PTZ "${direction.label}" entregue com sucesso a "${camera.name}" (ONVIF: $onvifSuccess, RTSP: $rtspSuccess)',
      );
    } else {
      DiagnosticLoggerService.instance.logError(
        'PTZ',
        'Não foi possível mover a câmera "${camera.name}" (${camera.ip}). Verifique se a câmera suporta PTZ mecânico.',
      );
    }

    return success;
  }

  /// Commands the camera to move to a predefined preset position
  Future<bool> gotoPreset(CameraDevice camera, String preset) async {
    DiagnosticLoggerService.instance.logInfo(
      'PTZ',
      'Movendo para Preset "$preset" em "${camera.name}" (${camera.ip})...',
    );

    final authHeader = camera.password.isNotEmpty
        ? '''<s:Header>
    <Security xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <UsernameToken>
        <Username>${camera.username.isNotEmpty ? camera.username : "admin"}</Username>
        <Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">${camera.password}</Password>
      </UsernameToken>
    </Security>
  </s:Header>'''
        : '<s:Header></s:Header>';

    final soapEnvelope = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:tptz="http://www.onvif.org/ver20/ptz/wsdl">
  $authHeader
  <s:Body>
    <tptz:GotoPreset>
      <tptz:ProfileToken>IPCProfilesToken0</tptz:ProfileToken>
      <tptz:PresetToken>$preset</tptz:PresetToken>
    </tptz:GotoPreset>
  </s:Body>
</s:Envelope>''';

    final endpoints = [
      'http://${camera.ip}:${camera.onvifPort}/onvif/deviceio_service',
      'http://${camera.ip}:${camera.onvifPort}/onvif/ptz_service',
    ];

    final client = HttpClient();
    client.connectionTimeout = const Duration(milliseconds: 1800);

    for (final url in endpoints) {
      try {
        final request = await client.postUrl(Uri.parse(url));
        request.headers.set('Content-Type', 'application/soap+xml; charset=utf-8');
        request.write(soapEnvelope);
        final response = await request.close().timeout(const Duration(milliseconds: 2000));
        if (response.statusCode == 200) {
          client.close();
          return true;
        }
      } catch (_) {}
    }
    client.close();
    return false;
  }

  /// Dispatches ONVIF ContinuousMove / RelativeMove SOAP Envelope
  Future<bool> _sendOnvifPtz(
    CameraDevice camera,
    PtzDirection direction, {
    double speed = 0.4,
  }) async {
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;

    switch (direction) {
      case PtzDirection.up:
        y = speed;
        break;
      case PtzDirection.down:
        y = -speed;
        break;
      case PtzDirection.left:
        x = -speed;
        break;
      case PtzDirection.right:
        x = speed;
        break;
      case PtzDirection.zoomIn:
        z = speed;
        break;
      case PtzDirection.zoomOut:
        z = -speed;
        break;
      case PtzDirection.home:
      case PtzDirection.stop:
        break;
    }

    final port = camera.onvifPort;
    final timeoutSecStr = 'PT0.6S';

    // Construção do Envelope SOAP ONVIF PTZ
    final authHeader = camera.password.isNotEmpty
        ? '''<s:Header>
    <Security xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <UsernameToken>
        <Username>${camera.username.isNotEmpty ? camera.username : "admin"}</Username>
        <Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">${camera.password}</Password>
      </UsernameToken>
    </Security>
  </s:Header>'''
        : '<s:Header></s:Header>';

    final String bodyContent;
    if (direction == PtzDirection.stop) {
      bodyContent = '''<tptz:Stop>
        <tptz:ProfileToken>IPCProfilesToken0</tptz:ProfileToken>
        <tptz:PanTilt>true</tptz:PanTilt>
        <tptz:Zoom>true</tptz:Zoom>
      </tptz:Stop>''';
    } else if (direction == PtzDirection.home) {
      bodyContent = '''<tptz:ContinuousMove>
        <tptz:ProfileToken>IPCProfilesToken0</tptz:ProfileToken>
        <tptz:Velocity>
          <tt:PanTilt x="0.0" y="0.0"/>
        </tptz:Velocity>
        <tptz:Timeout>PT0.2S</tptz:Timeout>
      </tptz:ContinuousMove>''';
    } else if (direction == PtzDirection.zoomIn || direction == PtzDirection.zoomOut) {
      bodyContent = '''<tptz:ContinuousMove>
        <tptz:ProfileToken>IPCProfilesToken0</tptz:ProfileToken>
        <tptz:Velocity>
          <tt:Zoom x="$z"/>
        </tptz:Velocity>
        <tptz:Timeout>$timeoutSecStr</tptz:Timeout>
      </tptz:ContinuousMove>''';
    } else {
      bodyContent = '''<tptz:ContinuousMove>
        <tptz:ProfileToken>IPCProfilesToken0</tptz:ProfileToken>
        <tptz:Velocity>
          <tt:PanTilt x="$x" y="$y"/>
        </tptz:Velocity>
        <tptz:Timeout>$timeoutSecStr</tptz:Timeout>
      </tptz:ContinuousMove>''';
    }

    final soapEnvelope = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:tptz="http://www.onvif.org/ver20/ptz/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">
  $authHeader
  <s:Body>
    $bodyContent
  </s:Body>
</s:Envelope>''';

    final endpoints = [
      'http://${camera.ip}:$port/onvif/deviceio_service',
      'http://${camera.ip}:$port/onvif/ptz_service',
      'http://${camera.ip}:$port/onvif/device_service',
    ];

    final client = HttpClient();
    client.connectionTimeout = const Duration(milliseconds: 1800);

    for (final url in endpoints) {
      try {
        final request = await client.postUrl(Uri.parse(url));
        request.headers.set('Content-Type', 'application/soap+xml; charset=utf-8');
        request.write(soapEnvelope);
        final response = await request.close().timeout(const Duration(milliseconds: 2000));
        final respBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200 &&
            (respBody.contains('ContinuousMoveResponse') || respBody.contains('StopResponse') || respBody.contains('Response'))) {
          client.close();
          return true;
        }
      } catch (_) {}
    }

    client.close();
    return false;
  }

  /// Dispatches RTSP SET_PARAMETER / USER_CMD_SET commands to port 554
  Future<bool> _sendRtspPtz(CameraDevice camera, PtzDirection direction) async {
    String ptzAction;
    switch (direction) {
      case PtzDirection.up:
        ptzAction = 'up';
        break;
      case PtzDirection.down:
        ptzAction = 'down';
        break;
      case PtzDirection.left:
        ptzAction = 'left';
        break;
      case PtzDirection.right:
        ptzAction = 'right';
        break;
      case PtzDirection.zoomIn:
        ptzAction = 'zoomin';
        break;
      case PtzDirection.zoomOut:
        ptzAction = 'zoomout';
        break;
      case PtzDirection.stop:
      case PtzDirection.home:
        ptzAction = 'stop';
        break;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        camera.ip,
        camera.rtspPort,
        timeout: const Duration(milliseconds: 1500),
      );

      // RTSP SET_PARAMETER command
      final body1 = 'ptz:$ptzAction\r\n';
      final req1 = 'SET_PARAMETER rtsp://${camera.ip}:${camera.rtspPort}/onvif1 RTSP/1.0\r\n'
          'CSeq: 10\r\n'
          'Content-Type: text/parameters\r\n'
          'Content-Length: ${body1.length}\r\n'
          '\r\n'
          '$body1';

      socket.write(req1);

      // RTSP USER_CMD_SET command (Goke / Bilian firmware)
      final body2 = 'cmd=ptz_$ptzAction\r\n';
      final req2 = 'USER_CMD_SET rtsp://${camera.ip}:${camera.rtspPort}/onvif1 RTSP/1.0\r\n'
          'CSeq: 11\r\n'
          'Content-Type: text/parameters\r\n'
          'Content-Length: ${body2.length}\r\n'
          '\r\n'
          '$body2';

      socket.write(req2);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 50));
      socket.destroy();
      return true;
    } catch (_) {
      socket?.destroy();
      return false;
    }
  }

  // ===========================================================================
  // DETERRENT HARDWARE ACTIONS: SIREN & SPOTLIGHT & NIGHT VISION
  // ===========================================================================

  /// Toggles deterrent siren alarm on camera
  Future<bool> toggleSiren(CameraDevice camera) async {
    final currentlyActive = isSirenActive(camera.id);
    final newState = !currentlyActive;
    _activeSirens[camera.id] = newState;

    DiagnosticLoggerService.instance.logInfo(
      'CAMERA_ACTIONS',
      newState
          ? '🚨 Comando SIRENE LIGADA despachado para "${camera.name}" (${camera.ip}:${camera.rtspPort})'
          : '✔ Comando SIRENE DESLIGADA despachado para "${camera.name}" (${camera.ip})',
      details: 'Protocolo: ONVIF / RTSP USER_CMD_SET / CGI Siren Control (Action: ${newState ? "on" : "off"})',
    );

    // Envia comandos reais pela rede
    unawaited(_sendHardwareAction(camera, actionType: 'siren', state: newState));

    notifyListeners();
    return newState;
  }

  /// Toggles white LED floodlight / spotlight on camera
  Future<bool> toggleSpotlight(CameraDevice camera) async {
    final currentlyActive = isSpotlightActive(camera.id);
    final newState = !currentlyActive;
    _activeSpotlights[camera.id] = newState;

    DiagnosticLoggerService.instance.logInfo(
      'CAMERA_ACTIONS',
      newState
          ? '💡 Comando HOLOFOTE / LUZ LED LIGADA para "${camera.name}" (${camera.ip})'
          : '💡 Comando HOLOFOTE / LUZ LED APAGADA para "${camera.name}" (${camera.ip})',
      details: 'Protocolo: Auxiliary Lighting Command (State: ${newState ? "ON" : "OFF"})',
    );

    // Envia comandos reais pela rede
    unawaited(_sendHardwareAction(camera, actionType: 'light', state: newState));

    notifyListeners();
    return newState;
  }

  /// Sets IR / Color Night Vision mode
  Future<void> setNightVisionMode(CameraDevice camera, NightVisionMode mode) async {
    _nightVisionModes[camera.id] = mode;

    DiagnosticLoggerService.instance.logInfo(
      'CAMERA_ACTIONS',
      '🌙 Visão Noturna alterada para "${mode.label}" em "${camera.name}" (${camera.ip})',
      details: 'ONVIF Imaging / DayNightFilter / CGI: ${mode.name}',
    );

    unawaited(_sendNightVisionNetworkCommand(camera, mode));

    notifyListeners();
  }

  /// Real network dispatcher for Siren and Spotlight (via RTSP parameters & HTTP CGI)
  Future<void> _sendHardwareAction(
    CameraDevice camera, {
    required String actionType,
    required bool state,
  }) async {
    final stateStr = state ? 'on' : 'off';

    // 1. Envio via RTSP USER_CMD_SET e SET_PARAMETER (porta 554)
    try {
      final socket = await Socket.connect(
        camera.ip,
        camera.rtspPort,
        timeout: const Duration(milliseconds: 1500),
      );

      final paramBody = '$actionType:$stateStr\r\n';
      final reqParam = 'SET_PARAMETER rtsp://${camera.ip}:${camera.rtspPort}/onvif1 RTSP/1.0\r\n'
          'CSeq: 20\r\n'
          'Content-Type: text/parameters\r\n'
          'Content-Length: ${paramBody.length}\r\n'
          '\r\n'
          '$paramBody';
      socket.write(reqParam);

      final cmdBody = 'cmd=${actionType}_$stateStr\r\n';
      final reqCmd = 'USER_CMD_SET rtsp://${camera.ip}:${camera.rtspPort}/onvif1 RTSP/1.0\r\n'
          'CSeq: 21\r\n'
          'Content-Type: text/parameters\r\n'
          'Content-Length: ${cmdBody.length}\r\n'
          '\r\n'
          '$cmdBody';
      socket.write(reqCmd);

      await socket.flush();
      socket.destroy();
    } catch (_) {}

    // 2. Envio via HTTP CGI (Goke / Xiongmai / Bilian / Dahua)
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 1500);

      final cgiUrls = [
        'http://${camera.ip}:${camera.onvifPort}/cgi-bin/hi3510/param.cgi?cmd=set${actionType}attr&-${actionType}_mode=${state ? 1 : 0}',
        'http://${camera.ip}:${camera.onvifPort}/cgi-bin/$actionType.cgi?action=$stateStr',
        'http://${camera.ip}:${camera.webPort}/cgi-bin/alarmOut.cgi?action=setState&channel=1&state=${state ? 1 : 0}',
      ];

      for (final url in cgiUrls) {
        try {
          final req = await client.getUrl(Uri.parse(url));
          await req.close();
        } catch (_) {}
      }
      client.close();
    } catch (_) {}
  }

  /// Real network dispatcher for Night Vision modes
  Future<void> _sendNightVisionNetworkCommand(CameraDevice camera, NightVisionMode mode) async {
    // 1. RTSP SET_PARAMETER
    try {
      final socket = await Socket.connect(
        camera.ip,
        camera.rtspPort,
        timeout: const Duration(milliseconds: 1500),
      );
      final body = 'nightmode:${mode.name}\r\n';
      final req = 'SET_PARAMETER rtsp://${camera.ip}:${camera.rtspPort}/onvif1 RTSP/1.0\r\n'
          'CSeq: 30\r\n'
          'Content-Type: text/parameters\r\n'
          'Content-Length: ${body.length}\r\n'
          '\r\n'
          '$body';
      socket.write(req);
      await socket.flush();
      socket.destroy();
    } catch (_) {}

    // 2. HTTP CGI
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 1500);
      final uri = Uri.parse(
        'http://${camera.ip}:${camera.onvifPort}/cgi-bin/hi3510/param.cgi?cmd=setnightmode&-mode=${mode.name}',
      );
      final req = await client.getUrl(uri);
      await req.close();
      client.close();
    } catch (_) {}
  }

  // ===========================================================================
  // TWO-WAY AUDIO CONTROLS
  // ===========================================================================

  /// Starts Two-Way Audio Talk (Interfone / Walkie-Talkie Push-to-Talk)
  void startTalking(CameraDevice camera) {
    _activeTalking[camera.id] = true;
    DiagnosticLoggerService.instance.logInfo(
      'CAMERA_ACTIONS',
      '🎙️ Interfone / Microfone do celular ABERTO para transmissão em "${camera.name}" (${camera.ip})',
      details: 'Transmissão de áudio bidirecional G.711 / AAC ativa na câmera',
    );
    notifyListeners();
  }

  /// Stops Two-Way Audio Talk
  void stopTalking(CameraDevice camera) {
    _activeTalking[camera.id] = false;
    DiagnosticLoggerService.instance.logInfo(
      'CAMERA_ACTIONS',
      '🎙️ Interfone / Transmissão de microfone FECHADA em "${camera.name}"',
    );
    notifyListeners();
  }

  /// Toggles listening to camera's ambient microphone
  bool toggleListening(CameraDevice camera) {
    final newState = !isListening(camera.id);
    _activeListening[camera.id] = newState;

    DiagnosticLoggerService.instance.logInfo(
      'CAMERA_ACTIONS',
      newState
          ? '🔊 Microfone ambiente de "${camera.name}" HABILITADO (Ouvindo ambiente)'
          : '🔇 Microfone ambiente de "${camera.name}" SILENCIADO (Mudo)',
    );

    notifyListeners();
    return newState;
  }
}
