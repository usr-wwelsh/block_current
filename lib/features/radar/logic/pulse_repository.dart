
import 'package:block_current/features/radar/domain/pulse.dart';
import 'package:block_current/features/radar/logic/packet_parser.dart';
import 'package:block_current/features/radar/service/beacon_service.dart';
import 'package:block_current/features/radar/service/relay_service.dart';
import 'package:block_current/features/radar/service/scanner_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pulseRepositoryProvider = Provider((ref) => PulseRepository());

class PulseRepository {
  final BeaconService _beacon = BeaconService();
  final ScannerService _scanner = ScannerService();
  final RelayService _relay = RelayService();
  
  // Local Memory of Pulses
  final List<Pulse> _pulses = [];
  
  // THE MULE LOGIC
  Future<void> dropPulse(Pulse pulse) async {
    // 1. Save Local
    _pulses.add(pulse);
    
    // 2. Encode to BLE Packet
    final packet = PacketParser.encode(pulse);
    
    // 3. Broadcast to Neighbors (Short Range)
    await _beacon.startAdvertising(packet);
    
    // 4. Try Sync to Relay (Long Range)
    // If we are online, this "Mules" the data to the cloud immediately.
    // If offline, it stays in _beacon advertising until we hit a relay.
    await _relay.publish(pulse.content ?? "");
  }
  
  void onBlePulseDetected(List<int> data) {
    // We detected a neighbor's pulse!
    final pulse = PacketParser.decode("ble_id", data);
    if (pulse != null) {
      _pulses.add(pulse);
      // RE-BROADCAST? (Mule logic)
      // If we have internet, upload it for them.
    }
  }
}
