
import 'package:block_current/features/radar/domain/pulse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:block_current/features/creation/presentation/drop_current_screen.dart'; // Import
import 'package:block_current/features/onboarding/presentation/city_selection_screen.dart'; // Import

// Mock Data Provider
// Local State Manager for Pulses (Simulates Repo for now)
final pulsesProvider = NotifierProvider<PulsesNotifier, List<Pulse>>(PulsesNotifier.new);

class PulsesNotifier extends Notifier<List<Pulse>> {
  @override
  List<Pulse> build() {
    return [
      Pulse.create(VibeType.safety, 42.3314, -83.0458, "Power outage reported on Woodward"), // Detroit coords
      Pulse.create(VibeType.joy, 42.3320, -83.0460, "Block party at Campus Martius!"),
      Pulse.create(VibeType.resource, 42.3310, -83.0450, "Free water distribution"),
      Pulse.create(VibeType.notice, 42.3330, -83.0470, "Road construction alert"),
    ];
  }

  void add(Pulse pulse) {
    state = [...state, pulse];
  }
}

final selectedPulseIdProvider = NotifierProvider<SelectedPulseIdNotifier, String?>(SelectedPulseIdNotifier.new);

// Filter Provider (null = All)
final selectedVibeFilterProvider = NotifierProvider<VibeFilterNotifier, VibeType?>(VibeFilterNotifier.new);

class VibeFilterNotifier extends Notifier<VibeType?> {
  @override
  VibeType? build() => null;
  
  void set(VibeType? type) {
    state = type;
  }
}

class SelectedPulseIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  
  void select(String? id) {
    state = id;
  }
}

class RadarScreen extends ConsumerStatefulWidget {
  final String cityId;
  final LatLng initialCenter;

  const RadarScreen({
    super.key, 
    this.cityId = "DETROIT", 
    this.initialCenter = const LatLng(42.3314, -83.0458),
  });

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;

  bool _showLabels = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // RATE LIMITING STATE
  final List<DateTime> _recentPosts = [];

