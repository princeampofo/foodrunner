// lib/services/geocoding_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foodrunner/config/secrets.dart';

class GeocodingService {
  // Replace with your actual Google Maps API key
  static const String _apiKey = Secrets.googleMapsApiKey;
  
  // Geocode address to GeoPoint
  Future<GeoPoint?> geocodeAddress(String address) async {
    try {
      debugPrint('🗺️ Geocoding address: $address');
      
      // URL encode the address
      String encodedAddress = Uri.encodeComponent(address);
      
      // Make request to Geocoding API
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$_apiKey',
        ),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          var location = data['results'][0]['geometry']['location'];
          double lat = location['lat'];
          double lng = location['lng'];
          
          debugPrint('✅ Geocoded to: $lat, $lng');
          return GeoPoint(lat, lng);
        } else {
          debugPrint('⚠️ Geocoding failed: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Geocoding error: $e');
      return null;
    }
  }
  
  // Reverse geocode (GeoPoint to address) - optional
  Future<String?> reverseGeocode(GeoPoint location) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}&key=$_apiKey',
        ),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Reverse geocoding error: $e');
      return null;
    }
  }
}