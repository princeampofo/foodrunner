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
  final double heading;      
  final double speed;          
  final double accuracy; 
  final int totalReviews;       


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
    this.heading = 0.0,
    this.speed = 0.0,
    this.accuracy = 0.0,
    this.totalReviews = 0,
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
      heading: (data['heading'] ?? 0.0).toDouble(),
      speed: (data['speed'] ?? 0.0).toDouble(),
      accuracy: (data['accuracy'] ?? 0.0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
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
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'totalReviews': totalReviews,
    };
  }

  // Copy with method for updates
  DriverModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? vehicleType,
    String? licensePlate,
    String? vehicleImageUrl,
    GeoPoint? currentLocation,
    String? geohash,
    bool? isOnline,
    bool? isAvailable,
    List<String>? activeOrderIds,
    int? maxCapacity,
    double? rating,
    int? totalDeliveries,
    double? todayEarnings,
    DateTime? lastUpdated,
    double? heading,              // ADD THIS LINE
    double? speed,                // ADD THIS LINE
    double? accuracy,             // ADD THIS LINE
    int? totalReviews,            // ADD THIS LINE
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      vehicleType: vehicleType ?? this.vehicleType,
      licensePlate: licensePlate ?? this.licensePlate,
      vehicleImageUrl: vehicleImageUrl ?? this.vehicleImageUrl,
      currentLocation: currentLocation ?? this.currentLocation,
      geohash: geohash ?? this.geohash,
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      activeOrderIds: activeOrderIds ?? this.activeOrderIds,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      heading: heading ?? this.heading,            
      speed: speed ?? this.speed,                      
      accuracy: accuracy ?? this.accuracy,   
      totalReviews: totalReviews ?? this.totalReviews,
    );
  }

  int get currentLoad => activeOrderIds.length;
  bool get isAtCapacity => currentLoad >= maxCapacity;
}