// lib/services/location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  StreamSubscription<Position>? _locationSubscription;
  
  // Request location permission
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }
    
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return null;
    
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Start tracking driver location
  void startTracking({
    required String driverId,
    required bool hasActiveDelivery,
  }) {
    _locationSubscription?.cancel();
    
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: hasActiveDelivery
            ? LocationAccuracy.high
            : LocationAccuracy.medium,
        distanceFilter: hasActiveDelivery ? 10 : 50,
        timeLimit: Duration(seconds: hasActiveDelivery ? 5 : 15),
      ),
    ).listen((Position position) {
      _updateDriverLocation(driverId, position);
    });
  }

  // Update driver location in Firestore
  Future<void> _updateDriverLocation(String driverId, Position position) async {
    try {
      // Calculate geohash (simple version - you can use geoflutterfire_plus for better implementation)
      String geohash = _calculateGeohash(position.latitude, position.longitude);
      
      await FirebaseFirestore.instance.collection('drivers').doc(driverId).update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'geohash': geohash,
        'heading': position.heading,
        'speed': position.speed,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  // Stop tracking
  void stopTracking() {
    _locationSubscription?.cancel();
  }

  // Calculate distance between two points (Haversine formula)
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Simple geohash calculation (basic implementation)
  String _calculateGeohash(double lat, double lng, {int precision = 7}) {
    // This is a simplified version. Use geoflutterfire_plus for production
    const String base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    List<bool> bits = [];
    double latMin = -90.0, latMax = 90.0;
    double lngMin = -180.0, lngMax = 180.0;
    
    while (bits.length < precision * 5) {
      if (bits.length % 2 == 0) {
        double mid = (lngMin + lngMax) / 2;
        if (lng > mid) {
          bits.add(true);
          lngMin = mid;
        } else {
          bits.add(false);
          lngMax = mid;
        }
      } else {
        double mid = (latMin + latMax) / 2;
        if (lat > mid) {
          bits.add(true);
          latMin = mid;
        } else {
          bits.add(false);
          latMax = mid;
        }
      }
    }
    
    String hash = '';
    for (int i = 0; i < bits.length; i += 5) {
      int value = 0;
      for (int j = 0; j < 5; j++) {
        if (i + j < bits.length && bits[i + j]) {
          value |= (1 << (4 - j));
        }
      }
      hash += base32[value];
    }
    
    return hash;
  }
}