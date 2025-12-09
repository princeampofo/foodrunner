// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../../../models/restaurant_model.dart';
import '../../../../../../../models/menu_item.dart';
import '../../../../../../../models/order_model.dart';
import '../../../../../../../models/driver_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== RESTAURANTS ==========

  // Get all restaurants
  Stream<List<RestaurantModel>> getRestaurants() {
    return _firestore
        .collection('restaurants')
        .where('isOpen', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RestaurantModel.fromFirestore(doc))
            .toList());
  }

  // Get restaurant by ID
  Future<RestaurantModel?> getRestaurant(String restaurantId) async {
    DocumentSnapshot doc =
        await _firestore.collection('restaurants').doc(restaurantId).get();
    if (doc.exists) {
      return RestaurantModel.fromFirestore(doc);
    }
    return null;
  }

  // ========== MENU ITEMS ==========

  // Get menu items for a restaurant
  Stream<List<MenuItemModel>> getMenuItems(String restaurantId) {
    return _firestore
        .collection('menuItems')
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MenuItemModel.fromFirestore(doc))
            .toList());
  }

  // Update menu item availability
  Future<void> updateMenuItemAvailability(String itemId, bool isAvailable) async {
    await _firestore.collection('menuItems').doc(itemId).update({
      'isAvailable': isAvailable,
    });
  }

  // Create menu item
  Future<String> createMenuItem(MenuItemModel menuItem) async {
    DocumentReference docRef = await _firestore.collection('menuItems').add(menuItem.toMap());
    return docRef.id;
  }

  // Update menu item
  Future<void> updateMenuItem(String itemId, MenuItemModel menuItem) async {
    await _firestore.collection('menuItems').doc(itemId).update(menuItem.toMap());
  }

  // Delete menu item
  Future<void> deleteMenuItem(String itemId) async {
    await _firestore.collection('menuItems').doc(itemId).delete();
  }

  // Get single menu item
  Future<MenuItemModel?> getMenuItem(String itemId) async {
    DocumentSnapshot doc = await _firestore.collection('menuItems').doc(itemId).get();
    if (doc.exists) {
      return MenuItemModel.fromFirestore(doc);
    }
    return null;
  }

  // ========== ORDERS ==========

  // Create order
  Future<String> createOrder(OrderModel order) async {
    DocumentReference docRef = await _firestore.collection('orders').add(order.toMap());
    return docRef.id;
  }

  // Get order by ID
  Future<OrderModel?> getOrder(String orderId) async {
    DocumentSnapshot doc = await _firestore.collection('orders').doc(orderId).get();
    if (doc.exists) {
      return OrderModel.fromFirestore(doc);
    }
    return null;
  }

  // Stream order (real-time updates)
  Stream<OrderModel> streamOrder(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) => OrderModel.fromFirestore(doc));
  }

  // Get customer orders
  Stream<List<OrderModel>> getCustomerOrders(String customerId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  // Get restaurant orders
  Stream<List<OrderModel>> getRestaurantOrders(String restaurantId) {
    return _firestore
        .collection('orders')
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', whereIn: [
      'pending',
      'accepted',
      'preparing',
      'ready_for_pickup',
      'driver_assigned',
      'driver_at_restaurant',
    ]).orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  // Get driver orders
  Stream<List<OrderModel>> getDriverOrders(String driverId) {
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
      'driver_assigned',
      'driver_at_restaurant',
      'out_for_delivery',
      'arriving',
    ]).orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    Map<String, dynamic> updateData = {
      'status': status.toString().split('.').last,
    };

    // Add timestamp for specific statuses
    switch (status) {
      case OrderStatus.accepted:
        updateData['acceptedAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.preparing:
        updateData['preparingAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.ready_for_pickup:
        updateData['readyAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.out_for_delivery:
        updateData['pickedUpAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.delivered:
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
        break;
      default:
        break;
    }

    await _firestore.collection('orders').doc(orderId).update(updateData);
  }

  // Assign driver to order
  Future<void> assignDriverToOrder(
      String orderId, String driverId, String driverName) async {
    await _firestore.collection('orders').doc(orderId).update({
      'driverId': driverId,
      'driverName': driverName,
      'status': OrderStatus.driver_assigned.toString().split('.').last,
    });
  }

  // ========== DRIVERS ==========

  // Get driver
  Future<DriverModel?> getDriver(String driverId) async {
    DocumentSnapshot doc =
        await _firestore.collection('drivers').doc(driverId).get();
    if (doc.exists) {
      return DriverModel.fromFirestore(doc);
    }
    return null;
  }

  // Stream driver
  Stream<DriverModel> streamDriver(String driverId) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .map((doc) => DriverModel.fromFirestore(doc));
  }

  // Update driver location
  Future<void> updateDriverLocation(
      String driverId, GeoPoint location, String geohash) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'currentLocation': location,
      'geohash': geohash,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Update driver online status
  Future<void> updateDriverOnlineStatus(String driverId, bool isOnline) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'isOnline': isOnline,
      'isAvailable': isOnline, // When going offline, also mark unavailable
    });
  }

  // Add order to driver's active orders
  Future<void> addOrderToDriver(String driverId, String orderId) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'activeOrderIds': FieldValue.arrayUnion([orderId]),
      'isAvailable': false, // Mark as busy
    });
  }

  // Remove order from driver's active orders
  Future<void> removeOrderFromDriver(String driverId, String orderId) async {
    DocumentSnapshot driverDoc =
        await _firestore.collection('drivers').doc(driverId).get();
    List<String> activeOrders =
        List<String>.from(driverDoc.get('activeOrderIds') ?? []);
    activeOrders.remove(orderId);

    await _firestore.collection('drivers').doc(driverId).update({
      'activeOrderIds': activeOrders,
      'isAvailable': activeOrders.isEmpty, // Available if no active orders
      'totalDeliveries': FieldValue.increment(1),
    });
  }
}