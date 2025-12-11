
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ScannerService {
  // Scanning for neighbors
  
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  
  Future<void> startScan() async {
    // Start scanning for our specific Service UUID
    await FlutterBluePlus.startScan(
       withServices: [], // Add UUID later
       timeout: const Duration(seconds: 10),
    );
  }
  
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}
