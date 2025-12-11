
import 'package:block_current/features/radar/domain/pulse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DropCurrentScreen extends ConsumerStatefulWidget {
  const DropCurrentScreen({super.key});

  @override
  ConsumerState<DropCurrentScreen> createState() => _DropCurrentScreenState();
}

class _DropCurrentScreenState extends ConsumerState<DropCurrentScreen> {
  VibeType _selectedVibe = VibeType.joy;
  final TextEditingController _msgController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("DROP CURRENT", style: TextStyle(fontFamily: 'Courier', color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SELECT VIBE //", style: TextStyle(fontFamily: 'Courier', color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: VibeType.values.map((vibe) {
                final isSelected = _selectedVibe == vibe;
                return GestureDetector(
                  onTap: () => setState(() => _selectedVibe = vibe),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 60 : 40,
                    height: isSelected ? 60 : 40,
                    decoration: BoxDecoration(
                      color: _getColorForVibe(vibe),
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected ? [BoxShadow(color: _getColorForVibe(vibe).withValues(alpha: 0.6), blurRadius: 20)] : [],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                _getVibeName(_selectedVibe).toUpperCase(),
                style: TextStyle(fontFamily: 'Courier', color: _getColorForVibe(_selectedVibe), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            
            const SizedBox(height: 40),
            const Text("MESSAGE //", style: TextStyle(fontFamily: 'Courier', color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: _msgController,
              style: const TextStyle(color: Colors.white, fontFamily: 'Courier'),
              maxLines: 3,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF222222),
                hintText: "What's happening safely/joyfully?",
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: BorderSide.none),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 1)),
              ),
            ),
            
            const SizedBox(height: 40),
            const Text("TTL // 7 DAYS", style: TextStyle(fontFamily: 'Courier', color: Colors.grey, fontSize: 12)),
            
            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getColorForVibe(_selectedVibe),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                onPressed: () {
                  // TODO: Save Pulse Logic
                  // For now just pop with data
                  Navigator.pop(context, {
                    'type': _selectedVibe,
                    'msg': _msgController.text,
                  });
                }, 
                child: const Text("BROADCAST CURRENT", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16))
              ),
            )
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
  
  String _getVibeName(VibeType type) {
    return type.toString().split('.').last;
  }
}
