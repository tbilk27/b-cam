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
/// live timecode, speed control, group clips playlist selector, and AI tracking.
class EventPlaybackDialog extends StatefulWidget {
  final CameraEvent event;
  final CameraDevice? camera;
  final List<CameraEvent>? groupClips;

  const EventPlaybackDialog({
    super.key,
    required this.event,
    this.camera,
    this.groupClips,
  });

  static Future<void> show(
    BuildContext context,
    CameraEvent event, [
    CameraDevice? camera,
    List<CameraEvent>? groupClips,
  ]) {
    return showDialog(
      context: context,
      builder: (ctx) => EventPlaybackDialog(
        event: event,
        camera: camera,
        groupClips: groupClips,
      ),
    );
  }

  @override
  State<EventPlaybackDialog> createState() => _EventPlaybackDialogState();
}

class _EventPlaybackDialogState extends State<EventPlaybackDialog> {
  CameraDevice? _camera;
  late List<CameraEvent> _clips;
  int _currentClipIndex = 0;

  @override
  void initState() {
    super.initState();
    _camera = widget.camera;
    if (widget.groupClips != null && widget.groupClips!.isNotEmpty) {
      _clips = List.from(widget.groupClips!);
      final idx = _clips.indexWhere((c) => c.id == widget.event.id);
      _currentClipIndex = idx >= 0 ? idx : 0;
    } else {
      _clips = [widget.event];
      _currentClipIndex = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_camera == null) {
      final storage = context.read<CameraStorageService>();
      final list = storage.cameras;
      final currentEvent = _clips[_currentClipIndex];
      final idx = list.indexWhere((c) => c.id == currentEvent.cameraId || c.name == currentEvent.cameraName);
      if (idx != -1) {
        _camera = list[idx];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _clips[_currentClipIndex];

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
          // Seletor de Clipes do Grupo quando agrupado
          if (_clips.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF16161D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2C2C38), width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(FluentIcons.video, size: 12, color: BCamTheme.statusOnlineGlow),
                          const SizedBox(width: 6),
                          Text(
                            'Grupo de Movimento (${_clips.length} clipes gravados)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(FluentIcons.chevron_left, size: 10),
                            onPressed: _currentClipIndex > 0
                                ? () => setState(() => _currentClipIndex--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '${_currentClipIndex + 1}/${_clips.length}',
                              style: GoogleFonts.robotoMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: BCamTheme.accentLightBlue,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(FluentIcons.chevron_right, size: 10),
                            onPressed: _currentClipIndex < _clips.length - 1
                                ? () => setState(() => _currentClipIndex++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_clips.length, (idx) {
                        final c = _clips[idx];
                        final isSel = idx == _currentClipIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _currentClipIndex = idx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel ? BCamTheme.accentBlue : const Color(0xFF22222D),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSel ? BCamTheme.statusOnlineGlow : const Color(0xFF333342),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(c.type.icon, size: 10, color: isSel ? Colors.white : c.type.color),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Clipe ${idx + 1} (${c.timeFormatted})',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 10,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? Colors.white : BCamTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
              key: ValueKey(event.id),
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
