// lib/models/restaurant_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantModel {
  final String id;
  final String name;
  final String description;
  final String cuisineType;
  final String imageUrl;
  final GeoPoint location;
  final String address;
  final double rating;
  final int totalRatings;
  final int estimatedDeliveryTime; // in minutes
  final bool isOpen;
  final String ownerId;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.description,
    required this.cuisineType,
    required this.imageUrl,
    required this.location,
    required this.address,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.estimatedDeliveryTime = 30,
    this.isOpen = true,
    required this.ownerId,
  });

  factory RestaurantModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RestaurantModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      cuisineType: data['cuisineType'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      location: data['location'] ?? GeoPoint(0, 0),
      address: data['address'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      estimatedDeliveryTime: data['estimatedDeliveryTime'] ?? 30,
      isOpen: data['isOpen'] ?? true,
      ownerId: data['ownerId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'cuisineType': cuisineType,
      'imageUrl': imageUrl,
      'location': location,
      'address': address,
      'rating': rating,
      'totalRatings': totalRatings,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'isOpen': isOpen,
      'ownerId': ownerId,
    };
  }
}