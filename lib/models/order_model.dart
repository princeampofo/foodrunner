// lib/models/order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum OrderStatus {
  pending,
  accepted,
  preparing,
  ready_for_pickup,
  finding_driver,         // NEW - when broadcasting to drivers
  driver_assigned,
  driver_at_restaurant,
  out_for_delivery,
  arriving,
  delivered,
  cancelled,
  no_driver_available,    // NEW - when no drivers respond
}

class OrderItem {
  final String menuItemId;
  final String name;
  final double price;
  final int quantity;
  final String? specialInstructions;

  OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.specialInstructions,
  });

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'specialInstructions': specialInstructions,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      menuItemId: map['menuItemId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 1,
      specialInstructions: map['specialInstructions'],
    );
  }
}

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String restaurantId;
  final String restaurantName;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double total;
  final OrderStatus status;
  final GeoPoint deliveryLocation;
  final String deliveryAddress;
  final GeoPoint restaurantLocation;
  final String? driverId;
  final String? driverName;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? preparingAt;
  final DateTime? readyAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final int estimatedPrepTime; // minutes
  final int priority; // 1=normal, 2=high

  OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.total,
    required this.status,
    required this.deliveryLocation,
    required this.deliveryAddress,
    required this.restaurantLocation,
    this.driverId,
    this.driverName,
    required this.createdAt,
    this.acceptedAt,
    this.preparingAt,
    this.readyAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.estimatedPrepTime = 20,
    this.priority = 1,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      items: (data['items'] as List<dynamic>)
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      deliveryFee: (data['deliveryFee'] ?? 0.0).toDouble(),
      tax: (data['tax'] ?? 0.0).toDouble(),
      total: (data['total'] ?? 0.0).toDouble(),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == 'OrderStatus.${data['status']}',
        orElse: () => OrderStatus.pending,
      ),
      deliveryLocation: data['deliveryLocation'] ?? GeoPoint(0, 0),
      deliveryAddress: data['deliveryAddress'] ?? '',
      restaurantLocation: data['restaurantLocation'] ?? GeoPoint(0, 0),
      driverId: data['driverId'],
      driverName: data['driverName'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      acceptedAt: data['acceptedAt'] != null
          ? (data['acceptedAt'] as Timestamp).toDate()
          : null,
      preparingAt: data['preparingAt'] != null
          ? (data['preparingAt'] as Timestamp).toDate()
          : null,
      readyAt: data['readyAt'] != null
          ? (data['readyAt'] as Timestamp).toDate()
          : null,
      pickedUpAt: data['pickedUpAt'] != null
          ? (data['pickedUpAt'] as Timestamp).toDate()
          : null,
      deliveredAt: data['deliveredAt'] != null
          ? (data['deliveredAt'] as Timestamp).toDate()
          : null,
      estimatedPrepTime: data['estimatedPrepTime'] ?? 20,
      priority: data['priority'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'tax': tax,
      'total': total,
      'status': status.toString().split('.').last,
      'deliveryLocation': deliveryLocation,
      'deliveryAddress': deliveryAddress,
      'restaurantLocation': restaurantLocation,
      'driverId': driverId,
      'driverName': driverName,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'preparingAt': preparingAt != null ? Timestamp.fromDate(preparingAt!) : null,
      'readyAt': readyAt != null ? Timestamp.fromDate(readyAt!) : null,
      'pickedUpAt': pickedUpAt != null ? Timestamp.fromDate(pickedUpAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'estimatedPrepTime': estimatedPrepTime,
      'priority': priority,
    };
  }

  // Get user-friendly status message
  String getStatusMessage() {
    switch (status) {
      case OrderStatus.pending:
        return 'Waiting for acceptance';
      case OrderStatus.accepted:
        return 'Order accepted';
      case OrderStatus.preparing:
        return 'Preparing your order';
      case OrderStatus.ready_for_pickup:
        return 'Ready for pickup';
      case OrderStatus.finding_driver:
        return 'Finding a driver...';
      case OrderStatus.no_driver_available:
        return 'No drivers available - Retrying...';
      case OrderStatus.driver_assigned:
        return driverName != null 
          ? 'Driver assigned: $driverName'
          : 'Driver assigned';
      case OrderStatus.driver_at_restaurant:
        return 'Driver has arrived';
      case OrderStatus.out_for_delivery:
        return 'Out for delivery';
      case OrderStatus.arriving:
        return 'Driver arriving soon';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
  
  // Get status color
  Color getStatusColor() {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.ready_for_pickup:
        return Colors.purple;
      case OrderStatus.finding_driver:
        return Colors.amber;
      case OrderStatus.no_driver_available:
        return Colors.red;
      case OrderStatus.driver_assigned:
      case OrderStatus.driver_at_restaurant:
        return Colors.teal;
      case OrderStatus.out_for_delivery:
      case OrderStatus.arriving:
        return Colors.green;
      case OrderStatus.delivered:
        return Colors.green[700]!;
      case OrderStatus.cancelled:
        return Colors.grey;
    }
  }
  
  // Get status icon
  IconData getStatusIcon() {
    switch (status) {
      case OrderStatus.pending:
        return Icons.access_time;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready_for_pickup:
        return Icons.done_all;
      case OrderStatus.finding_driver:
        return Icons.search;
      case OrderStatus.no_driver_available:
        return Icons.warning;
      case OrderStatus.driver_assigned:
      case OrderStatus.driver_at_restaurant:
        return Icons.person;
      case OrderStatus.out_for_delivery:
      case OrderStatus.arriving:
        return Icons.delivery_dining;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }
}