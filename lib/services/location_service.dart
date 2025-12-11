// lib/services/location_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  StreamSubscription<Position>? _locationSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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

  // Get current location once
  Future<Position?> getCurrentLocation() async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return null;
    
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      debugPrint('Current location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  // Start tracking driver location
  void startTracking({
    required String driverId,
    required bool hasActiveDelivery,
  }) {
    debugPrint('Starting location tracking for driver: $driverId');
    debugPrint('   Active delivery: $hasActiveDelivery');
    
    // Cancel any existing subscription
    _locationSubscription?.cancel();
    
    // Start new location stream
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: hasActiveDelivery
            ? LocationAccuracy.high      
            : LocationAccuracy.medium,  
        distanceFilter: hasActiveDelivery ? 10 : 50, 
      ),
    ).listen(
      (Position position) {
        debugPrint('Location update: ${position.latitude}, ${position.longitude}');
        _updateDriverLocation(driverId, position);
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
    
    debugPrint('Location tracking started');
  }

  // Update driver location in Firestore
  Future<void> _updateDriverLocation(String driverId, Position position) async {
    try {
      // Calculate simple geohash
      String geohash = _calculateGeohash(position.latitude, position.longitude);
      
      await _firestore.collection('drivers').doc(driverId).update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'geohash': geohash,
        'heading': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      debugPrint('Error updating driver location: $e');
    }
  }

  // Stop tracking
  void stopTracking() {
    debugPrint('Stopping location tracking');
    _locationSubscription?.cancel();
    _locationSubscription = null;
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

  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}