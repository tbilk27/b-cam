import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../services/camera_event_service.dart';
import '../theme/fluent_theme.dart';

class VerticalEventTimeline extends StatefulWidget {
  final CameraDevice camera;
  final ScrollController? scrollController;
  final bool isCompact;
  final Function(CameraEvent)? onEventTap;

  const VerticalEventTimeline({
    super.key,
    required this.camera,
    this.scrollController,
    this.isCompact = false,
    this.onEventTap,
  });

  @override
  State<VerticalEventTimeline> createState() => _VerticalEventTimelineState();
}

class _VerticalEventTimelineState extends State<VerticalEventTimeline> {
  String _selectedFilter = 'TODOS';

  @override
  Widget build(BuildContext context) {
    final allEvents = CameraEventService.instance.getEventsForCamera(widget.camera);

    final filteredEvents = allEvents.where((e) {
      if (_selectedFilter == 'TODOS') return true;
      if (_selectedFilter == 'PESSOAS') return e.type == CameraEventType.person;
      if (_selectedFilter == 'VEÍCULOS') return e.type == CameraEventType.vehicle;
      if (_selectedFilter == 'MOVIMENTO') return e.type == CameraEventType.motion;
      if (_selectedFilter == 'ALARMES') return e.type == CameraEventType.alarm;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with event count and title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: BCamTheme.accentLightBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(FluentIcons.timeline_progress, size: 16, color: BCamTheme.accentLightBlue),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Linha do Tempo de Eventos',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: BCamTheme.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BCamTheme.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                ),
                child: Text(
                  '${filteredEvents.length} eventos',
                  style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterPill('TODOS', allEvents.length),
              const SizedBox(width: 6),
              _buildFilterPill('PESSOAS', allEvents.where((e) => e.type == CameraEventType.person).length),
              const SizedBox(width: 6),
              _buildFilterPill('VEÍCULOS', allEvents.where((e) => e.type == CameraEventType.vehicle).length),
              const SizedBox(width: 6),
              _buildFilterPill('MOVIMENTO', allEvents.where((e) => e.type == CameraEventType.motion).length),
              const SizedBox(width: 6),
              _buildFilterPill('ALARMES', allEvents.where((e) => e.type == CameraEventType.alarm).length),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Events List or Empty State
        if (filteredEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.search_issue, size: 32, color: BCamTheme.textTertiary),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhum evento registrado nesta categoria.',
                    style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            controller: widget.scrollController,
            shrinkWrap: true,
            physics: widget.scrollController != null ? null : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredEvents.length,
            itemBuilder: (context, index) {
              final event = filteredEvents[index];
              final isLast = index == filteredEvents.length - 1;
              return _buildTimelineItem(event, isLast);
            },
          ),
      ],
    );
  }

  Widget _buildFilterPill(String filter, int count) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? BCamTheme.accentLightBlue.withValues(alpha: 0.2) : BCamTheme.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? BCamTheme.accentLightBlue : BCamTheme.darkBorder,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filter,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? BCamTheme.accentLightBlue : BCamTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? BCamTheme.accentLightBlue : const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.robotoMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.black : BCamTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(CameraEvent event, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Rail (Timestamp & Vertical Line with Node)
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  event.timeFormatted,
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: BCamTheme.textPrimary,
                  ),
                ),
                Text(
                  event.dateFormatted,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: BCamTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Central Connector Node & Line
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: event.type.color,
                  border: Border.all(color: const Color(0xFF0F0F12), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: event.type.color.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: BCamTheme.darkBorder,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 10),

          // Event Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () {
                  if (widget.onEventTap != null) {
                    widget.onEventTap!(event);
                  } else {
                    _showEventPlaybackDialog(event);
                  }
                },
                child: Card(
                  backgroundColor: BCamTheme.darkSurface,
                  borderColor: event.isFlagged ? BCamTheme.statusOffline.withValues(alpha: 0.6) : BCamTheme.darkBorder,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: event.type.color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: event.type.color.withValues(alpha: 0.5), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(event.type.icon, size: 11, color: event.type.color),
                                const SizedBox(width: 4),
                                Text(
                                  event.type.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: event.type.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0x73000000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(FluentIcons.stopwatch, size: 10, color: BCamTheme.textTertiary),
                                const SizedBox(width: 3),
                                Text(
                                  event.durationFormatted,
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 9.5,
                                    color: BCamTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Description
                      Text(
                        event.description,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: BCamTheme.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Simulated Video Clip Snapshot Bar
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141418),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x1AFFFFFF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: double.infinity,
                              decoration: const BoxDecoration(
                                color: Color(0x8A000000),
                                borderRadius: BorderRadius.horizontal(left: Radius.circular(5)),
                              ),
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(event.type.icon, size: 20, color: event.type.color.withValues(alpha: 0.7)),
                                    const Icon(FluentIcons.play, size: 14, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Clipe NVR Gravado',
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                  Text(
                                    'IA: ${(event.confidence * 100).toInt()}% • Toque para reproduzir',
                                    style: GoogleFonts.inter(fontSize: 9.5, color: BCamTheme.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(FluentIcons.chevron_right, size: 12, color: BCamTheme.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEventPlaybackDialog(CameraEvent event) {
    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: Row(
            children: [
              Icon(event.type.icon, size: 18, color: event.type.color),
              const SizedBox(width: 8),
              Text(
                'Reprodução: ${event.type.label}',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${event.cameraName} • ${event.timeFormatted} (${event.dateFormatted})',
                style: GoogleFonts.robotoMono(fontSize: 12, color: BCamTheme.accentLightBlue),
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                style: GoogleFonts.inter(fontSize: 13, color: BCamTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BCamTheme.darkBorder),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(FluentIcons.play, size: 36, color: BCamTheme.accentLightBlue),
                      const SizedBox(height: 8),
                      Text(
                        'Buffer de gravação de ${event.durationFormatted}',
                        style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                      ),
                      Text(
                        'Origem: NVR Local / Cartão SD',
                        style: GoogleFonts.robotoMono(fontSize: 10, color: BCamTheme.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                displayInfoBar(
                  context,
                  builder: (context, close) => InfoBar(
                    title: const Text('Clipe NVR em Execução'),
                    content: Text('Reproduzindo trecho gravado às ${event.timeFormatted} (${event.durationFormatted}).'),
                    severity: InfoBarSeverity.info,
                    onClose: close,
                  ),
                );
              },
              child: const Text('Iniciar Reprodução'),
            ),
          ],
        );
      },
    );
  }
}
