// lib/services/directions_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodrunner/config/secrets.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';


class DirectionsService {
  static const String _apiKey = Secrets.googleMapsApiKey;
  
  // Get route between two points
  Future<RouteInfo?> getRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    try {
      debugPrint('🗺️ Getting route from Directions API...');
      debugPrint('   Origin: ${origin.latitude}, ${origin.longitude}');
      debugPrint('   Destination: ${destination.latitude}, ${destination.longitude}');

      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=driving'
          '&departure_time=now'
          '&traffic_model=best_guess'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          var route = data['routes'][0];
          
          // Extract polyline
          String encodedPolyline = route['overview_polyline']['points'];
          
          // Decode polyline to list of coordinates
          List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(encodedPolyline);
          
          // Convert to GeoPoint list
          List<GeoPoint> routePoints = decodedPoints.map((point) {
            return GeoPoint(point.latitude, point.longitude);
          }).toList();

          // Extract distance and duration
          var leg = route['legs'][0];
          int distanceMeters = leg['distance']['value'];
          int durationSeconds = leg['duration']['value'];
          String distanceText = leg['distance']['text'];
          String durationText = leg['duration']['text'];

          debugPrint('✅ Route received:');
          debugPrint('   Points: ${routePoints.length}');
          debugPrint('   Distance: $distanceText');
          debugPrint('   Duration: $durationText');

          return RouteInfo(
            points: routePoints,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            distanceText: distanceText,
            durationText: durationText,
            encodedPolyline: encodedPolyline,
          );
        } else {
          debugPrint('Directions API error: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Directions API error: $e');
      return null;
    }
  }
}

// Route information model
class RouteInfo {
  final List<GeoPoint> points;
  final int distanceMeters;
  final int durationSeconds;
  final String distanceText;
  final String durationText;
  final String encodedPolyline;

  RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceText,
    required this.durationText,
    required this.encodedPolyline,
  });
}