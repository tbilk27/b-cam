import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../screens/camera_detail_screen.dart';
import '../services/camera_storage_service.dart';
import '../theme/fluent_theme.dart';
import 'event_clip_player_view.dart';

/// Interactive Event Playback Dialog without redundant bottom buttons.
/// Immediately starts playing the recorded CCTV event clip with scrubber,
/// live timecode, speed control, and AI bounding box tracking.
class EventPlaybackDialog extends StatefulWidget {
  final CameraEvent event;
  final CameraDevice? camera;

  const EventPlaybackDialog({
    super.key,
    required this.event,
    this.camera,
  });

  static Future<void> show(BuildContext context, CameraEvent event, [CameraDevice? camera]) {
    return showDialog(
      context: context,
      builder: (ctx) => EventPlaybackDialog(event: event, camera: camera),
    );
  }

  @override
  State<EventPlaybackDialog> createState() => _EventPlaybackDialogState();
}

class _EventPlaybackDialogState extends State<EventPlaybackDialog> {
  CameraDevice? _camera;

  @override
  void initState() {
    super.initState();
    _camera = widget.camera;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_camera == null) {
      final storage = context.read<CameraStorageService>();
      final list = storage.cameras;
      final idx = list.indexWhere((c) => c.id == widget.event.cameraId || c.name == widget.event.cameraName);
      if (idx != -1) {
        _camera = list[idx];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 440),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(event.type.icon, size: 18, color: event.type.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reprodução: ${event.type.label}',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_camera != null)
                IconButton(
                  icon: const Icon(FluentIcons.video, size: 14, color: BCamTheme.accentLightBlue),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      FluentPageRoute(builder: (_) => CameraDetailScreen(camera: _camera!)),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 13, color: Color(0xB3FFFFFF)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${event.cameraName} • ${event.timeFormatted} (${event.dateFormatted})',
                style: GoogleFonts.robotoMono(fontSize: 12, color: BCamTheme.accentLightBlue),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BCamTheme.statusOnlineGlow.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: BCamTheme.statusOnlineGlow, width: 0.8),
                ),
                child: Text(
                  '${(event.confidence * 100).toInt()}% ASSERTIVIDADE',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: BCamTheme.statusOnlineGlow,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            event.description,
            style: GoogleFonts.inter(fontSize: 13, color: BCamTheme.textPrimary),
          ),
          const SizedBox(height: 12),

          // Interactive CCTV Event Clip Player
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: BCamTheme.accentLightBlue.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: EventClipPlayerView(
              event: event,
              camera: _camera,
              autoPlay: true,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(FluentIcons.info, size: 11, color: BCamTheme.textTertiary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Buffer gravado de ${event.durationFormatted} • Origem: NVR Local / Cartão SD',
                  style: GoogleFonts.robotoMono(fontSize: 10, color: BCamTheme.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
      // No bottom buttons as requested: "se já tem o ícone, não precisa dos botões abaixo"
      actions: null,
    );
  }
}
