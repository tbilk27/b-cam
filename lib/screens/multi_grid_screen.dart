import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/camera_storage_service.dart';
import '../theme/gta_colors.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: const Text('MATRIZ DE MONITORAMENTO'),
        ),
        actions: [
          IconButton(
            tooltip: '1 Coluna',
            icon: Icon(Icons.crop_square_rounded, color: _gridColumns == 1 ? GtaColors.neonPink : Colors.white60),
            onPressed: () => setState(() => _gridColumns = 1),
          ),
          IconButton(
            tooltip: '2 Colunas (Quad)',
            icon: Icon(Icons.grid_view_rounded, color: _gridColumns == 2 ? GtaColors.neonPink : Colors.white60),
            onPressed: () => setState(() => _gridColumns = 2),
          ),
          IconButton(
            tooltip: '3 Colunas',
            icon: Icon(Icons.view_comfy_rounded, color: _gridColumns == 3 ? GtaColors.neonPink : Colors.white60),
            onPressed: () => setState(() => _gridColumns = 3),
          ),
        ],
      ),
      body: cameras.isEmpty
          ? Center(
              child: Text(
                'Nenhuma câmera comissionada para exibir.',
                style: GoogleFonts.rajdhani(fontSize: 16, color: Colors.white60),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: _gridColumns == 1 ? 16 / 9 : 16 / 12,
              ),
              itemCount: cameras.length,
              itemBuilder: (context, index) {
                final cam = cameras[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CameraDetailScreen(camera: cam),
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: LivePlayerView(
                          camera: cam,
                          autoPlay: true,
                          isMiniature: true,
                        ),
                      ),
                      // Overlay click badge
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
