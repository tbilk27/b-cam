import 'dart:math';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../services/camera_event_service.dart';
import '../theme/fluent_theme.dart';
import 'event_playback_dialog.dart';

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
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'TODOS';
  double _zoomScale = 1.0; // 0.75x, 1.0x, 1.5x, 2.0x
  String? _activeScrubberTime;

  @override
  void initState() {
    super.initState();
    _activeScrubberTime = DateFormat('HH:mm:ss').format(DateTime.now());
    CameraEventService.instance.addListener(_onEventsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CameraEventService.instance.ensureEventsForCamera(widget.camera);
    });
  }

  void _onEventsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CameraEventService.instance.removeListener(_onEventsChanged);
    super.dispose();
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    final now = DateTime.now();
    if (_selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day) {
      return; // Já está em Hoje
    }
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  String get _dateLabel {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (_selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day) {
      return 'Hoje';
    } else if (_selectedDate.year == yesterday.year &&
        _selectedDate.month == yesterday.month &&
        _selectedDate.day == yesterday.day) {
      return 'Ontem';
    } else {
      return DateFormat('dd/MM/yyyy').format(_selectedDate);
    }
  }

  void _zoomIn() {
    setState(() {
      _zoomScale = min(2.5, _zoomScale + 0.25);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomScale = max(0.6, _zoomScale - 0.25);
    });
  }

  void _showFilterFlyout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text(
          'Filtrar Eventos da Câmera',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterRadioItem('TODOS', 'Todos os Eventos', FluentIcons.all_currency),
            _buildFilterRadioItem('PESSOAS', 'Presença Humana (IA)', FluentIcons.contact),
            _buildFilterRadioItem('VEÍCULOS', 'Veículos Detectados (IA)', FluentIcons.car),
            _buildFilterRadioItem('MOVIMENTO', 'Movimento Geral (PIR/VMD)', FluentIcons.running),
            _buildFilterRadioItem('ALARMES', 'Disparos de Alarme', FluentIcons.alarm_clock),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Aplicar Filtro'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRadioItem(String key, String label, IconData icon) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          size: 16,
          color: isSelected ? BCamTheme.statusOnlineGlow : BCamTheme.textSecondary,
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : BCamTheme.textSecondary,
          ),
        ),
        trailing: isSelected
            ? const Icon(FluentIcons.check_mark, size: 14, color: BCamTheme.statusOnlineGlow)
            : null,
        onPressed: () {
          setState(() {
            _selectedFilter = key;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final showSubHeader = constraints.maxHeight >= 70;

        return Column(
          children: [
            if (showSubHeader) ...[
              // 1. Sub-Header Bar (< Hoje > | Funil | Visualização do evento 🔴)
              _buildSubHeaderBar(context),
              const SizedBox(height: 4),
            ],

            // 2. Timeline Body with Ruler, Event Cards, and Floating Zoom Buttons
            Expanded(
              child: Stack(
                children: [
              // Main scrollable timeline
              filteredEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(FluentIcons.search_issue, size: 36, color: BCamTheme.textTertiary),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhum evento registrado nesta data.',
                            style: GoogleFonts.inter(fontSize: 12.5, color: BCamTheme.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'O Agente de IA monitora continuamente o fluxo da câmera.',
                            style: GoogleFonts.robotoMono(fontSize: 10, color: BCamTheme.textTertiary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: EdgeInsets.fromLTRB(8, 12, widget.isCompact ? 44 : 56, 24),
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];
                        final isFirst = index == 0;
                        final isLast = index == filteredEvents.length - 1;
                        return _buildTimelineRow(event, isFirst, isLast);
                      },
                    ),

              // Floating Zoom Controls on the Right (+ and - buttons)
              Positioned(
                right: widget.isCompact ? 6 : 12,
                top: 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildZoomButton(
                      icon: FluentIcons.add,
                      tooltip: 'Aproximar Escala (+)',
                      onPressed: _zoomIn,
                    ),
                    const SizedBox(height: 8),
                    _buildZoomButton(
                      icon: FluentIcons.remove,
                      tooltip: 'Afastar Escala (-)',
                      onPressed: _zoomOut,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  },
);
  }

  Widget _buildSubHeaderBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: BCamTheme.darkSurface,
        border: Border(
          bottom: BorderSide(color: BCamTheme.darkBorder, width: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: < Hoje > Date Navigation Pill & Filter Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date Pill Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: BCamTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(FluentIcons.chevron_left, size: 12, color: BCamTheme.textSecondary),
                      onPressed: _previousDay,
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        // Quick switch between Hoje and Ontem
                        if (_dateLabel == 'Hoje') {
                          _previousDay();
                        } else {
                          setState(() => _selectedDate = DateTime.now());
                        }
                      },
                      child: Text(
                        _dateLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: BCamTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(FluentIcons.chevron_right, size: 12, color: BCamTheme.textSecondary),
                      onPressed: _dateLabel == 'Hoje' ? null : _nextDay,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Filter Funnel Button
              GestureDetector(
                onTap: () => _showFilterFlyout(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _selectedFilter != 'TODOS'
                        ? BCamTheme.statusOnlineGlow.withValues(alpha: 0.2)
                        : BCamTheme.darkCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedFilter != 'TODOS'
                          ? BCamTheme.statusOnlineGlow
                          : BCamTheme.darkBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      FluentIcons.filter,
                      size: 13,
                      color: _selectedFilter != 'TODOS'
                          ? BCamTheme.statusOnlineGlow
                          : BCamTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Right: Visualização do evento 🔴
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.isCompact ? 'Eventos' : 'Visualização do evento',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BCamTheme.statusOnlineGlow,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30), // Red dot indicator
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(CameraEvent event, bool isFirst, bool isLast) {
    final itemHeight = 90.0 * _zoomScale;

    return SizedBox(
      height: itemHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Time Label on the Far Left (e.g. 15:48, 14:02)
          SizedBox(
            width: 46,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  DateFormat('HH:mm').format(event.timestamp),
                  style: GoogleFonts.robotoMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: BCamTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),

          // 2. Vertical Ruler Track with Active Green Pill Scrubber
          SizedBox(
            width: (isFirst && !widget.isCompact) ? 76 : 28,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Continuous Vertical Ruler Rail
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: (isFirst && !widget.isCompact) ? 68 : 12,
                  child: Container(
                    width: 3.5,
                    color: const Color(0xFF2C2C34),
                  ),
                ),

                // Green Event Notch on Ruler
                Positioned(
                  top: itemHeight * 0.25,
                  bottom: itemHeight * 0.25,
                  left: (isFirst && !widget.isCompact) ? 68 : 12,
                  child: Container(
                    width: 3.5,
                    color: BCamTheme.statusOnlineGlow,
                  ),
                ),

                // Horizontal Green Connector Notch
                Positioned(
                  top: itemHeight * 0.45,
                  left: (isFirst && !widget.isCompact) ? 60 : 8,
                  child: Container(
                    width: 12,
                    height: 2,
                    color: BCamTheme.statusOnlineGlow,
                  ),
                ),

                // Active Scrubber Badge on First/Selected Event (16:19:47)
                if (isFirst && !widget.isCompact && _activeScrubberTime != null)
                  Positioned(
                    top: itemHeight * 0.35,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C853).withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        _activeScrubberTime!,
                        style: GoogleFonts.robotoMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 3. Event Clip Card (Center / Right)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                onTap: () {
                  final groupClips = _resolveClipsForCluster(event);
                  if (widget.onEventTap != null) {
                    widget.onEventTap!(event);
                  } else {
                    EventPlaybackDialog.show(
                      context,
                      event,
                      widget.camera,
                      groupClips,
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF202026),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF33333E),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Clip Information (Title / Clipes / Duration)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _resolveClipCountLabel(event),
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33FFFFFF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    event.durationFormatted,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: BCamTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(event.type.icon, size: 12, color: event.type.color),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${event.type.label} (${(event.confidence * 100).toInt()}%)',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: event.type.color,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Play Triangle Button Icon
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            FluentIcons.play,
                            size: 13,
                            color: Colors.white,
                          ),
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

  String _resolveClipCountLabel(CameraEvent event) {
    final count = _resolveClipCount(event);
    return '$count ${count == 1 ? "clipe" : "clipes"}';
  }

  int _resolveClipCount(CameraEvent event) {
    if (event.type == CameraEventType.person) return 5;
    if (event.type == CameraEventType.vehicle) return 2;
    if (event.type == CameraEventType.motion) return 3;
    return 4;
  }

  List<CameraEvent> _resolveClipsForCluster(CameraEvent primaryEvent) {
    final count = _resolveClipCount(primaryEvent);
    if (count <= 1) return [primaryEvent];

    final list = <CameraEvent>[primaryEvent];
    for (int i = 1; i < count; i++) {
      final offsetSeconds = i * 20;
      final subTime = primaryEvent.timestamp.add(Duration(seconds: offsetSeconds));
      list.add(
        CameraEvent(
          id: '${primaryEvent.id}_clip_$i',
          cameraId: primaryEvent.cameraId,
          cameraName: primaryEvent.cameraName,
          type: primaryEvent.type,
          timestamp: subTime,
          duration: Duration(seconds: max(6, primaryEvent.duration.inSeconds - (i * 2))),
          description: '${primaryEvent.description} • Seq. #$i',
          confidence: primaryEvent.confidence,
          boundingBoxes: primaryEvent.boundingBoxes,
          sceneInterpretation: primaryEvent.sceneInterpretation,
          clipUrl: primaryEvent.clipUrl,
        ),
      );
    }
    return list;
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: BCamTheme.darkSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BCamTheme.darkBorder, width: 0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, size: 14, color: BCamTheme.textPrimary),
          ),
        ),
      ),
    );
  }
}
