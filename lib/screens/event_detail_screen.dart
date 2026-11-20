import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../services/camera_storage_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/event_clip_player_view.dart';
import 'camera_detail_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final CameraEvent event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final storage = Provider.of<CameraStorageService>(context, listen: false);
    CameraDevice? camera;
    try {
      camera = storage.cameras.firstWhere(
        (c) => c.id == event.cameraId || c.name == event.cameraName,
      );
    } catch (_) {
      camera = storage.cameras.isNotEmpty ? storage.cameras.first : null;
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SafeArea(
      child: ScaffoldPage(
        header: PageHeader(
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: IconButton(
              icon: const Icon(FluentIcons.back, size: 16),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          title: Row(
            children: [
              Icon(event.type.icon, size: 20, color: event.type.color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.type.label,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${event.cameraName} • ${event.timeFormatted} (${event.dateFormatted})',
                      style: GoogleFonts.robotoMono(fontSize: 11, color: BCamTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: isLandscape
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Pane: Video and Bounding Box Viewer
                    Expanded(
                      flex: 56,
                      child: _buildVideoView(event, camera),
                    ),
                    const SizedBox(width: 14),
                    // Right Pane: AI Interpretation, Detections, Actions
                    Expanded(
                      flex: 44,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAiCard(event),
                            const SizedBox(height: 10),
                            if (event.boundingBoxes.isNotEmpty) _buildBoundingBoxesCard(event),
                            const SizedBox(height: 12),
                            _buildActionsRow(event, camera),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVideoView(event, camera),
                    const SizedBox(height: 16),
                    _buildAiCard(event),
                    const SizedBox(height: 12),
                    if (event.boundingBoxes.isNotEmpty) _buildBoundingBoxesCard(event),
                    const SizedBox(height: 16),
                    _buildActionsRow(event, camera),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildVideoView(CameraEvent event, CameraDevice? camera) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BCamTheme.darkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: EventClipPlayerView(
          event: event,
          camera: camera,
          autoPlay: true,
        ),
      ),
    );
  }

  Widget _buildAiCard(CameraEvent event) {
    return Card(
      backgroundColor: BCamTheme.darkSurface,
      borderColor: BCamTheme.darkBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BCamTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(FluentIcons.robot, size: 16, color: BCamTheme.accentLightBlue),
              ),
              const SizedBox(width: 8),
              Text(
                'Interpretação da Cena por Agente de IA',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: BCamTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.sceneInterpretation ?? event.description,
            style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: BCamTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Índice de Certeza do Agente',
                          style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                        ),
                        Text(
                          '${(event.confidence * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.robotoMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: event.confidence >= 0.25 ? BCamTheme.statusOnlineGlow : BCamTheme.statusOffline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ProgressBar(
                      value: event.confidence * 100,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '✔ Aprovado: confiança superior ao limiar mínimo de 25% (notificação despachada).',
            style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.statusOnlineGlow),
          ),
        ],
      ),
    );
  }

  Widget _buildBoundingBoxesCard(CameraEvent event) {
    return Card(
      backgroundColor: BCamTheme.darkSurface,
      borderColor: BCamTheme.darkBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Objetos Marcados e Contornados (${event.boundingBoxes.length})',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: BCamTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: event.boundingBoxes.map((box) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: box.displayColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: box.displayColor.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.tag, size: 12, color: box.displayColor),
                    const SizedBox(width: 4),
                    Text(
                      '${box.label}: ${(box.confidence * 100).toInt()}%',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: box.displayColor),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(CameraEvent event, CameraDevice? camera) {
    return Row(
      children: [
        Expanded(
          child: Button(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: event.deepLinkUrl ?? 'bcam://event/${event.id}'));
              displayInfoBar(
                context,
                builder: (context, close) => InfoBar(
                  title: const Text('Deeplink Copiado'),
                  content: Text(event.deepLinkUrl ?? 'bcam://event/${event.id}'),
                  severity: InfoBarSeverity.success,
                  onClose: close,
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.link, size: 14),
                SizedBox(width: 6),
                Text('Copiar Deeplink'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (camera != null)
          Expanded(
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  FluentPageRoute(
                    builder: (context) => CameraDetailScreen(camera: camera),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.video, size: 14),
                  SizedBox(width: 6),
                  Text('Câmera ao Vivo'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
