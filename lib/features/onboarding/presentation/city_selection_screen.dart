
import 'package:block_current/features/radar/presentation/radar_screen.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:block_current/features/onboarding/logic/local_geocoder.dart'; // Import LocalGeocoder

class CitySelectionScreen extends StatefulWidget {
  const CitySelectionScreen({super.key});

  @override
  State<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends State<CitySelectionScreen> {
  final TextEditingController _cityController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Preload Data
    LocalGeocoder.load();
  }

  Future<void> _submit() async {
    final query = _cityController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    
    // Simulate slight delay for UX
    await Future.delayed(const Duration(milliseconds: 500));

    // LOCAL SEARCH
    final result = LocalGeocoder.search(query);

    if (result != null) {
         final lat = result['lat'] as double;
         final lng = result['lng'] as double;
         final name = result['name'].toString().toUpperCase();

         if (mounted) {
           Navigator.pushReplacement(
             context, 
             MaterialPageRoute(builder: (_) => RadarScreen(
               cityId: name,
               initialCenter: LatLng(lat, lng),
             ))
           );
         }
    } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text("City not found in offline DB. Try 'New York', 'Tokyo', 'London'."),
             backgroundColor: Colors.red,
           ));
        }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "BLOCK CURRENT // SYNC NODE",
                style: TextStyle(fontFamily: 'Courier', color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "Enter city name to connect to local mesh.",
                style: TextStyle(fontFamily: 'Courier', color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              TextField(
                controller: _cityController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 18),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  hintText: "DETROIT, MI",
                  hintStyle: TextStyle(color: Colors.white24),
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                ),
                onSubmitted: (_) => _submit(),
              ),
              
              const SizedBox(height: 20),
              
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                    : const Text("ACCESS MESH", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
