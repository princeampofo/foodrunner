// lib/models/driver_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String vehicleType;
  final String licensePlate;
  final String? vehicleImageUrl;
  final GeoPoint? currentLocation;
  final String? geohash;
  final bool isOnline;
  final bool isAvailable;
  final List<String> activeOrderIds;
  final int maxCapacity;
  final double rating;
  final int totalDeliveries;
  final double todayEarnings;
  final DateTime? lastUpdated;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.vehicleType,
    required this.licensePlate,
    this.vehicleImageUrl,
    this.currentLocation,
    this.geohash,
    this.isOnline = false,
    this.isAvailable = true,
    this.activeOrderIds = const [],
    this.maxCapacity = 4,
    this.rating = 5.0,
    this.totalDeliveries = 0,
    this.todayEarnings = 0.0,
    this.lastUpdated,
  });

  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DriverModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      vehicleType: data['vehicleType'] ?? '',
      licensePlate: data['licensePlate'] ?? '',
      vehicleImageUrl: data['vehicleImageUrl'],
      currentLocation: data['currentLocation'],
      geohash: data['geohash'],
      isOnline: data['isOnline'] ?? false,
      isAvailable: data['isAvailable'] ?? true,
      activeOrderIds: List<String>.from(data['activeOrderIds'] ?? []),
      maxCapacity: data['maxCapacity'] ?? 4,
      rating: (data['rating'] ?? 5.0).toDouble(),
      totalDeliveries: data['totalDeliveries'] ?? 0,
      todayEarnings: (data['todayEarnings'] ?? 0.0).toDouble(),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'vehicleType': vehicleType,
      'licensePlate': licensePlate,
      'vehicleImageUrl': vehicleImageUrl,
      'currentLocation': currentLocation,
      'geohash': geohash,
      'isOnline': isOnline,
      'isAvailable': isAvailable,
      'activeOrderIds': activeOrderIds,
      'maxCapacity': maxCapacity,
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'todayEarnings': todayEarnings,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }

  int get currentLoad => activeOrderIds.length;
  bool get isAtCapacity => currentLoad >= maxCapacity;
}