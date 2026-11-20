import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/camera_storage_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/live_player_view.dart';
import 'camera_detail_screen.dart';

class MultiGridScreen extends StatefulWidget {
  const MultiGridScreen({super.key});

  @override
  State<MultiGridScreen> createState() => _MultiGridScreenState();
}

class _MultiGridScreenState extends State<MultiGridScreen> {
  int _gridColumns = 2; // 1 = Single, 2 = 2x2 Quad, 3 = 3x3

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<CameraStorageService>();
    final cameras = storage.cameras;

    return SafeArea(
      child: ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.back, size: 16),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Matriz Grid',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                FluentIcons.rectangle_shape,
                size: 16,
                color: _gridColumns == 1 ? BCamTheme.accentLightBlue : BCamTheme.textTertiary,
              ),
              onPressed: () => setState(() => _gridColumns = 1),
            ),
            IconButton(
              icon: Icon(
                FluentIcons.view_dashboard,
                size: 16,
                color: _gridColumns == 2 ? BCamTheme.accentLightBlue : BCamTheme.textTertiary,
              ),
              onPressed: () => setState(() => _gridColumns = 2),
            ),
            IconButton(
              icon: Icon(
                FluentIcons.tiles,
                size: 16,
                color: _gridColumns == 3 ? BCamTheme.accentLightBlue : BCamTheme.textTertiary,
              ),
              onPressed: () => setState(() => _gridColumns = 3),
            ),
          ],
        ),
      ),
      content: cameras.isEmpty
          ? Center(
              child: Text(
                'Nenhuma câmera comissionada para exibir.',
                style: GoogleFonts.inter(fontSize: 14, color: BCamTheme.textSecondary),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: _gridColumns == 1 ? 16 / 9 : 16 / 12,
              ),
              itemCount: cameras.length,
              itemBuilder: (context, index) {
                final cam = cameras[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      FluentPageRoute(
                        builder: (_) => CameraDetailScreen(camera: cam),
                      ),
                    );
                  },
                  child: Card(
                    backgroundColor: BCamTheme.darkSurface,
                    borderColor: BCamTheme.darkBorder,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: LivePlayerView(
                            camera: cam,
                            autoPlay: true,
                            isMiniature: true,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: BCamTheme.darkCard,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  cam.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: BCamTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                cam.ip,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 9.5,
                                  color: BCamTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    ),
    );
  }
}
