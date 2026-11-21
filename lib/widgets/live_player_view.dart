import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/bounding_box.dart';
import '../models/camera_device.dart';
import '../models/manufacturer.dart';
import '../services/ai_vision_agent_service.dart';
import '../services/camera_event_service.dart';
import '../services/camera_storage_service.dart';
import '../services/cloud_relay_service.dart';
import '../services/diagnostic_logger_service.dart';
import '../theme/fluent_theme.dart';
import 'bounding_box_overlay.dart';
import 'exclusion_mask_painter.dart';

class LivePlayerView extends StatefulWidget {
  final CameraDevice camera;
  final bool autoPlay;
  final bool showPtzOverlay;
  final bool isMiniature;
  final bool showTopHud;
  final bool showOsdClock;

  const LivePlayerView({
    super.key,
    required this.camera,
    this.autoPlay = true,
    this.showPtzOverlay = false,
    this.isMiniature = false,
    this.showTopHud = true,
    this.showOsdClock = true,
  });

  @override
  State<LivePlayerView> createState() => LivePlayerViewState();
}

class LivePlayerViewState extends State<LivePlayerView>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  Player? _player;
  VideoController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isMuted = true;
  Timer? _clockTimer;
  String _currentTime = '';
  StreamSubscription? _errorSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _widthSub;
  bool _hasAutoCaptured = false;

  /// Captura o frame atual em reprodução no Player e salva no armazenamento persistente
  Future<String?> captureSnapshot() async {
    try {
      if (_player == null) return null;
      final bytes = await _player!.screenshot(format: 'image/jpeg');
      if (bytes != null && bytes.isNotEmpty) {
        final dir = await getApplicationDocumentsDirectory();
        final snapDir = Directory('${dir.path}/snapshots');
        if (!await snapDir.exists()) {
          await snapDir.create(recursive: true);
        }
        final path = '${snapDir.path}/snap_${widget.camera.id}.jpg';
        final file = File(path);
        await file.writeAsBytes(bytes, flush: true);
        await FileImage(file).evict();
        DiagnosticLoggerService.instance.logInfo(
          'SNAPSHOT',
          'Frame ao vivo salvo como capa da câmera "${widget.camera.name}": $path (${bytes.length} bytes)',
        );
        return path;
      }
    } catch (e) {
      DiagnosticLoggerService.instance.logWarn('SNAPSHOT', 'Falha ao capturar frame ao vivo: $e');
    }
    return null;
  }

  // Auto-reconnect engine
  int _reconnectAttempt = 0;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;
  Timer? _watchdogTimer;
  Timer? _aiSurveillanceTimer;

  // Camera state & local copy for immediate credential healing
  late CameraDevice _effectiveCamera;

  // Cloud Relay Routing (Fora da LAN / 4G / 5G)
  bool _usingCloudRelay = false;

  // AI Vision Live Detections
  bool _showAiOverlay = true;

  bool get _isLikelyAuthError {
    final msg = _errorMessage?.toLowerCase() ?? '';
    return msg.contains('unauthorized') ||
        msg.contains('401') ||
        msg.contains('authentication') ||
        msg.contains('authorization') ||
        (widget.camera.manufacturer == CameraManufacturer.yoosee &&
            (msg.contains('file format') || msg.contains('bad request'))) ||
        _effectiveCamera.password == 'admin' ||
        _effectiveCamera.password.isEmpty;
  }

  void _onAiVisionUpdate() {
    if (mounted) setState(() {});
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _effectiveCamera = widget.camera;
    WidgetsBinding.instance.addObserver(this);
    AiVisionAgentService.instance.addListener(_onAiVisionUpdate);
    CameraEventService.instance.addListener(_onAiVisionUpdate);
    _initPlayer();
    _startHudClock();
    _startWatchdog();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.camera.isEnabled) {
      DiagnosticLoggerService.instance.logInfo(
        'RTSP_PLAYER',
        'App retomado ao primeiro plano. Revalidando status do fluxo para "${widget.camera.name}" (${widget.camera.ip})...',
      );
      if (_hasError || !(_player?.state.playing ?? false)) {
        _cancelAutoReconnect();
        _playStream();
      }
    }
  }

  void _startHudClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
        });
      }
    });
    _currentTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
  }

  void _startWatchdog() {
    _watchdogTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted || !widget.camera.isEnabled) return;
      // If autoPlay is enabled, not in error, but not playing and not loading for > 12s, reconnect
      if (widget.autoPlay && !_hasError && !_isLoading && !(_player?.state.playing ?? false)) {
        DiagnosticLoggerService.instance.logWarn(
          'RTSP_PLAYER',
          'Watchdog detectou fluxo inativo para "${widget.camera.name}". Forçando reconexão...',
        );
        _playStream();
      }
    });
  }

  void _initPlayer() {
    try {
      final p = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 1024 * 1024 * 4, // 4MB low latency buffer
        ),
      );
      _player = p;
      _controller = VideoController(p);

      _widthSub = p.stream.width.listen((width) {
        if (width != null && width > 0 && mounted) {
          _cancelAutoReconnect();
          setState(() {
            _hasError = false;
            _errorMessage = null;
            _isLoading = false;
            _reconnectAttempt = 0;
          });
          if (_usingCloudRelay) {
            DiagnosticLoggerService.instance.logInfo(
              'CLOUD_RELAY',
              '✔ Conexão ativa com sucesso via Cloud Relay para "${widget.camera.name}".',
            );
          } else {
            DiagnosticLoggerService.instance.logInfo(
              'RTSP_PLAYER',
              '✔ Fluxo RTSP ativo (${width}x${p.state.height}) para "${widget.camera.name}".',
            );
          }
        }
      });

      _errorSub = p.stream.error.listen((error) {
        // Filter out benign non-fatal seek/stream notifications from libmpv
        if (error.contains('Cannot seek') ||
            error.contains('force-seekable') ||
            error.contains('Seeking is not supported') ||
            error.contains('demux_rtsp')) {
          DiagnosticLoggerService.instance.logInfo(
            'RTSP_PLAYER',
            'libmpv evento informativo (não-fatal) para "${widget.camera.name}": $error',
          );
          return;
        }

        DiagnosticLoggerService.instance.logError(
          'RTSP_PLAYER',
          'Erro de reprodução na câmera "${widget.camera.name}" (${widget.camera.ip})',
          details: 'libmpv: $error | URL: ${widget.camera.maskedStreamUrl}',
        );

        // Auto-healing: Se falhar no fluxo principal (HD / H.265 / Smart Codec / 3MP), comuta automaticamente para o fluxo secundário (SD / H.264)
        final isCodecOrFormatError = error.contains('Could not open codec') ||
            error.contains('Cannot open codec') ||
            error.contains('codec') ||
            error.contains('Failed to recognize file format');

        if (isCodecOrFormatError && _effectiveCamera.subType == 0) {
          DiagnosticLoggerService.instance.logWarn(
            'RTSP_PLAYER',
            '⚠️ Codec/formato HD incompatível na câmera "${widget.camera.name}". Ativando fallback automático para Sub Stream (SD / H.264)...',
          );
          _effectiveCamera = _effectiveCamera.copyWith(subType: 1);
          if (mounted) {
            try {
              context.read<CameraStorageService>().updateCamera(_effectiveCamera);
            } catch (_) {}
          }
          _cancelAutoReconnect();
          _reconnectAttempt = 0;
          _usingCloudRelay = false;
          _playStream();
          return;
        }

        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = error;
            _isLoading = false;
          });
          _scheduleAutoReconnect();
        }
      });

      _completedSub = p.stream.completed.listen((completed) {
        if (completed && mounted) {
          DiagnosticLoggerService.instance.logWarn(
            'RTSP_PLAYER',
            'Fluxo de vídeo encerrado/desconectado para "${widget.camera.name}" (${widget.camera.ip}). Agendando reconexão...',
          );
          setState(() {
            _hasError = true;
            _errorMessage = 'Conexão interrompida';
            _isLoading = false;
          });
          _scheduleAutoReconnect();
        }
      });

      _playingSub = p.stream.playing.listen((playing) {
        if (playing && mounted) {
          _cancelAutoReconnect();
          setState(() {
            _hasError = false;
            _errorMessage = null;
            _isLoading = false;
            _reconnectAttempt = 0;
          });

          if (_usingCloudRelay) {
            DiagnosticLoggerService.instance.logInfo(
              'CLOUD_RELAY',
              '✔ Conexão ativa com sucesso via Cloud Relay para "${widget.camera.name}".',
            );
          }

          _startAiSurveillanceLoop();

          // Dispara captura automática do frame após 3 segundos de estabilização do fluxo
          if (!_hasAutoCaptured) {
            _hasAutoCaptured = true;
            Future.delayed(const Duration(seconds: 3), () async {
              if (mounted && (_player?.state.playing ?? false)) {
                final path = await captureSnapshot();
                if (path != null && mounted) {
                  try {
                    final storage = Provider.of<CameraStorageService>(context, listen: false);
                    await storage.recordCameraAccess(widget.camera.id, snapshotPath: path);

                    // Processa e registra o evento real se a IA estiver ativa na câmera
                    if (_effectiveCamera.aiDetectionEnabled) {
                      await AiVisionAgentService.instance.processLiveSnapshot(
                        _effectiveCamera,
                        snapshotPath: path,
                      );
                    }
                  } catch (_) {}
                }
              }
            });
          }
        }
      });

      _bufferingSub = p.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() {
            _isLoading = buffering;
          });
        }
      });

      if (widget.autoPlay && widget.camera.isEnabled) {
        _playStream();
      } else {
        _isLoading = false;
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
      _scheduleAutoReconnect();
    }
  }

  void _scheduleAutoReconnect() {
    _cancelAutoReconnect();
    if (!widget.camera.isEnabled) {
      DiagnosticLoggerService.instance.logInfo(
        'RTSP_PLAYER',
        'Retentativa de reconexão suspensa: Câmera "${widget.camera.name}" está desativada.',
      );
      return;
    }
    _reconnectAttempt++;

    // Só comuta para nuvem se houver um host remoto expressamente configurado
    // ou se a nuvem global estiver forçada (evita loop infinito em nuvem quando na LAN)
    final hasCustomRemoteHost = _effectiveCamera.remoteHost != null && _effectiveCamera.remoteHost!.trim().isNotEmpty;
    final canUseCloud = _effectiveCamera.remoteAccessMode == 'remote' ||
        (_effectiveCamera.remoteAccessMode == 'auto' && (hasCustomRemoteHost || CloudRelayService.instance.globalMode == CloudNetworkMode.alwaysCloud));

    if (canUseCloud && _effectiveCamera.remoteAccessMode != 'local') {
      // Alterna entre LAN local e relay remoto nas tentativas ímpares/pares
      final shouldCloud = (_reconnectAttempt % 2 == 1);
      if (_usingCloudRelay != shouldCloud) {
        _usingCloudRelay = shouldCloud;
        DiagnosticLoggerService.instance.logInfo(
          'CLOUD_RELAY',
          _usingCloudRelay
              ? 'Alternando conexão de "${widget.camera.name}" para a infraestrutura Cloud Relay...'
              : 'Retornando conexão de "${widget.camera.name}" para a LAN local (${_effectiveCamera.ip})...',
        );
      }
    } else {
      _usingCloudRelay = false;
    }

    // Exponential / stepped backoff: 2s -> 4s -> 7s -> 10s (max)
    final delay = switch (_reconnectAttempt) {
      1 => 2,
      2 => 4,
      3 => 7,
      _ => 10,
    };
    _secondsRemaining = delay;

    DiagnosticLoggerService.instance.logInfo(
      'RTSP_PLAYER',
      'Reconexão automática #$_reconnectAttempt agendada para "${widget.camera.name}" em ${_secondsRemaining}s',
    );

    if (mounted) {
      setState(() {});
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _countdownTimer = null;
        _playStream();
      }
    });
  }

  void _cancelAutoReconnect() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _showQuickPasswordDialog() {
    _cancelAutoReconnect();
    final passCtrl = TextEditingController(text: _effectiveCamera.password);
    bool obscure = true;
    final isMibo = _effectiveCamera.isMibo;

    fluent.showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return fluent.ContentDialog(
              title: Row(
                children: [
                  Icon(
                    fluent.FluentIcons.password_field,
                    size: 18,
                    color: isMibo ? const Color(0xFF00C853) : const Color(0xFFFF9500),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMibo ? 'Código de Verificação: ${_effectiveCamera.name}' : 'Credenciais: ${_effectiveCamera.name}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMibo
                        ? 'Câmeras Intelbras Mibo exigem o Código de Verificação da etiqueta física da câmera:'
                        : 'A câmera (${_effectiveCamera.ip}) recusou o acesso. Informe a senha configurada no dispositivo:',
                    style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  fluent.TextBox(
                    controller: passCtrl,
                    obscureText: obscure,
                    placeholder: isMibo
                        ? 'Código de Verificação da etiqueta (ex: RWKINH)'
                        : 'Senha da câmera',
                    suffix: fluent.IconButton(
                      icon: Icon(obscure ? fluent.FluentIcons.view : fluent.FluentIcons.hide, size: 14),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  if (isMibo) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF162319),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Importante: No aplicativo oficial Mibo, desative a opção "Criptografia de Vídeo". A senha NUNCA é a da sua conta de e-mail do app Mibo, e sim o código da etiqueta.',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFD4EDDA), height: 1.35),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                fluent.Button(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                fluent.FilledButton(
                  onPressed: () async {
                    final newPass = passCtrl.text.trim();
                    Navigator.of(ctx).pop();
                    final storage = context.read<CameraStorageService>();
                    final updated = _effectiveCamera.copyWith(password: newPass);
                    setState(() {
                      _effectiveCamera = updated;
                      _hasError = false;
                      _errorMessage = null;
                      _isLoading = true;
                    });
                    await storage.updateCamera(updated);
                    _playStream();
                  },
                  child: const Text('Salvar e Conectar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _playStream() async {
    _cancelAutoReconnect();

    if (!widget.camera.isEnabled) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }

    try {
      final shouldCloud = _usingCloudRelay ||
          _effectiveCamera.remoteAccessMode == 'remote' ||
          CloudRelayService.instance.shouldRouteThroughCloud(_effectiveCamera);

      final url = _effectiveCamera.getEffectiveStreamUrl(forceCloud: shouldCloud);
      final maskedUrl = _effectiveCamera.getEffectiveMaskedStreamUrl(forceCloud: shouldCloud);
      final isYoosee = _effectiveCamera.manufacturer.id == 'yoosee';
      // Yoosee cameras exclusively support UDP transport for RTSP streaming; TCP returns 'Nonmatching transport'
      final transportStr = (isYoosee && !shouldCloud) ? 'udp' : 'tcp';

      DiagnosticLoggerService.instance.logInfo(
        'RTSP_PLAYER',
        'Conectando a "${_effectiveCamera.name}" (${shouldCloud ? "Cloud Relay" : _effectiveCamera.ip}) via ${transportStr.toUpperCase()} (Tentativa #$_reconnectAttempt)',
        details: 'Stream URL: $maskedUrl',
      );

      if (_player != null) {
        await _player!.setVolume(widget.isMiniature ? 0 : (_isMuted ? 0 : 100));

        try {
          await (_player!.platform as dynamic).setProperty('rtsp-transport', transportStr);
          await (_player!.platform as dynamic).setProperty('demuxer-lavf-o', 'rtsp_transport=$transportStr');
        } catch (e) {
          debugPrint('Note: setProperty rtsp-transport: $e');
        }

        await _player!.open(
          Media(
            url,
            httpHeaders: {
              'User-Agent': 'b-cam/1.0',
            },
          ),
          play: true,
        );
      }

      // Timeout watchdog: if not playing after 5 seconds, ensure loading overlay disappears
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_hasError) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e, stack) {
      DiagnosticLoggerService.instance.logError(
        'RTSP_PLAYER',
        'Exceção ao inicializar stream de "${widget.camera.name}" (${widget.camera.ip})',
        error: e,
        stackTrace: stack,
        details: 'URL: ${widget.camera.maskedStreamUrl}',
      );
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
        _scheduleAutoReconnect();
      }
    }
  }

  @override
  void didUpdateWidget(covariant LivePlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _effectiveCamera = widget.camera;
    if (oldWidget.camera.isEnabled != widget.camera.isEnabled) {
      if (!widget.camera.isEnabled) {
        _cancelAutoReconnect();
        _watchdogTimer?.cancel();
        _player?.stop();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        _startWatchdog();
        _reconnectAttempt = 0;
        _playStream();
      }
    } else if (widget.camera.isEnabled &&
        (oldWidget.camera.streamUrl != widget.camera.streamUrl ||
            oldWidget.camera.ip != widget.camera.ip ||
            oldWidget.camera.subType != widget.camera.subType ||
            oldWidget.camera.password != widget.camera.password)) {
      _reconnectAttempt = 0;
      _playStream();
    }
  }

  void _startAiSurveillanceLoop() {
    _aiSurveillanceTimer?.cancel();
    _aiSurveillanceTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
      if (!mounted || !_effectiveCamera.isEnabled || !_effectiveCamera.aiDetectionEnabled) return;
      if (!(_player?.state.playing ?? false)) return;

      final path = await captureSnapshot();
      if (path != null && mounted) {
        await AiVisionAgentService.instance.processLiveSnapshot(
          _effectiveCamera,
          snapshotPath: path,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AiVisionAgentService.instance.removeListener(_onAiVisionUpdate);
    CameraEventService.instance.removeListener(_onAiVisionUpdate);
    _cancelAutoReconnect();
    _watchdogTimer?.cancel();
    _aiSurveillanceTimer?.cancel();
    _clockTimer?.cancel();
    _errorSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    _widthSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final liveBoxes = (_showAiOverlay && widget.camera.aiDetectionEnabled)
        ? AiVisionAgentService.instance.getLiveDetectionsForCamera(widget.camera)
        : const <BoundingBox>[];

    if (!widget.camera.isEnabled) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131317),
          borderRadius: BorderRadius.circular(widget.isMiniature ? 8 : 12),
          border: Border.all(
            color: BCamTheme.darkBorder,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    fluent.FluentIcons.circle_stop_solid,
                    size: 24,
                    color: BCamTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Câmera Desativada',
                  style: GoogleFonts.inter(
                    fontSize: widget.isMiniature ? 11.5 : 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Retentativas de conexão suspensas.',
                  style: GoogleFonts.inter(
                    fontSize: widget.isMiniature ? 9 : 11,
                    color: BCamTheme.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!widget.isMiniature) ...[
                  const SizedBox(height: 10),
                  fluent.Button(
                    onPressed: () {
                      context.read<CameraStorageService>().toggleCameraEnabled(widget.camera.id);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(fluent.FluentIcons.play, size: 11, color: BCamTheme.statusOnlineGlow),
                        const SizedBox(width: 5),
                        Text(
                          'Ativar Câmera',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12),
        borderRadius: BorderRadius.circular(widget.isMiniature ? 8 : 12),
        border: Border.all(
          color: _hasError
              ? (_secondsRemaining > 0
                  ? BCamTheme.accentLightBlue.withValues(alpha: 0.5)
                  : BCamTheme.statusOffline.withValues(alpha: 0.5))
              : BCamTheme.darkBorder,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Canvas
          (_controller != null)
              ? Video(
                  controller: _controller!,
                  fit: BoxFit.cover,
                  controls: NoVideoControls,
                )
              : Container(color: Colors.black),

          // 2. Painted Exclusion Zone Mask (if configured on this camera)
          if (widget.camera.hasExclusionZone && _showAiOverlay)
            IgnorePointer(
              child: CustomPaint(
                painter: ExclusionMaskPainter(
                  excludedCells: widget.camera.exclusionMask.toSet(),
                  showGridLines: false,
                  maskColor: const Color(0x33FF3B30),
                  borderColor: const Color(0x66FF3B30),
                ),
              ),
            ),

          // 2. Subtle Vignette Effect
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.25,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),

          // 3. Grid Crosshair markings in corners (Sober Surveillance HUD)
          if (!widget.isMiniature)
            IgnorePointer(
              child: CustomPaint(
                painter: _HudCrosshairPainter(),
              ),
            ),

          // 4. Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: widget.isMiniature
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BCamTheme.accentLightBlue,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: BCamTheme.accentLightBlue,
                              backgroundColor: Color(0xFF2A2A30),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _reconnectAttempt > 0
                                ? 'RECONECTANDO AO FLUXO (TENTATIVA #$_reconnectAttempt)...'
                                : 'CONECTANDO AO FLUXO...',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: BCamTheme.textSecondary,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

          // 5. Error & Auto-reconnect display
          if (_hasError)
            Container(
              color: const Color(0xFF19161B),
              padding: EdgeInsets.all(widget.isMiniature ? 4 : 8),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: widget.isMiniature
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLikelyAuthError
                                ? Icons.lock_outline_rounded
                                : (_secondsRemaining > 0 ? Icons.sync_rounded : Icons.videocam_off_rounded),
                            color: _isLikelyAuthError
                                ? const Color(0xFFFF9500)
                                : (_secondsRemaining > 0 ? BCamTheme.accentLightBlue : BCamTheme.statusOffline),
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isLikelyAuthError
                                ? 'SENHA INCORRETA'
                                : (_secondsRemaining > 0 ? 'RECONECTANDO (${_secondsRemaining}s)' : 'OFFLINE'),
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: _isLikelyAuthError
                                  ? const Color(0xFFFF9500)
                                  : (_secondsRemaining > 0 ? BCamTheme.accentLightBlue : BCamTheme.statusOffline),
                            ),
                          ),
                          Text(
                            '#$_reconnectAttempt • ${_effectiveCamera.ip}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 8,
                              color: BCamTheme.textTertiary,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLikelyAuthError
                                ? Icons.lock_rounded
                                : (_secondsRemaining > 0 ? Icons.sync_rounded : Icons.videocam_off_rounded),
                            color: _isLikelyAuthError
                                ? const Color(0xFFFF9500)
                                : (_secondsRemaining > 0 ? BCamTheme.accentLightBlue : BCamTheme.statusOffline),
                            size: 34,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLikelyAuthError
                                ? 'FALHA DE AUTENTICAÇÃO (401)'
                                : (_secondsRemaining > 0 ? 'AGUARDANDO RECONEXÃO' : 'FLUXO INDISPONÍVEL'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isLikelyAuthError
                                  ? const Color(0xFFFF9500)
                                  : (_secondsRemaining > 0 ? BCamTheme.accentLightBlue : BCamTheme.statusOffline),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isLikelyAuthError
                                ? 'A câmera recusou o usuário ou senha configurados'
                                : 'IP: ${_effectiveCamera.ip}:${_effectiveCamera.rtspPort}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _isLikelyAuthError ? Colors.white70 : BCamTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _isLikelyAuthError
                                  ? 'Dica: clique em "Alterar Senha" para atualizar a senha da câmera.'
                                  : _errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: _isLikelyAuthError ? const Color(0xFFFFB74D) : BCamTheme.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (_secondsRemaining > 0 && !_isLikelyAuthError)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: BCamTheme.accentLightBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tentativa automática em ${_secondsRemaining}s (#$_reconnectAttempt)...',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: BCamTheme.accentLightBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              if (_isLikelyAuthError)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF9500),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: _showQuickPasswordDialog,
                                  icon: const Icon(Icons.key, size: 14, color: Colors.black),
                                  label: Text(
                                    'Alterar Senha da Câmera',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BCamTheme.darkSurface,
                                  foregroundColor: BCamTheme.textPrimary,
                                  side: const BorderSide(color: BCamTheme.darkBorder),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () {
                                  _cancelAutoReconnect();
                                  _playStream();
                                },
                                icon: const Icon(Icons.refresh, size: 14),
                                label: Text(
                                  'Reconectar Agora',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                ),
              ),
            ),

          // 5.5 Live AI Bounding Box & Assertiveness Marking (Cleanly overlaid on top of video canvas)
          if (_showAiOverlay && widget.camera.aiDetectionEnabled && liveBoxes.isNotEmpty)
            BoundingBoxOverlay(
              boundingBoxes: liveBoxes,
              minConfidenceThreshold: widget.camera.aiMinConfidence,
              showLabels: true,
              child: const SizedBox.expand(),
            ),

          // 6. Dedicated CCTV OSD Timestamp (Data e Hora do Vídeo ao Vivo)
          if (widget.showOsdClock)
            Positioned(
              top: 8,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24, width: 0.6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _hasError ? const Color(0xFFFF3B30) : const Color(0xFF00E676),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_hasError ? const Color(0xFFFF3B30) : const Color(0xFF00E676))
                                .withValues(alpha: 0.8),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currentTime,
                      style: GoogleFonts.robotoMono(
                        fontSize: widget.isMiniature ? 8.5 : 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 6.1 Top-Left Status HUD Bar (REC/LIVE status & Exclusions)
          if (widget.showTopHud)
            Positioned(
              top: 8,
              left: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _hasError ? BCamTheme.statusOffline : BCamTheme.statusOnlineGlow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_hasError ? BCamTheme.statusOffline : BCamTheme.statusOnlineGlow)
                              .withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _hasError
                        ? (_secondsRemaining > 0 ? 'RETRY' : 'OFFLINE')
                        : (_usingCloudRelay || widget.camera.remoteAccessMode == 'remote' ? 'LIVE • CLOUD' : 'LIVE'),
                    style: GoogleFonts.inter(
                      fontSize: widget.isMiniature ? 9 : 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (widget.camera.hasExclusionZone) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF3B30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0x80FF3B30), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(fluent.FluentIcons.blocked2, size: 8, color: Color(0xFFFF3B30)),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.camera.exclusionZonePercentage.toStringAsFixed(0)}% EXCLUÍDO',
                            style: GoogleFonts.robotoMono(
                              fontSize: widget.isMiniature ? 7.5 : 8.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF6961),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_showAiOverlay && widget.camera.aiDetectionEnabled && liveBoxes.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: liveBoxes.first.displayColor.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: liveBoxes.first.displayColor.withValues(alpha: 0.7),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(fluent.FluentIcons.robot, size: 9, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${liveBoxes.first.label.toUpperCase()} ${liveBoxes.first.assertivenessFormatted}',
                            style: GoogleFonts.robotoMono(
                              fontSize: widget.isMiniature ? 8 : 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // 7. Bottom HUD Bar (Brand, Channel, Controls)
          Positioned(
            bottom: 8,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: widget.camera.manufacturer.brandColor.withValues(alpha: 0.7),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${widget.camera.manufacturer.displayName} • CH${widget.camera.channel}',
                      style: GoogleFonts.inter(
                        fontSize: widget.isMiniature ? 9 : 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!widget.isMiniature)
                  Row(
                    children: [
                      // AI Vision Bounding Box toggle
                      if (widget.camera.aiDetectionEnabled)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: _showAiOverlay
                                  ? BCamTheme.accentBlue.withValues(alpha: 0.7)
                                  : Colors.black54,
                              padding: const EdgeInsets.all(5),
                              minimumSize: const Size(28, 28),
                            ),
                            icon: Icon(
                              Icons.smart_toy_outlined,
                              color: _showAiOverlay ? Colors.white : Colors.white54,
                              size: 15,
                            ),
                            tooltip: _showAiOverlay ? 'Ocultar Contornos IA' : 'Exibir Contornos IA',
                            onPressed: () {
                              setState(() {
                                _showAiOverlay = !_showAiOverlay;
                              });
                            },
                          ),
                        ),
                      // Audio Mute toggle
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(5),
                          minimumSize: const Size(28, 28),
                        ),
                        icon: Icon(
                          _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: _isMuted ? Colors.white54 : BCamTheme.accentLightBlue,
                          size: 15,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMuted = !_isMuted;
                            _player?.setVolume(_isMuted ? 0 : 100);
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      // Reload
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(5),
                          minimumSize: const Size(28, 28),
                        ),
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 15),
                        onPressed: () {
                          _cancelAutoReconnect();
                          _playStream();
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HudCrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const cornerLen = 10.0;
    const padding = 6.0;

    // Top-Left
    canvas.drawLine(const Offset(padding, padding + cornerLen), const Offset(padding, padding), paint);
    canvas.drawLine(const Offset(padding, padding), const Offset(padding + cornerLen, padding), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width - padding - cornerLen, padding), Offset(size.width - padding, padding), paint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + cornerLen), paint);

    // Bottom-Left
    canvas.drawLine(Offset(padding, size.height - padding - cornerLen), Offset(padding, size.height - padding), paint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerLen, size.height - padding), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - padding - cornerLen, size.height - padding), Offset(size.width - padding, size.height - padding), paint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding - cornerLen), Offset(size.width - padding, size.height - padding), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
