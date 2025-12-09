// lib/screens/driver/active_delivery_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/order_model.dart';
import '../../../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  final OrderModel order;
  final DriverModel driver;

  const ActiveDeliveryScreen({
    super.key,
    required this.order,
    required this.driver,
  });

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  late OrderModel _order;
  GoogleMapController? mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _listenToOrderUpdates();
    _setupMap();
    
    // Start high-frequency location tracking during delivery
    _locationService.startTracking(
      driverId: widget.driver.id,
      hasActiveDelivery: true,
    );
  }

  @override
  void dispose() {
    // Return to normal frequency tracking
    _locationService.startTracking(
      driverId: widget.driver.id,
      hasActiveDelivery: false,
    );
    super.dispose();
  }

  void _listenToOrderUpdates() {
    _firestoreService.streamOrder(_order.id).listen((updatedOrder) {
      if (mounted) {
        setState(() {
          _order = updatedOrder;
        });
      }
    });
  }

  void _setupMap() {
    // Restaurant marker
    _markers.add(
      Marker(
        markerId: const MarkerId('restaurant'),
        position: LatLng(
          _order.restaurantLocation.latitude,
          _order.restaurantLocation.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: _order.restaurantName,
          snippet: 'Pickup Location',
        ),
      ),
    );

    // Customer marker
    _markers.add(
      Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(
          _order.deliveryLocation.latitude,
          _order.deliveryLocation.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: _order.customerName,
          snippet: 'Delivery Location',
        ),
      ),
    );

    // Driver marker (current location)
    if (widget.driver.currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(
            widget.driver.currentLocation!.latitude,
            widget.driver.currentLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'You',
            snippet: 'Current Location',
          ),
        ),
      );
    }

    // Draw route line
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          if (widget.driver.currentLocation != null)
            LatLng(
              widget.driver.currentLocation!.latitude,
              widget.driver.currentLocation!.longitude,
            ),
          LatLng(
            _order.restaurantLocation.latitude,
            _order.restaurantLocation.longitude,
          ),
          LatLng(
            _order.deliveryLocation.latitude,
            _order.deliveryLocation.longitude,
          ),
        ],
        color: Colors.blue,
        width: 5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_order.id.substring(0, 8)}'),
      ),
      body: Column(
        children: [
          // Map view
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _order.restaurantLocation.latitude,
                  _order.restaurantLocation.longitude,
                ),
                zoom: 13,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) {
                mapController = controller;
              },
            ),
          ),

          // Order details
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status indicator
                    _buildStatusIndicator(),
                    const SizedBox(height: 16),

                    // Location details
                    if (_order.status == OrderStatus.driver_assigned ||
                        _order.status == OrderStatus.driver_at_restaurant)
                      _buildLocationCard(
                        'Pickup from',
                        _order.restaurantName,
                        Icons.restaurant,
                        Colors.orange,
                      )
                    else
                      _buildLocationCard(
                        'Deliver to',
                        _order.deliveryAddress,
                        Icons.location_on,
                        Colors.green,
                      ),
                    const SizedBox(height: 16),

                    // Customer info
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(_order.customerName),
                        subtitle: Text(_order.customerPhone),
                        trailing: IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () {
                            // Implement call functionality
                            _showCallDialog();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Order items summary
                    Text(
                      'Order Items (${_order.items.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._order.items.take(3).map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text('${item.quantity}x'),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item.name)),
                            ],
                          ),
                        )),
                    if (_order.items.length > 3)
                      Text(
                        '+${_order.items.length - 3} more items',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Action button
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleAction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _getActionButtonColor(),
                ),
                child: Text(
                  _getActionButtonText(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(), width: 2),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(), color: _getStatusColor(), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusTitle(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _getStatusDescription(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(
      String label, String address, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.navigation, color: Colors.blue),
              onPressed: () {
                // Open in Google Maps
                _openInMaps();
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_order.status) {
      case OrderStatus.driver_assigned:
        return Colors.blue;
      case OrderStatus.driver_at_restaurant:
        return Colors.orange;
      case OrderStatus.out_for_delivery:
      case OrderStatus.arriving:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_order.status) {
      case OrderStatus.driver_assigned:
        return Icons.directions_car;
      case OrderStatus.driver_at_restaurant:
        return Icons.restaurant;
      case OrderStatus.out_for_delivery:
      case OrderStatus.arriving:
        return Icons.delivery_dining;
      default:
        return Icons.info;
    }
  }

  String _getStatusTitle() {
    switch (_order.status) {
      case OrderStatus.driver_assigned:
        return 'Heading to Restaurant';
      case OrderStatus.driver_at_restaurant:
        return 'At Restaurant';
      case OrderStatus.out_for_delivery:
        return 'Delivering Order';
      case OrderStatus.arriving:
        return 'Arriving Soon';
      default:
        return 'Active Delivery';
    }
  }

  String _getStatusDescription() {
    switch (_order.status) {
      case OrderStatus.driver_assigned:
        return 'Navigate to restaurant to pick up the order';
      case OrderStatus.driver_at_restaurant:
        return 'Collect the order from the restaurant';
      case OrderStatus.out_for_delivery:
        return 'Navigate to customer location';
      case OrderStatus.arriving:
        return "You're almost there!";
      default:
        return '';
    }
  }

  Color _getActionButtonColor() {
    switch (_order.status) {
      case OrderStatus.driver_assigned:
        return Colors.blue;
      case OrderStatus.driver_at_restaurant:
        return Colors.orange;
      case OrderStatus.out_for_delivery:
      case OrderStatus.arriving:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getActionButtonText() {
    switch (_order.status) {
      case OrderStatus.driver_assigned:
        return 'Arrived at Restaurant';
      case OrderStatus.driver_at_restaurant:
        return 'Picked Up Order';
      case OrderStatus.out_for_delivery:
      case OrderStatus.arriving:
        return 'Complete Delivery';
      default:
        return 'Next Step';
    }
  }

  Future<void> _handleAction() async {
    try {
      switch (_order.status) {
        case OrderStatus.driver_assigned:
          // Mark as arrived at restaurant
          await _firestoreService.updateOrderStatus(
            _order.id,
            OrderStatus.driver_at_restaurant,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marked as arrived at restaurant')),
          );
          break;

        case OrderStatus.driver_at_restaurant:
          // Mark as picked up
          await _firestoreService.updateOrderStatus(
            _order.id,
            OrderStatus.out_for_delivery,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order picked up!')),
          );
          // Update map markers and route
          setState(() {
            _setupMap();
          });
          break;

        case OrderStatus.out_for_delivery:
        case OrderStatus.arriving:
          // Complete delivery
          await _completeDelivery();
          break;

        default:
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _completeDelivery() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: const Text(
          'Have you successfully delivered the order to the customer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Delivery'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Update order status
        await _firestoreService.updateOrderStatus(
          _order.id,
          OrderStatus.delivered,
        );

        // Remove order from driver's active orders
        await _firestoreService.removeOrderFromDriver(
          widget.driver.id,
          _order.id,
        );

        // Calculate and add earnings
        double earnings = _order.deliveryFee * 0.8; // Driver gets 80%
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driver.id)
            .update({
          'todayEarnings': FieldValue.increment(earnings),
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delivery completed! You earned \$${earnings.toStringAsFixed(2)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Customer'),
        content: Text('Do you want to call ${_order.customerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement actual phone call
              // Use url_launcher package: launch('tel:${_order.customerPhone}')
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling ${_order.customerPhone}...')),
              );
            },
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  void _openInMaps() {
    // Implement opening in Google Maps
    // Use url_launcher or map_launcher package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening in Google Maps...')),
    );
  }
}