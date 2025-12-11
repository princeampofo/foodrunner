// lib/services/rating_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit rating for order
  Future<void> submitRating(RatingModel rating) async {
    try {
      debugPrint('Submitting rating for order ${rating.orderId}');
      
      // Create rating document
      DocumentReference ratingRef = await _firestore.collection('ratings').add(rating.toMap());
      
      // Update order with rating info
      await _firestore.collection('orders').doc(rating.orderId).update({
        'isRated': true,
        'restaurantRating': rating.restaurantRating,
        'driverRating': rating.driverRating,
        'ratingId': ratingRef.id,
      });

      // Update restaurant average rating
      await _updateRestaurantRating(rating.restaurantId);
      
      // Update driver average rating
      await _updateDriverRating(rating.driverId);

      debugPrint('Rating submitted successfully');
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      rethrow;
    }
  }

  // Update restaurant's average rating
  Future<void> _updateRestaurantRating(String restaurantId) async {
    try {
      // Get all ratings for this restaurant
      QuerySnapshot ratingsSnapshot = await _firestore
          .collection('ratings')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) return;

      // Calculate average
      int totalRating = 0;
      for (var doc in ratingsSnapshot.docs) {
        totalRating += (doc.data() as Map<String, dynamic>)['restaurantRating'] as int;
      }

      double averageRating = totalRating / ratingsSnapshot.docs.length;
      int totalReviews = ratingsSnapshot.docs.length;

      // Update restaurant document
      await _firestore.collection('restaurants').doc(restaurantId).update({
        'rating': double.parse(averageRating.toStringAsFixed(1)),
        'totalReviews': totalReviews,
      });

      debugPrint('Updated restaurant rating: ${averageRating.toStringAsFixed(1)} ($totalReviews reviews)');
    } catch (e) {
      debugPrint('Error updating restaurant rating: $e');
    }
  }

  // Update driver's average rating
  Future<void> _updateDriverRating(String driverId) async {
    try {
      // Get all ratings for this driver
      QuerySnapshot ratingsSnapshot = await _firestore
          .collection('ratings')
          .where('driverId', isEqualTo: driverId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) return;

      // Calculate average
      int totalRating = 0;
      for (var doc in ratingsSnapshot.docs) {
        totalRating += (doc.data() as Map<String, dynamic>)['driverRating'] as int;
      }

      double averageRating = totalRating / ratingsSnapshot.docs.length;
      int totalReviews = ratingsSnapshot.docs.length;

      // Update driver document
      await _firestore.collection('drivers').doc(driverId).update({
        'rating': double.parse(averageRating.toStringAsFixed(1)),
        'totalReviews': totalReviews,
      });

      debugPrint('Updated driver rating: ${averageRating.toStringAsFixed(1)} ($totalReviews reviews)');
    } catch (e) {
      debugPrint('Error updating driver rating: $e');
    }
  }

  // Get ratings for a specific order
  Future<RatingModel?> getRatingForOrder(String orderId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('ratings')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return RatingModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('Error getting rating: $e');
      return null;
    }
  }

  // Get all ratings for a restaurant
  Stream<List<RatingModel>> getRestaurantRatings(String restaurantId) {
    return _firestore
        .collection('ratings')
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RatingModel.fromFirestore(doc)).toList();
    });
  }

  // Get all ratings for a driver
  Stream<List<RatingModel>> getDriverRatings(String driverId) {
    return _firestore
        .collection('ratings')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RatingModel.fromFirestore(doc)).toList();
    });
  }
}