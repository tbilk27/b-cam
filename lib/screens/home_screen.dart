import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../services/camera_storage_service.dart';
import '../theme/gta_colors.dart';
import '../widgets/gta_button.dart';
import '../widgets/gta_logo.dart';
import '../widgets/gta_neon_card.dart';
import '../widgets/live_player_view.dart';
import 'camera_detail_screen.dart';
import 'commission_screen.dart';
import 'multi_grid_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = 'TODAS';

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<CameraStorageService>();
    final allCameras = storage.cameras;

    List<CameraDevice> filteredCameras;
    if (_selectedFilter == 'FAVORITAS') {
      filteredCameras = storage.favoriteCameras;
    } else if (_selectedFilter != 'TODAS') {
      filteredCameras = allCameras.where((c) => c.location.toUpperCase() == _selectedFilter).toList();
    } else {
      filteredCameras = allCameras;
    }

    final uniqueLocations = allCameras.map((c) => c.location.toUpperCase()).toSet().toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // GTA VI Vice City Neon App Bar
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const GtaLogo(size: 42, showText: true),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: GtaColors.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GtaColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: GtaColors.statusOnline,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'WI-FI ONLINE',
                            style: GoogleFonts.orbitron(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: GtaColors.statusOnline,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Quick Action Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    // Radar Scan Action
                    Expanded(
                      flex: 3,
                      child: GtaButton(
                        height: 48,
                        label: 'VARREDURA WI-FI',
                        icon: Icons.radar_rounded,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ScanScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Multi-view Grid Action
                    Expanded(
                      flex: 2,
                      child: GtaButton(
                        height: 48,
                        label: 'MATRIZ',
                        icon: Icons.grid_view_rounded,
                        outlined: true,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MultiGridScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add manual camera action
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: GtaColors.bgCard,
                        side: const BorderSide(color: GtaColors.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.add_rounded, color: GtaColors.electricCyan),
                      tooltip: 'Adicionar Manual',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CommissionScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Filter Tabs
            SliverToBoxAdapter(
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterChip('TODAS', allCameras.length),
                    _buildFilterChip('FAVORITAS', storage.favoriteCameras.length),
                    ...uniqueLocations.map((loc) {
                      final count = allCameras.where((c) => c.location.toUpperCase() == loc).length;
                      return _buildFilterChip(loc, count);
                    }),
                  ],
                ),
              ),
            ),

            // Camera List Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CÂMERAS ATIVAS (${filteredCameras.length})',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'RTSP / ONVIF STREAM',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: GtaColors.electricCyan,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Camera Feed Cards
            if (filteredCameras.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: GtaColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GtaColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.videocam_off_rounded, size: 54, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma câmera nesta categoria.',
                        style: GoogleFonts.rajdhani(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      GtaButton(
                        label: 'BUSCAR NA REDE WI-FI',
                        icon: Icons.radar_rounded,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ScanScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cam = filteredCameras[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildCameraCard(cam, storage),
                      );
                    },
                    childCount: filteredCameras.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        label: Text('$label ($count)'),
        labelStyle: GoogleFonts.orbitron(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : Colors.white60,
        ),
        selectedColor: GtaColors.neonPink,
        backgroundColor: GtaColors.bgCard,
        side: BorderSide(
          color: isSelected ? GtaColors.neonPink : GtaColors.borderSubtle,
        ),
        onSelected: (val) {
          if (val) setState(() => _selectedFilter = label);
        },
      ),
    );
  }

  Widget _buildCameraCard(CameraDevice cam, CameraStorageService storage) {
    return GtaNeonCard(
      padding: EdgeInsets.zero,
      borderColor: cam.manufacturer.brandColor.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Video Player Header
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CameraDetailScreen(camera: cam)),
              );
            },
            child: SizedBox(
              height: 210,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LivePlayerView(
                      camera: cam,
                      autoPlay: true,
                    ),
                  ),
                  // Fullscreen expand button overlay
                  Positioned(
                    top: 10,
                    right: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CameraDetailScreen(camera: cam)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Camera Info & Controls Footer
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Brand pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cam.manufacturer.brandColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cam.manufacturer.brandColor, width: 1),
                  ),
                  child: Text(
                    cam.manufacturer.displayName.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Camera Name and Location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cam.name,
                        style: GoogleFonts.rajdhani(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'IP: ${cam.ip}  •  ${cam.location}',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                // Favorite Star
                IconButton(
                  icon: Icon(
                    cam.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: cam.isFavorite ? GtaColors.sunsetYellow : Colors.white38,
                  ),
                  onPressed: () => storage.toggleFavorite(cam.id),
                ),
                // More options menu (edit, delete)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                  color: GtaColors.bgCard,
                  onSelected: (val) {
                    if (val == 'edit') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CommissionScreen(existingCamera: cam)),
                      );
                    } else if (val == 'delete') {
                      storage.removeCamera(cam.id);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_rounded, color: GtaColors.electricCyan, size: 18),
                          const SizedBox(width: 8),
                          Text('Editar / Recomissionar', style: GoogleFonts.rajdhani(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_forever_rounded, color: GtaColors.statusOffline, size: 18),
                          const SizedBox(width: 8),
                          Text('Excluir Câmera', style: GoogleFonts.rajdhani(color: GtaColors.statusOffline)),
                        ],
                      ),
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
