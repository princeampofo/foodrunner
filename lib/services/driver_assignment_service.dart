// lib/services/driver_assignment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/order_model.dart';
import '../models/driver_model.dart';

class DriverAssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Calculate distance between two points (in meters)
  double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Main method: Broadcast order to nearby drivers
  Future<void> broadcastOrderToNearbyDrivers(OrderModel order) async {
    try {
      debugPrint('🔍 Broadcasting order ${order.id.substring(0, 8)}...');
      debugPrint('   Restaurant: ${order.restaurantName}');
      debugPrint('   Location: ${order.restaurantLocation.latitude}, ${order.restaurantLocation.longitude}');

      // Step 1: Update order status to "finding_driver"
      await _firestore.collection('orders').doc(order.id).update({
        'status': OrderStatus.finding_driver.toString().split('.').last,
        'statusMessage': 'Looking for a driver...',
        'broadcastAt': FieldValue.serverTimestamp(),
      });

      // Step 2: Get all online and available drivers
      QuerySnapshot driversSnapshot = await _firestore
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

      if (driversSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No online drivers available');
        await _handleNoDriversAvailable(order.id);
        return;
      }

      debugPrint('📍 Found ${driversSnapshot.docs.length} online drivers');

      // Step 3: Filter drivers by distance and calculate scores
      List<Map<String, dynamic>> nearbyDrivers = [];

      for (var doc in driversSnapshot.docs) {
        DriverModel driver = DriverModel.fromFirestore(doc);

        // Skip if driver has no location
        if (driver.currentLocation == null) {
          debugPrint('   ⚠️ Driver ${driver.name}: No location');
          continue;
        }

        // Calculate distance to restaurant
        double distance = _calculateDistance(
          driver.currentLocation!,
          order.restaurantLocation,
        );

        debugPrint('   Driver ${driver.name}: ${(distance / 1000).toStringAsFixed(2)} km away');

        // Only consider drivers within 10km (10,000 meters)
        if (distance <= 10000) {
          nearbyDrivers.add({
            'driverId': driver.id,
            'driverName': driver.name,
            'distance': distance,
            'rating': driver.rating,
            'currentLoad': driver.currentLoad,
            'totalDeliveries': driver.totalDeliveries,
          });
        }
      }

      if (nearbyDrivers.isEmpty) {
        debugPrint('⚠️ No drivers within 10km radius');
        await _handleNoDriversAvailable(order.id);
        return;
      }

      debugPrint('✅ Found ${nearbyDrivers.length} nearby drivers');

      // Step 4: Sort drivers by score (best driver first)
      nearbyDrivers.sort((a, b) {
        double scoreA = _calculateDriverScore(
          a['distance'],
          a['rating'],
          a['currentLoad'],
        );
        double scoreB = _calculateDriverScore(
          b['distance'],
          b['rating'],
          b['currentLoad'],
        );
        return scoreB.compareTo(scoreA); // Higher score first
      });

      // Step 5: Broadcast to top 3 drivers (or all if less than 3)
      int broadcastCount = nearbyDrivers.length > 3 ? 3 : nearbyDrivers.length;
      
      debugPrint('📤 Broadcasting to top $broadcastCount drivers:');
      
      for (int i = 0; i < broadcastCount; i++) {
        var driverInfo = nearbyDrivers[i];
        await _createOrderRequest(order, driverInfo);
        debugPrint('   ✉️  ${i + 1}. ${driverInfo['driverName']} - ${(driverInfo['distance'] / 1000).toStringAsFixed(2)} km');
      }

      debugPrint('✅ Broadcast complete!');
    } catch (e) {
      debugPrint('❌ Error broadcasting order: $e');
      await _handleBroadcastError(order.id, e.toString());
    }
  }

  // Calculate driver score (higher is better)
  double _calculateDriverScore(double distance, double rating, int currentLoad) {
    // Normalize distance (closer = higher score)
    // 0m = 1.0, 10000m = 0.0
    double distanceScore = (10000 - distance) / 10000;
    if (distanceScore < 0) distanceScore = 0;
    
    // Normalize rating (0-5 -> 0-1)
    double ratingScore = rating / 5.0;
    
    // Normalize load (less load = higher score)
    // 0 orders = 1.0, 4 orders = 0.0
    double loadScore = (4 - currentLoad) / 4.0;
    if (loadScore < 0) loadScore = 0;
    
    // Weighted score
    // Distance is most important (50%), then rating (30%), then load (20%)
    double finalScore = (distanceScore * 0.5) + (ratingScore * 0.3) + (loadScore * 0.2);
    
    return finalScore;
  }

  // Create order request document for a specific driver
  Future<void> _createOrderRequest(
    OrderModel order,
    Map<String, dynamic> driverInfo,
  ) async {
    await _firestore.collection('orderRequests').add({
      // Order info
      'orderId': order.id,
      'orderTotal': order.total,
      'itemCount': order.items.length,
      
      // Driver info
      'driverId': driverInfo['driverId'],
      'driverName': driverInfo['driverName'],
      
      // Restaurant info
      'restaurantId': order.restaurantId,
      'restaurantName': order.restaurantName,
      'restaurantLocation': order.restaurantLocation,
      
      // Customer info
      'customerId': order.customerId,
      'customerName': order.customerName,
      'customerPhone': order.customerPhone,
      'customerLocation': order.deliveryLocation,
      'customerAddress': order.deliveryAddress,
      
      // Logistics
      'distance': driverInfo['distance'],
      'estimatedEarnings': order.deliveryFee * 0.8, // Driver gets 80% of delivery fee
      
      // Status & timing
      'status': 'pending', // pending, accepted, rejected, expired
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(seconds: 30)),
      ),
    });
  }

  // Handle when no drivers are available
  Future<void> _handleNoDriversAvailable(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderStatus.no_driver_available.toString().split('.').last,
      'statusMessage': 'Finding you a driver. Please wait...',
    });

    // Implement retry logic to broadcast again after 30 seconds if no drivers are available
    Future.delayed(const Duration(seconds: 10), () async {
      DocumentSnapshot orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        OrderModel order = OrderModel.fromFirestore(orderDoc);
        if (order.status == OrderStatus.no_driver_available) {
          debugPrint('🔄 Retrying broadcast for order ${order.id.substring(0, 8)}');
          await broadcastOrderToNearbyDrivers(order);
          
        } else {
          debugPrint('ℹ️ Order ${order.id.substring(0, 8)} status changed, not retrying');
        } 
      }
    });


  }

  // Handle broadcast errors
  Future<void> _handleBroadcastError(String orderId, String error) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderStatus.no_driver_available.toString().split('.').last,
      'statusMessage': 'Error finding drivers. Please contact support.',
      'broadcastError': error,
    });
  }

  // Method called when driver accepts order
  Future<void> assignOrderToDriver(
    String orderId,
    String driverId,
    String driverName,
  ) async {
    try {
      debugPrint('✅ Assigning order $orderId to driver $driverName');

      // Step 1: Update order status
      await _firestore.collection('orders').doc(orderId).update({
        'driverId': driverId,
        'driverName': driverName,
        'status': OrderStatus.driver_assigned.toString().split('.').last,
        'driverAssignedAt': FieldValue.serverTimestamp(),
      });

      // Step 2: Update driver - add order to active orders
      await _firestore.collection('drivers').doc(driverId).update({
        'activeOrderIds': FieldValue.arrayUnion([orderId]),
        'isAvailable': false, // Mark as busy
      });

      // Step 3: Expire all other pending requests for this order
      QuerySnapshot pendingRequests = await _firestore
          .collection('orderRequests')
          .where('orderId', isEqualTo: orderId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in pendingRequests.docs) {
        // Mark as expired if not the accepting driver
        if (doc.get('driverId') != driverId) {
          await doc.reference.update({'status': 'expired'});
        } else {
          await doc.reference.update({'status': 'accepted'});
        }
      }

      debugPrint('✅ Order assignment complete');
    } catch (e) {
      debugPrint('❌ Error assigning order: $e');
      rethrow;
    }
  }

  // Auto-expire old order requests (called periodically)
  Future<void> expireOldRequests() async {
    try {
      DateTime now = DateTime.now();
      
      QuerySnapshot oldRequests = await _firestore
          .collection('orderRequests')
          .where('status', isEqualTo: 'pending')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();

      for (var doc in oldRequests.docs) {
        await doc.reference.update({'status': 'expired'});
      }

      if (oldRequests.docs.isNotEmpty) {
        debugPrint('⏱️ Expired ${oldRequests.docs.length} old order requests');
      }
    } catch (e) {
      debugPrint('❌ Error expiring old requests: $e');
    }
  }
}