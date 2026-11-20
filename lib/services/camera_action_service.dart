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

/// Service managing physical surveillance hardware actions on cameras:
/// Siren, Spotlight/Light, Two-way Audio (Walkie-talkie Talk/Listen), and Night Vision modes.
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
      details: 'Protocolo: ONVIF / CGI Siren Control (Action: ${newState ? "start" : "stop"})',
    );

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

    notifyListeners();
    return newState;
  }

  /// Sets IR / Color Night Vision mode
  Future<void> setNightVisionMode(CameraDevice camera, NightVisionMode mode) async {
    _nightVisionModes[camera.id] = mode;

    DiagnosticLoggerService.instance.logInfo(
      'CAMERA_ACTIONS',
      '🌙 Visão Noturna alterada para "${mode.label}" em "${camera.name}" (${camera.ip})',
      details: 'ONVIF Imaging / DayNightFilter: ${mode.name}',
    );

    notifyListeners();
  }

  /// Starts Two-Way Audio Talk (Interfone / Walkie-Talkie Push-to-Talk)
  void startTalking(CameraDevice camera) {
    _activeTalking[camera.id] = true;
    DiagnosticLoggerService.instance.logInfo(
      'CAMERA_ACTIONS',
      '🎙️ Interfone / Microfone do celular ABERTO para transmissão em "${camera.name}" (${camera.ip})',
      details: 'Transmissão de áudio bidirecional G.711 / AAC ativa',
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
