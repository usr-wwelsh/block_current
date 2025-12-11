import 'package:block_current/features/radar/presentation/radar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:block_current/features/onboarding/presentation/city_selection_screen.dart'; // Import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Offline Caching (NATIVE ONLY)
  if (!kIsWeb) {
    try {
      await FMTCObjectBoxBackend().initialise();
      await const FMTCStore('caching').manage.create();
    } catch (e) {
      debugPrint("FMTC Init Error: $e");
    }
  }
  
  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Current',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
            primary: Colors.greenAccent,
            secondary: Colors.cyanAccent,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const CitySelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
