import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/camera_device.dart';
import '../services/camera_action_service.dart';
import '../theme/fluent_theme.dart';

/// Reusable surveillance action controls bar:
/// Siren, Spotlight/Light, Two-way Audio (Walkie-talkie Talk/Listen), and Night Vision.
class CameraActionsBar extends StatefulWidget {
  final CameraDevice camera;
  final bool isCompact;

  const CameraActionsBar({
    super.key,
    required this.camera,
    this.isCompact = false,
  });

  @override
  State<CameraActionsBar> createState() => _CameraActionsBarState();
}

class _CameraActionsBarState extends State<CameraActionsBar> {
  final _actionService = CameraActionService.instance;

  @override
  void initState() {
    super.initState();
    _actionService.addListener(_onActionUpdate);
  }

  @override
  void dispose() {
    _actionService.removeListener(_onActionUpdate);
    super.dispose();
  }

  void _onActionUpdate() {
    if (mounted) setState(() {});
  }

  void _toggleSiren() async {
    final active = await _actionService.toggleSiren(widget.camera);
    if (!mounted) return;
    displayInfoBar(
      context,
      duration: const Duration(seconds: 3),
      builder: (context, close) => InfoBar(
        title: Text(active ? '🚨 Sirene Disparada' : 'Sirene Desativada'),
        content: Text(
          active
              ? 'Alarme sonoro acionado na câmera "${widget.camera.name}".'
              : 'Alarme sonoro cancelado.',
        ),
        severity: active ? InfoBarSeverity.error : InfoBarSeverity.info,
        onClose: close,
      ),
    );
  }

  void _toggleSpotlight() async {
    final active = await _actionService.toggleSpotlight(widget.camera);
    if (!mounted) return;
    displayInfoBar(
      context,
      duration: const Duration(seconds: 3),
      builder: (context, close) => InfoBar(
        title: Text(active ? '💡 Holofote Aceso' : 'Holofote Apagado'),
        content: Text(
          active
              ? 'Luz LED branca da câmera ligada para iluminação local.'
              : 'Luz LED branca apagada.',
        ),
        severity: InfoBarSeverity.info,
        onClose: close,
      ),
    );
  }

  void _toggleListen() {
    final active = _actionService.toggleListening(widget.camera);
    displayInfoBar(
      context,
      duration: const Duration(seconds: 2),
      builder: (context, close) => InfoBar(
        title: Text(active ? '🔊 Ouvindo Ambiente' : '🔇 Mudo'),
        content: Text(active ? 'Canal de áudio da câmera aberto.' : 'Áudio silenciado.'),
        severity: InfoBarSeverity.info,
        onClose: close,
      ),
    );
  }

  void _showNightVisionPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        final currentMode = _actionService.getNightVisionMode(widget.camera.id);
        return ContentDialog(
          title: Row(
            children: [
              const Icon(FluentIcons.clear_night, size: 18, color: BCamTheme.accentLightBlue),
              const SizedBox(width: 8),
              Text(
                'Visão Noturna: ${widget.camera.name}',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: NightVisionMode.values.map((mode) {
              final isSelected = mode == currentMode;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(
                    mode == NightVisionMode.color
                        ? FluentIcons.lightbulb
                        : (mode == NightVisionMode.ir ? FluentIcons.clear_night : FluentIcons.sync),
                    size: 16,
                    color: isSelected ? BCamTheme.statusOnlineGlow : BCamTheme.textSecondary,
                  ),
                  title: Text(
                    mode.label,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? Colors.white : BCamTheme.textSecondary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(FluentIcons.check_mark, size: 14, color: BCamTheme.statusOnlineGlow)
                      : null,
                  onPressed: () {
                    _actionService.setNightVisionMode(widget.camera, mode);
                    Navigator.of(ctx).pop();
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSiren = _actionService.isSirenActive(widget.camera.id);
    final isLight = _actionService.isSpotlightActive(widget.camera.id);
    final isTalking = _actionService.isTalking(widget.camera.id);
    final isListening = _actionService.isListening(widget.camera.id);
    final nightMode = _actionService.getNightVisionMode(widget.camera.id);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: widget.isCompact ? 6 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Sirene
          _buildActionButton(
            icon: FluentIcons.ringer,
            label: 'Sirene',
            isActive: isSiren,
            activeColor: const Color(0xFFFF3B30),
            onTap: _toggleSiren,
          ),

          // 2. Luz / Holofote
          _buildActionButton(
            icon: isLight ? FluentIcons.lightbulb : FluentIcons.light,
            label: 'Holofote',
            isActive: isLight,
            activeColor: const Color(0xFFFFCC00),
            onTap: _toggleSpotlight,
          ),

          // 3. Falar (Interfone Push-to-Talk)
          GestureDetector(
            onLongPressStart: (_) => _actionService.startTalking(widget.camera),
            onLongPressEnd: (_) => _actionService.stopTalking(widget.camera),
            child: _buildActionButton(
              icon: isTalking ? FluentIcons.microphone : FluentIcons.record2,
              label: isTalking ? 'Falando...' : 'Segure p/ Falar',
              isActive: isTalking,
              activeColor: BCamTheme.statusOnlineGlow,
              onTap: () {
                displayInfoBar(
                  context,
                  builder: (c, close) => InfoBar(
                    title: const Text('Interfone'),
                    content: const Text('Mantenha o botão pressionado para falar no alto-falante da câmera.'),
                    severity: InfoBarSeverity.info,
                    onClose: close,
                  ),
                );
              },
            ),
          ),

          // 4. Ouvir (Microfone da Câmera)
          _buildActionButton(
            icon: isListening ? FluentIcons.volume3 : FluentIcons.volume0,
            label: isListening ? 'Ouvindo' : 'Mudo',
            isActive: isListening,
            activeColor: BCamTheme.accentLightBlue,
            onTap: _toggleListen,
          ),

          // 5. Visão Noturna
          _buildActionButton(
            icon: FluentIcons.clear_night,
            label: nightMode == NightVisionMode.auto
                ? 'Noturna: Auto'
                : (nightMode == NightVisionMode.color ? 'Noturna: Cor' : 'Noturna: IR'),
            isActive: nightMode != NightVisionMode.off,
            activeColor: BCamTheme.accentLightBlue,
            badge: nightMode == NightVisionMode.color ? 'COR' : (nightMode == NightVisionMode.ir ? 'IR' : null),
            onTap: _showNightVisionPicker,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
    String? badge,
  }) {
    final effectiveColor = isActive
        ? (activeColor ?? BCamTheme.statusOnlineGlow)
        : BCamTheme.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: widget.isCompact ? 34 : 40,
                height: widget.isCompact ? 34 : 40,
                decoration: BoxDecoration(
                  color: isActive ? effectiveColor.withValues(alpha: 0.18) : const Color(0xFF22222B),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? effectiveColor : const Color(0xFF33333F),
                    width: 0.9,
                  ),
                ),
                child: Center(
                  child: Icon(icon, size: widget.isCompact ? 16 : 19, color: effectiveColor),
                ),
              ),
              if (badge != null)
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.8),
                    decoration: BoxDecoration(
                      color: effectiveColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.robotoMono(fontSize: 7.5, fontWeight: FontWeight.w800, color: Colors.black),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: widget.isCompact ? 9 : 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: effectiveColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
