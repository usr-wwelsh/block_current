
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class LocalGeocoder {
  static List<Map<String, dynamic>>? _cache;

  static Future<void> load() async {
    if (_cache != null) return;
    try {
      final String response = await rootBundle.loadString('assets/data/cities.json');
      final List<dynamic> data = json.decode(response);
      _cache = data.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print("Error loading cities: $e");
      _cache = [];
    }
  }

  static Map<String, dynamic>? search(String query) {
    if (_cache == null || _cache!.isEmpty) return null;
    
    final q = query.toLowerCase().trim();
    try {
      // 1. Exact Match
      final exact = _cache!.firstWhere((c) => c['name'].toString().toLowerCase() == q, orElse: () => {});
      if (exact.isNotEmpty) return exact;

      // 2. Starts With
      final start = _cache!.firstWhere((c) => c['name'].toString().toLowerCase().startsWith(q), orElse: () => {});
      if (start.isNotEmpty) return start;
      
    } catch (e) {
      return null;
    }
    return null;
  }
}
