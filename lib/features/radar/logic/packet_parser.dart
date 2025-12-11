
import 'dart:convert';
import 'dart:typed_data';
import 'package:block_current/features/radar/domain/pulse.dart';

/// Utilities to compress/decompress Pulse data for limited BLE 20-byte MTU.
class PacketParser {
  
  // Format: [Type(1)][Lat(4)][Lng(4)][Time(4)][Content(Var)]
  // We heavily truncate specific precision for 3 reasons:
  // 1. Privacy (General area only)
  // 2. Bandwidth (BLE is tiny)
  // 3. Speed (Faster scans)
  
  static Uint8List encode(Pulse pulse) {
    final bytes = BytesBuilder();
    
    // 1. Vibe Type (1 byte index)
    bytes.addByte(pulse.type.index);
    
    // 2. Lat/Lng (Float32 - 4 bytes each)
    // We already fuzzed them in UI, but Float32 is standard.
    final list = Float32List.fromList([pulse.latitude, pulse.longitude]);
    bytes.add(list.buffer.asUint8List());
    
    // 3. Timestamp (Epoch Seconds - 4 bytes Int32)
    // Truncate milliseconds
    final time = pulse.timestamp.millisecondsSinceEpoch ~/ 1000;
    final timeBytes = Uint8List(4)..buffer.asByteData().setInt32(0, time, Endian.little);
    bytes.add(timeBytes);
    
    // 4. Content (UTF8 - Remaining bytes)
    // BLE packet max is usually ~20 bytes legacy, ~512 bytes extended.
    // We'll assume extended or multiple packets, but for now just append.
    if (pulse.content != null) {
      bytes.add(utf8.encode(pulse.content!));
    }
    
    return bytes.toBytes();
  }

  static Pulse? decode(String id, List<int> data) {
    try {
      final byteData = ByteData.sublistView(Uint8List.fromList(data));
      int offset = 0;
      
      // 1. Type
      final typeIndex = byteData.getUint8(offset);
      final type = VibeType.values[typeIndex % VibeType.values.length];
      offset += 1;
      
      // 2. Lat/Lng
      final lat = byteData.getFloat32(offset, Endian.little);
      offset += 4;
      final lng = byteData.getFloat32(offset, Endian.little);
      offset += 4;
      
      // 3. Time
      final timeInt = byteData.getInt32(offset, Endian.little);
      final time = DateTime.fromMillisecondsSinceEpoch(timeInt * 1000);
      offset += 4;
      
      // 4. Content
      String? content;
      if (offset < data.length) {
        content = utf8.decode(data.sublist(offset));
      }
      
      return Pulse(id, type, lat, lng, time, content);
      
    } catch (e) {
      // Corrupt packet
      return null;
    }
  }
}
