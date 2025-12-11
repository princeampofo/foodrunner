// lib/services/driver_simulator_service.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'directions_service.dart';

class DriverSimulatorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DirectionsService _directionsService = DirectionsService();
  
  Timer? _simulationTimer;
  List<GeoPoint>? _routePoints;
  int _currentPointIndex = 0;
  bool _isSimulating = false;

  // Start simulating driver movement along actual route
  Future<void> startSimulation({
    required String driverId,
    required GeoPoint startLocation,
    required GeoPoint endLocation,
    int speedKmh = 40,
  }) async {
    if (_isSimulating) {
      debugPrint('Simulation already running');
      return;
    }

    debugPrint('Starting driver simulation with real route');
    debugPrint('   From: ${startLocation.latitude}, ${startLocation.longitude}');
    debugPrint('   To: ${endLocation.latitude}, ${endLocation.longitude}');
    debugPrint('   Speed: $speedKmh km/h');

    _isSimulating = true;
    _currentPointIndex = 0;

    // Get real route from Google Directions API
    RouteInfo? routeInfo = await _directionsService.getRoute(
      origin: startLocation,
      destination: endLocation,
    );

    if (routeInfo == null) {
      debugPrint('Could not get route, falling back to straight line');
      _routePoints = _generateStraightLineRoute(startLocation, endLocation);
    } else {
      debugPrint('Using real route with ${routeInfo.points.length} points');
      debugPrint('   Distance: ${routeInfo.distanceText}');
      debugPrint('   Duration: ${routeInfo.durationText}');
      
      // Use the real route points
      _routePoints = routeInfo.points;
      
      // Optionally interpolate more points for smoother movement
      debugPrint('Interpolated to ${_routePoints!.length} points for smooth movement');
    }

    // Calculate update interval based on speed
    double speedMps = speedKmh * 1000 / 3600; // meters per second
    
    // Calculate total distance
    double totalDistance = 0;
    for (int i = 0; i < _routePoints!.length - 1; i++) {
      totalDistance += _calculateDistance(_routePoints![i], _routePoints![i + 1]);
    }
    
    // Calculate time needed for entire route
    double totalTimeSeconds = totalDistance / speedMps;
    
    // Update interval = total time / number of points
    int updateIntervalMs = ((totalTimeSeconds / _routePoints!.length) * 1000).round();
    
    // Keep interval reasonable (min 500ms, max 3000ms)
    updateIntervalMs = updateIntervalMs.clamp(500, 3000);

    debugPrint('   Total distance: ${(totalDistance / 1000).toStringAsFixed(2)} km');
    debugPrint('   Total time: ${(totalTimeSeconds / 60).toStringAsFixed(1)} minutes');
    debugPrint('   Update interval: ${updateIntervalMs}ms');

    // Start timer to update location
    _simulationTimer = Timer.periodic(
      Duration(milliseconds: updateIntervalMs),
      (timer) async {
        if (_currentPointIndex >= _routePoints!.length) {
          debugPrint('✅ Simulation complete - reached destination');
          stopSimulation();
          return;
        }

        GeoPoint currentPoint = _routePoints![_currentPointIndex];
        
        // Calculate heading (bearing) to next point
        double heading = 0;
        double speed = speedMps;
        
        if (_currentPointIndex < _routePoints!.length - 1) {
          heading = _calculateBearing(
            currentPoint,
            _routePoints![_currentPointIndex + 1],
          );
          
          // Calculate actual speed based on distance to next point
          double distanceToNext = _calculateDistance(
            currentPoint,
            _routePoints![_currentPointIndex + 1],
          );
          speed = distanceToNext / (updateIntervalMs / 1000);
        }

        // Update driver location in Firestore
        await _updateDriverLocation(
          driverId,
          currentPoint,
          heading,
          speed,
        );

        if (_currentPointIndex % 5 == 0) {
          debugPrint('📍 Progress: ${_currentPointIndex + 1}/${_routePoints!.length} (${(((_currentPointIndex + 1) / _routePoints!.length) * 100).toStringAsFixed(0)}%)');
        }

        _currentPointIndex++;
      },
    );
  }

  // Stop simulation
  void stopSimulation() {
    debugPrint('Stopping driver simulation');
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isSimulating = false;
    _routePoints = null;
    _currentPointIndex = 0;
  }

  // Generate straight line if API fails
  List<GeoPoint> _generateStraightLineRoute(
    GeoPoint start,
    GeoPoint end, {
    int pointCount = 50,
  }) {
    List<GeoPoint> points = [];
    
    for (int i = 0; i <= pointCount; i++) {
      double fraction = i / pointCount;
      double lat = start.latitude + (end.latitude - start.latitude) * fraction;
      double lng = start.longitude + (end.longitude - start.longitude) * fraction;
      points.add(GeoPoint(lat, lng));
    }
    
    return points;
  }

  // Calculate distance between two points (meters)
  double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Calculate bearing/heading between two points (degrees)
  double _calculateBearing(GeoPoint from, GeoPoint to) {
    double lat1 = _degreesToRadians(from.latitude);
    double lat2 = _degreesToRadians(to.latitude);
    double dLon = _degreesToRadians(to.longitude - from.longitude);

    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double bearing = atan2(y, x);
    
    // Convert to degrees
    bearing = _radiansToDegrees(bearing);
    bearing = (bearing + 360) % 360;
    
    return bearing;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;
  double _radiansToDegrees(double radians) => radians * 180 / pi;

  // Update driver location in Firestore
  Future<void> _updateDriverLocation(
    String driverId,
    GeoPoint location,
    double heading,
    double speed,
  ) async {
    try {
      String geohash = _calculateGeohash(location.latitude, location.longitude);
      
      await _firestore.collection('drivers').doc(driverId).update({
        'currentLocation': location,
        'geohash': geohash,
        'heading': heading,
        'speed': speed,
        'accuracy': 10.0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating driver location: $e');
    }
  }

  // Simple geohash calculation
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

  // Getter for route points
  List<GeoPoint>? get routePoints => _routePoints;
  
  bool get isSimulating => _isSimulating;
}