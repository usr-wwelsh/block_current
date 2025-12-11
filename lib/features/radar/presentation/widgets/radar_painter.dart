
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:block_current/features/radar/domain/pulse.dart';

class RadarPainter extends CustomPainter {
  final List<Pulse> pulses;
  final double currentLat;
  final double currentLong;
  final double rangeMeters; // How far the edge of the screen represents
  final double animationValue; // For the scanning sweep effect

  final String? selectedPulseId;

  RadarPainter({
    required this.pulses,
    required this.currentLat,
    required this.currentLong,
    this.rangeMeters = 500.0,
    required this.animationValue,
    this.selectedPulseId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // 1. Draw Background (Radar Screen)
    final bgPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Draw Grid (Concentric Circles)
    final gridPaint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
        canvas.drawCircle(center, radius * (i / 4), gridPaint);
    }
    
    // Crosshairs
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);

    // 3. Draw Sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.green.withOpacity(0.0), Colors.green.withOpacity(0.5)],
        stops: const [0.75, 1.0],
        transform: GradientRotation(animationValue * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius, sweepPaint);


    // 4. Draw Pulses (Blips)
    for (var pulse in pulses) {
      final offset = _latLngToOffset(pulse, center, radius);
      if (offset != null) {
          final isSelected = pulse.id == selectedPulseId;
          
          final blipPaint = Paint()
            ..color = _getColorForVibe(pulse.type)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0); // Glow
            
          canvas.drawCircle(offset, isSelected ? 8.0 : 6.0, blipPaint);
          
          // Draw a sharp core
          final corePaint = Paint()..color = Colors.white;
          canvas.drawCircle(offset, 2.0, corePaint);
          
          // Draw Selection Ring
          if (isSelected) {
             final ringPaint = Paint()
               ..color = Colors.white
               ..style = PaintingStyle.stroke
               ..strokeWidth = 2.0;
             canvas.drawCircle(offset, 12.0, ringPaint);
          }
      }
    }
  }

  Offset? _latLngToOffset(Pulse pulse, Offset center, double radius) {
    // Simplified Equirectangular projection for short distances
    // 1 deg Lat ~= 111km
    // 1 deg Long ~= 111km * cos(lat)
    
    const metersPerLat = 111000.0;
    double metersPerLng = 111000.0 * cos(currentLat * pi / 180.0);
    
    double dyMeters = (currentLat - pulse.latitude) * metersPerLat; // + Lat is Up (North), but Canvas Y is Down. 
    // Wait, Lat increases North. Canvas Y increases Down. So (Current - Pulse) is positive if Pulse is South (Down). Correct.
    
    double dxMeters = (pulse.longitude - currentLong) * metersPerLng; // + Long is East (Right). Canvas X is Right. Correct.
    
    // Scale to radius
    // rangeMeters is the radius distance
    double scale = radius / rangeMeters;
    
    double dx = dxMeters * scale;
    double dy = dyMeters * scale; 
    
    // Check if out of bounds (circular clip)
    if (dx*dx + dy*dy > radius*radius) return null;
    
    return center + Offset(dx, dy);
  }

  Color _getColorForVibe(VibeType type) {
    switch (type) {
      case VibeType.safety: return Colors.redAccent;
      case VibeType.resource: return Colors.yellowAccent;
      case VibeType.joy: return Colors.greenAccent;
      case VibeType.notice: return Colors.cyanAccent;
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.pulses != pulses;
  }
}
