import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../services/camera_storage_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/bounding_box_overlay.dart';
import 'camera_detail_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final CameraEvent event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _showBoundingBoxes = true;
  bool _isPlaying = false;

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
        content: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Video / Snapshot Container with BoundingBoxOverlay
              Container(
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
                  child: Stack(
                    children: [
                      // Simulated Clip Background or Image
                      Positioned.fill(
                        child: BoundingBoxOverlay(
                          boundingBoxes: _showBoundingBoxes ? event.boundingBoxes : const [],
                          minConfidenceThreshold: 0.25,
                          child: Container(
                            color: const Color(0xFF141418),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isPlaying ? FluentIcons.pause : FluentIcons.play,
                                    size: 48,
                                    color: BCamTheme.accentLightBlue,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isPlaying ? 'Reproduzindo Gravação do Evento' : 'Buffer NVR: ${event.durationFormatted}',
                                    style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                                  ),
                                  Text(
                                    'Gravação Local Criptografada',
                                    style: GoogleFonts.robotoMono(fontSize: 10, color: BCamTheme.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Overlay Controls Header
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xD91B1B1F),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: event.type.color.withValues(alpha: 0.6), width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  Icon(event.type.icon, size: 12, color: event.type.color),
                                  const SizedBox(width: 4),
                                  Text(
                                    'IA: ${(event.confidence * 100).toInt()}% CERTEZA',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: event.type.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Toggle Bounding Boxes Button
                            Button(
                              style: ButtonStyle(
                                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                backgroundColor: WidgetStateProperty.all(
                                  _showBoundingBoxes ? BCamTheme.accentBlue.withValues(alpha: 0.3) : const Color(0xD91B1B1F),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showBoundingBoxes = !_showBoundingBoxes;
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    _showBoundingBoxes ? FluentIcons.checkbox_composite : FluentIcons.checkbox,
                                    size: 12,
                                    color: _showBoundingBoxes ? BCamTheme.accentLightBlue : BCamTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Bounding Boxes',
                                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Play/Pause Bottom Bar
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(_isPlaying ? FluentIcons.pause : FluentIcons.play, color: Colors.white, size: 16),
                              onPressed: () {
                                setState(() {
                                  _isPlaying = !_isPlaying;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ProgressBar(
                                value: _isPlaying ? 65 : 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              event.durationFormatted,
                              style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // AI Scene Interpretation Card
              Card(
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
              ),

              const SizedBox(height: 12),

              // Bounding Boxes Summary Card
              if (event.boundingBoxes.isNotEmpty)
                Card(
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
                ),

              const SizedBox(height: 16),

              // Deeplink & Action Buttons
              Row(
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
                              builder: (context) => CameraDetailScreen(camera: camera!),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