  bool _checkRateLimit() {
    final now = DateTime.now();
    // 1. Clean up old posts (older than 10 mins)
    _recentPosts.removeWhere((t) => now.difference(t).inMinutes >= 10);
    
    // 2. Check 10s Cooldown
    if (_recentPosts.isNotEmpty) {
      final last = _recentPosts.last;
      final diff = now.difference(last);
      if (diff.inSeconds < 10) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Cooldown: Wait ${10 - diff.inSeconds}s."),
          backgroundColor: Colors.redAccent,
        ));
        return false;
      }
    }

    // 3. Check 5 posts in 10 mins
    if (_recentPosts.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Rate limit: Max 5 drops per 10 mins."),
        backgroundColor: Colors.redAccent,
      ));
      return false;
    }
    
    return true;
  }

  void _recordPost() {
    _recentPosts.add(DateTime.now());
  }

  bool _isPinning = false; // State for Picking Location

  // Coarse-Grain Logic (Round to nearest ~50m)
  // 1 deg Lat ~= 111km. 0.0005 ~= 55m.
  double _fuzz(double val) {
    return (val / 0.0005).round() * 0.0005;
  }

  @override
  Widget build(BuildContext context) {
    final allPulses = ref.watch(pulsesProvider);
    final activeFilter = ref.watch(selectedVibeFilterProvider);
    
    // FILTER: Only show pulses within 200 Miles (321 km) of the City Center
    // AND match the active filter (if any)
    const Distance distance = Distance();
    final pulses = allPulses.where((p) {
      final double mi = distance.as(LengthUnit.Mile, LatLng(p.latitude, p.longitude), widget.initialCenter);
      if (mi > 200) return false;
      
      if (activeFilter != null && p.type != activeFilter) return false;
      
      return true;
    }).toList();

    final selectedId = ref.watch(selectedPulseIdProvider);

    ref.listen(selectedPulseIdProvider, (prev, next) {
      if (next != null) {
        final activePulse = pulses.firstWhere((p) => p.id == next);
        _mapController.move(LatLng(activePulse.latitude, activePulse.longitude), 16.0);
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return Scaffold(
          backgroundColor: Colors.black,
          body: Row(
            children: [
              if (!isMobile)
                SizedBox(
                  width: 300,
                  child: _buildSidebar(pulses, selectedId),
                ),
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: widget.initialCenter,
                        initialZoom: 15.0,
                        backgroundColor: Colors.black,
                        onTap: (_, __) {
                          ref.read(selectedPulseIdProvider.notifier).select(null);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _showLabels 
                              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                              : 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.blockcurrent.app',
                          tileProvider: kIsWeb 
                              ? NetworkTileProvider() 
                              : const FMTCStore('caching').getTileProvider(),
                        ),
                        // HIDE MARKERS WHEN PINNING TO REDUCE CLUTTER
                        if (!_isPinning)
                          MarkerLayer(
                            markers: pulses.map((pulse) {
                              final isSelected = pulse.id == selectedId;
                              return Marker(
                                point: LatLng(pulse.latitude, pulse.longitude),
                                width: 50,
                                height: 50,
                                child: Tooltip(
                                  message: "${pulse.content ?? 'Unknown'} @ ${pulse.timestamp.hour}:${pulse.timestamp.minute}",
                                  waitDuration: const Duration(milliseconds: 500),
                                  textStyle: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(4)),
                                  child: GestureDetector(
                                    onTap: () {
                                       ref.read(selectedPulseIdProvider.notifier).select(pulse.id);
                                       if (isMobile) {
                                         _showMobileDetails(context, pulse);
                                       }
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (isSelected)
                                          AnimatedBuilder(
                                            animation: _pulseController,
                                            builder: (context, child) {
                                              return Container(
                                                width: 30 + (_pulseController.value * 20),
                                                height: 30 + (_pulseController.value * 20),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white.withValues(alpha: 1.0 - _pulseController.value), 
                                                    width: 2
                                                  ),
                                                ),
                                              );
                                            }
                                          ),
                                        Container(
                                          width: isSelected ? 14 : 10,
                                          height: isSelected ? 14 : 10,
                                          decoration: BoxDecoration(
                                            color: _getColorForVibe(pulse.type),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: _getColorForVibe(pulse.type).withValues(alpha: 0.8),
                                                blurRadius: isSelected ? 15 : 8,
                                                spreadRadius: isSelected ? 4 : 1,
                                              )
                                            ]
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                    
                    _buildLegend(activeFilter),
                    
                    // CROSSHAIR FOR PINNING
                    if (_isPinning)
                      Center(
                        child: Icon(Icons.add_circle_outline, color: Colors.white.withValues(alpha: 0.8), size: 40),
                      ),
                    
                    // CONTROLS OVERLAY
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!_isPinning) ...[
                            FloatingActionButton.small(
                              heroTag: "labels",
                              backgroundColor: Colors.grey[900],
                              foregroundColor: Colors.white,
                              onPressed: () => setState(() => _showLabels = !_showLabels),
                              child: Icon(_showLabels ? Icons.layers_clear : Icons.layers),
                            ),
                            const SizedBox(height: 10),
                            FloatingActionButton(
                              heroTag: "location",
                              backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                              foregroundColor: Colors.greenAccent,
                              onPressed: () {
                                _mapController.move(widget.initialCenter, 16.0);
                              },
                              child: const Icon(Icons.my_location),
                            ),
                            const SizedBox(height: 20),
                          ],
                          
                          // PINNING CONTROLS
                          if (_isPinning)
                             Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 FloatingActionButton.extended(
                                   heroTag: "cancel",
                                   backgroundColor: Colors.red,
                                   foregroundColor: Colors.white,
                                   label: const Text("CANCEL", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                                   icon: const Icon(Icons.close),
                                   onPressed: () => setState(() => _isPinning = false),
                                 ),
                                 const SizedBox(width: 10),
                               ],
                             ),

                          // DROP BUTTON (CHANGES FUNCTION)
                          FloatingActionButton.extended(
                            heroTag: "drop",
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            label: Text(_isPinning ? "CONFIRM LOCATION" : "DROP CURRENT", style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                            icon: Icon(_isPinning ? Icons.check : Icons.bolt),
                            onPressed: () async {
                               if (!_isPinning) {
                                 // Enter Pinning Mode
                                 if (_checkRateLimit()) {
                                   setState(() => _isPinning = true);
                                 }
                               } else {
                                 // CONFIRM LOCATION
                                 final center = _mapController.camera.center;
                                 
                                 // Apply Coarse Fuzzing
                                 final fuzzedLat = _fuzz(center.latitude);
                                 final fuzzedLng = _fuzz(center.longitude);
                                 
                                 // Navigate to Form
                                 final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const DropCurrentScreen()));
                                 
                                 setState(() => _isPinning = false); // Reset
                                 
                                 if (result != null) {
                                     // Create the Pulse with Fuzzed Coords
                                     final newPulse = Pulse.create(
                                       result['type'], 
                                       fuzzedLat, 
                                       fuzzedLng, 
                                       result['msg']
                                     );
                                     
                                     // ADD TO STATE (So it appears on map)
                                     ref.read(pulsesProvider.notifier).add(newPulse);
                                     
                                     // Record for Rate Limit
                                     _recordPost();
                                     
                                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Dropped @ $fuzzedLat, $fuzzedLng (Fuzzed)")));
                                 }
                               }
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // ON MOBILE: Simple Header & Menu
                    if (isMobile)
                      Positioned(
                         top: 40,
                         left: 20,
                         child: Row(
                           children: [
                             Builder(
                               builder: (context) {
                                 return FloatingActionButton.small(
                                   heroTag: "menu",
                                   backgroundColor: Colors.white,
                                   foregroundColor: Colors.black,
                                   onPressed: () => Scaffold.of(context).openDrawer(),
                                   child: const Icon(Icons.menu),
                                 );
                               }
                             ),
                             const SizedBox(width: 10),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white12)),
                               child: const Text("BLOCK CURRENT // MOBILE", style: TextStyle(fontFamily: 'Courier', color: Colors.white)),
                             ),
                           ],
                         ),
                      )
                  ],
                ),
              ),
            ],
          ),
          drawer: isMobile ? Drawer(child: Container(color: const Color(0xFF222222), child: _buildSidebar(pulses, selectedId))) : null,
        );
      }
    );
  }

  Widget _buildSidebar(List<Pulse> pulses, String? selectedId) {
    return Container(
      color: const Color(0xFF222222), // Dark Gray
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "BLOCK CURRENT // ${widget.cityId}",
                  style: TextStyle(
                    fontFamily: 'Courier', 
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(builder: (_) => const CitySelectionScreen())
                    );
                  },
                  child: const Icon(Icons.swap_horiz, color: Colors.greenAccent, size: 20),
                )
              ],
            ),
          ),
          Container(height: 1, color: Colors.grey[800]),
          Expanded(
            child: ListView.builder(
              itemCount: pulses.length,
              itemBuilder: (context, index) {
                final pulse = pulses[index];
                final isSelected = pulse.id == selectedId;
                return InkWell(
                  onTap: () {
                    ref.read(selectedPulseIdProvider.notifier).select(pulse.id);
                  },
                  child: Container(
                    color: isSelected ? Colors.grey[800] : Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getColorForVibe(pulse.type),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pulse.id.substring(0, 8).toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "${pulse.timestamp.hour}:${pulse.timestamp.minute}",
                              style: const TextStyle(color: Colors.white24, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (pulse.content != null)
                          Text(
                            pulse.content!,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          "LAT: ${pulse.latitude.toStringAsFixed(4)}  LNG: ${pulse.longitude.toStringAsFixed(4)}",
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            color: Colors.white30,
                            fontSize: 10
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileDetails(BuildContext context, Pulse pulse) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(children: [
                Icon(Icons.circle, color: _getColorForVibe(pulse.type), size: 12),
                const SizedBox(width: 10),
                Text(pulse.content ?? "Pulse Signal", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
             ]),
             const SizedBox(height: 10),
             Text("ID: ${pulse.id}", style: const TextStyle(fontFamily: "Courier", color: Colors.grey)),
             const Spacer(),
             ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE"))
          ],
        ),
      )
    );
  }

  Widget _buildLegend(VibeType? activeFilter) {
    return Positioned(
      top: 50,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text("TYPE // FILTER", style: TextStyle(fontFamily: 'Courier', color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             ...VibeType.values.map((type) {
               final isActive = activeFilter == type;
               final isDimmed = activeFilter != null && !isActive;
               return GestureDetector(
                 onTap: () {
                   ref.read(selectedVibeFilterProvider.notifier).set(isActive ? null : type);
                 },
                 child: Padding(
                   padding: const EdgeInsets.only(bottom: 6),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text(
                         type.name.toUpperCase(), 
                         style: TextStyle(
                           fontFamily: 'Courier', 
                           color: isDimmed ? Colors.white24 : Colors.white, 
                           fontSize: 12,
                           fontWeight: isActive ? FontWeight.bold : FontWeight.normal
                         )
                       ),
                       const SizedBox(width: 8),
                       Container(
                         width: 12,
                         height: 12,
                         decoration: BoxDecoration(
                           color: _getColorForVibe(type).withValues(alpha: isDimmed ? 0.2 : 1.0),
                           shape: BoxShape.circle,
                           border: isActive ? Border.all(color: Colors.white, width: 2) : null,
                         ),
                       ),
                     ],
                   ),
                 ),
               );
             }),
          ],
        ),
      ),
    );
  }

  Color _getColorForVibe(VibeType type) {
    switch (type) {
      case VibeType.safety: return const Color(0xFFFF0000); // Red
      case VibeType.resource: return const Color(0xFFFFD700); // Yellow
      case VibeType.joy: return const Color(0xFF00FF00); // Green
      case VibeType.notice: return const Color(0xFF00FFFF); // Cyan
    }
  }
}
