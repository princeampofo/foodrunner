// lib/models/rating_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String orderId;
  final String customerId;
  final String customerName;
  
  // Restaurant rating
  final String restaurantId;
  final String restaurantName;
  final int restaurantRating;
  final String? restaurantReview;
  
  // Driver rating
  final String driverId;
  final String driverName;
  final int driverRating;
  final String? driverReview;
  
  final DateTime createdAt;

  RatingModel({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantRating,
    this.restaurantReview,
    required this.driverId,
    required this.driverName,
    required this.driverRating,
    this.driverReview,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'customerName': customerName,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantRating': restaurantRating,
      'restaurantReview': restaurantReview,
      'driverId': driverId,
      'driverName': driverName,
      'driverRating': driverRating,
      'driverReview': driverReview,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return RatingModel(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      restaurantRating: data['restaurantRating'] ?? 5,
      restaurantReview: data['restaurantReview'],
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      driverRating: data['driverRating'] ?? 5,
      driverReview: data['driverReview'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}