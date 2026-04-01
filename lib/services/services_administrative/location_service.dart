// lib/services/services_administrative/location_service.dart
import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // ── GPS do dispositivo (usado como fallback) ───────────────────────────────
  Future<Position?> getPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Coordenadas de moradia do usuário salvas no Firebase ──────────────────
  /// Retorna as coordenadas do campo `latitude`/`longitude` do nó
  /// `Users/$uid` — que representam onde o usuário mora, não a posição
  /// atual do dispositivo.
  ///
  /// Retorna `null` se o usuário não tiver coords cadastradas.
  Future<({double latitude, double longitude})?> getUserHomeCoords(
      String uid) async {
    if (uid.isEmpty) return null;
    try {
      final snap =
          await FirebaseDatabase.instance.ref('Users/$uid').get();
      if (!snap.exists || snap.value == null) return null;

      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final lat = _toDouble(data['latitude']);
      final lon = _toDouble(data['longitude']);
      if (lat == null || lon == null) return null;

      return (latitude: lat, longitude: lon);
    } catch (_) {
      return null;
    }
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // ── Haversine ─────────────────────────────────────────────────────────────
  /// Distância em quilômetros entre dois pontos geográficos.
  static double distanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  // ── Formatação ─────────────────────────────────────────────────────────────
  static String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }
}