
import 'package:uuid/uuid.dart';

enum VibeType {
  safety,   // Red
  resource, // Yellow
  joy,      // Green
  notice,   // Blue
}

class Pulse {
  final String id;
  final VibeType type;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? content; // Null if only heard via BLE Advertisement

  Pulse({
    required this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.content,
  });

  factory Pulse.create(VibeType type, double lat, double long, String? msg) {
    return Pulse(
      id: const Uuid().v4(),
      type: type,
      latitude: lat,
      longitude: long,
      timestamp: DateTime.now(),
      content: msg,
    );
  }
}
