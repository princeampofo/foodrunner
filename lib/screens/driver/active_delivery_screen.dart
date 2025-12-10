// lib/screens/driver/active_delivery_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import '../../services/driver_simulator_service.dart';
import '../../services/directions_service.dart';
// import 'dart:ui' as ui;
// import 'dart:typed_data';
// import 'package:flutter/services.dart';

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
  final DriverSimulatorService _simulatorService = DriverSimulatorService();
  
  GoogleMapController? _mapController;
  StreamSubscription<OrderModel>? _orderSubscription;
  StreamSubscription<DriverModel>? _driverSubscription;
  
  OrderModel? _currentOrder;
  DriverModel? _currentDriver;
  OrderStatus? previousStatus;
  // Add these instance variables:
  BitmapDescriptor? carIcon;
  bool isLoadingRoute = false;
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _currentDriver = widget.driver;
    previousStatus = widget.order.status;
    
    _createCarIcon();
    _initializeMap();
    _listenToOrderUpdates();
    _listenToDriverUpdates();

    // Defer simulation start until after the first frame,
    // when context & inherited widgets (ScaffoldMessenger) are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkAndStartSimulation();
    });
}

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _driverSubscription?.cancel();
    _mapController?.dispose();
    _simulatorService.stopSimulation();
    super.dispose();
  }

  void _initializeMap() async {
     _updateMarkers();
    await _loadRoutePolyline();
   
  }

  Future<void> _createCarIcon() async {
    carIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/car.png',
    );
    setState(() {});
  }

  // Add method to load route polyline:
  Future<void> _loadRoutePolyline() async {
    if (_currentOrder == null) return;

    setState(() => isLoadingRoute = true);

    try {
      bool isPickingUp = _currentOrder!.status == OrderStatus.driver_assigned ||
          _currentOrder!.status == OrderStatus.driver_at_restaurant;

      GeoPoint origin = _currentDriver?.currentLocation ?? 
          (isPickingUp ? _currentOrder!.restaurantLocation : _currentOrder!.restaurantLocation);
      
      GeoPoint destination = isPickingUp
          ? _currentOrder!.restaurantLocation
          : _currentOrder!.deliveryLocation;

      debugPrint('🗺️ Loading route polyline...');
      
      final directionsService = DirectionsService();
      final routeInfo = await directionsService.getRoute(
        origin: origin,
        destination: destination,
      );

      if (routeInfo != null && mounted) {
        // Create polyline
        Set<Polyline> polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: routeInfo.points.map((geoPoint) {
              return LatLng(geoPoint.latitude, geoPoint.longitude);
            }).toList(),
            color: Colors.blue,
            width: 5,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        };

        setState(() {
          _polylines = polylines;
        });

        debugPrint('✅ Polyline loaded with ${routeInfo.points.length} points');
      }
    } catch (e) {
      debugPrint('❌ Error loading route polyline: $e');
    } finally {
      if (mounted) {
        setState(() => isLoadingRoute = false);
      }
    }
  }


  void _listenToOrderUpdates() {
    _orderSubscription = _firestoreService.streamOrder(_currentOrder!.id).listen(
      (order) {
        if (mounted) {
          OrderStatus oldStatus = _currentOrder!.status;
          
          setState(() {
            _currentOrder = order;
          });
          
          _updateMarkers();
          
          // Check if status changed
          if (oldStatus != order.status) {
            debugPrint('📊 Order status changed: ${oldStatus.toString().split('.').last} → ${order.status.toString().split('.').last}');
            _handleStatusChange(oldStatus, order.status);
          }
        }
      },
    );
  }

  void _listenToDriverUpdates() {
    _driverSubscription = _firestoreService.streamDriver(widget.driver.id).listen(
      (driver) {
        if (mounted) {
          setState(() {
            _currentDriver = driver;
          });
          _updateMarkers();
          _updateCameraPosition();
        }
      },
    );
  }

  // AUTO-START simulation based on status
  void _checkAndStartSimulation() {
    debugPrint('🔍 Checking if simulation should start...');
    debugPrint('   Current status: ${_currentOrder!.status.toString().split('.').last}');
    
    if (_currentOrder!.status == OrderStatus.driver_assigned) {
      debugPrint('✅ Driver just assigned - starting simulation to restaurant');
      _startSimulationToRestaurant();
    } else if (_currentOrder!.status == OrderStatus.out_for_delivery) {
      debugPrint('✅ Order picked up - starting simulation to customer');
      _startSimulationToCustomer();
    }
  }

  // Update _handleStatusChange to reload polyline:
  void _handleStatusChange(OrderStatus oldStatus, OrderStatus newStatus) {
    debugPrint('🔄 Handling status change: ${oldStatus.toString().split('.').last} → ${newStatus.toString().split('.').last}');
    
    // Stop simulation when arriving at restaurant
    if (newStatus == OrderStatus.driver_at_restaurant) {
      debugPrint('🛑 Arrived at restaurant - stopping simulation');
      _simulatorService.stopSimulation();
    }
    
    // Auto-start simulation to customer when order is picked up
    if (oldStatus == OrderStatus.driver_at_restaurant && 
        newStatus == OrderStatus.out_for_delivery) {
      debugPrint('🚗 Order picked up - auto-starting simulation to customer');
      
      // Reload polyline for new destination
      _loadRoutePolyline();
      
      Future.delayed(const Duration(milliseconds: 1000), () {
        _startSimulationToCustomer();
      });
    }
    
    // Stop simulation when delivery is complete
    if (newStatus == OrderStatus.delivered) {
      debugPrint('🛑 Delivery complete - stopping simulation');
      _simulatorService.stopSimulation();
    }
  }

  void _startSimulationToRestaurant() {
    GeoPoint startLocation = _currentDriver!.currentLocation ??
        const GeoPoint(33.7490, -84.3880); // Default Atlanta location

    GeoPoint destination = _currentOrder!.restaurantLocation;

    debugPrint('🚗 AUTO-STARTING simulation to restaurant');
    debugPrint('   From: ${startLocation.latitude}, ${startLocation.longitude}');
    debugPrint('   To: ${destination.latitude}, ${destination.longitude}');

    _simulatorService.startSimulation(
      driverId: widget.driver.id,
      startLocation: startLocation,
      endLocation: destination,
      speedKmh: 40,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.navigation, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚗 Driving to ${_currentOrder!.restaurantName}...',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _startSimulationToCustomer() {
    GeoPoint startLocation = _currentDriver!.currentLocation ??
        _currentOrder!.restaurantLocation;

    GeoPoint destination = _currentOrder!.deliveryLocation;

    debugPrint('🚗 AUTO-STARTING simulation to customer');
    debugPrint('   From: ${startLocation.latitude}, ${startLocation.longitude}');
    debugPrint('   To: ${destination.latitude}, ${destination.longitude}');

    _simulatorService.startSimulation(
      driverId: widget.driver.id,
      startLocation: startLocation,
      endLocation: destination,
      speedKmh: 40,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.navigation, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚗 Delivering to ${_currentOrder!.customerName}...',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Update _updateMarkers to use simple circle:
  void _updateMarkers() {
    if (_currentOrder == null || _currentDriver == null) return;

    Set<Marker> markers = {};

    // Restaurant marker (only if not picked up yet)
    bool isPickingUp = _currentOrder!.status == OrderStatus.driver_assigned ||
        _currentOrder!.status == OrderStatus.driver_at_restaurant;

    if (isPickingUp) {
      markers.add(
        Marker(
          markerId: const MarkerId('restaurant'),
          position: LatLng(
            _currentOrder!.restaurantLocation.latitude,
            _currentOrder!.restaurantLocation.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: '🍽️ ${_currentOrder!.restaurantName}',
            snippet: 'Pickup location',
          ),
        ),
      );
    }

    // Customer marker (delivery destination)
    markers.add(
      Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(
          _currentOrder!.deliveryLocation.latitude,
          _currentOrder!.deliveryLocation.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: '🏠 ${_currentOrder!.customerName}',
          snippet: 'Delivery location',
        ),
      ),
    );

    // Driver marker - Simple blue circle that follows polyline exactly
    if (_currentDriver!.currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(
            _currentDriver!.currentLocation!.latitude,
            _currentDriver!.currentLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Blue circle
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(
            title: '🚗 Driver',
            snippet: 'Current location',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }


  void _updateCameraPosition() {
    if (_mapController == null || _currentDriver?.currentLocation == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(
          _currentDriver!.currentLocation!.latitude,
          _currentDriver!.currentLocation!.longitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentOrder == null || _currentDriver == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    bool isPickingUp = _currentOrder!.status == OrderStatus.driver_assigned ||
        _currentOrder!.status == OrderStatus.driver_at_restaurant;

    GeoPoint destination = isPickingUp
        ? _currentOrder!.restaurantLocation
        : _currentOrder!.deliveryLocation;

    String destinationName = isPickingUp
        ? _currentOrder!.restaurantName
        : _currentOrder!.customerName;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_currentOrder!.id.substring(0, 8)}'),
        actions: [
          // Simulation status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _simulatorService.isSimulating
                  ? Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Driving',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Stopped',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentDriver!.currentLocation != null
                    ? LatLng(
                        _currentDriver!.currentLocation!.latitude,
                        _currentDriver!.currentLocation!.longitude,
                      )
                    : LatLng(
                        destination.latitude,
                        destination.longitude,
                      ),
                zoom: 14,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),

          // Order details and controls
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  _buildStatusCard(isPickingUp, destinationName),
                  const SizedBox(height: 16),

                  // Customer info
                  _buildCustomerInfo(),
                  const SizedBox(height: 16),

                  // Order items
                  _buildOrderItems(),
                  const SizedBox(height: 24),

                  // Action button
                  _buildActionButton(isPickingUp),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isPickingUp, String destinationName) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    if (_currentOrder!.status == OrderStatus.driver_assigned) {
      icon = Icons.restaurant;
      color = Colors.orange;
      title = 'Going to Restaurant';
      subtitle = 'Pick up order from $destinationName';
    } else if (_currentOrder!.status == OrderStatus.driver_at_restaurant) {
      icon = Icons.restaurant;
      color = Colors.blue;
      title = 'At Restaurant';
      subtitle = 'Pick up the order';
    } else if (_currentOrder!.status == OrderStatus.out_for_delivery ||
               _currentOrder!.status == OrderStatus.arriving) {
      icon = Icons.home;
      color = Colors.green;
      title = 'Delivering to Customer';
      subtitle = 'Deliver to $destinationName';
    } else {
      icon = Icons.delivery_dining;
      color = Colors.grey;
      title = 'Active Delivery';
      subtitle = destinationName;
    }

    return Card(
      color: color.withValues(alpha:0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // Determine destination based on current status
                GeoPoint dest = (_currentOrder!.status == OrderStatus.driver_assigned ||
                                _currentOrder!.status == OrderStatus.driver_at_restaurant)
                    ? _currentOrder!.restaurantLocation
                    : _currentOrder!.deliveryLocation;
                
                _openNavigation(dest);
              },
              icon: const Icon(Icons.navigation),
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentOrder!.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentOrder!.customerPhone,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => _callCustomer(_currentOrder!.customerPhone),
                  icon: const Icon(Icons.phone),
                  color: Colors.green,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green[50],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentOrder!.deliveryAddress,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Items',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentOrder!.items.length} items',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._currentOrder!.items.take(3).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.quantity}x',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.name)),
                    ],
                  ),
                )),
            if (_currentOrder!.items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${_currentOrder!.items.length - 3} more items',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isPickingUp) {
    String buttonText;
    VoidCallback? onPressed;
    Color? backgroundColor;

    if (_currentOrder!.status == OrderStatus.driver_assigned) {
      buttonText = 'Arrived at Restaurant';
      onPressed = _markArrivedAtRestaurant;
      backgroundColor = Colors.orange;
    } else if (_currentOrder!.status == OrderStatus.driver_at_restaurant) {
      buttonText = 'Picked Up Order';
      onPressed = _markPickedUp;
      backgroundColor = Colors.blue;
    } else if (_currentOrder!.status == OrderStatus.out_for_delivery ||
        _currentOrder!.status == OrderStatus.arriving) {
      buttonText = 'Complete Delivery';
      onPressed = _completeDelivery;
      backgroundColor = Colors.green;
    } else {
      buttonText = 'Continue';
      onPressed = null;
      backgroundColor = Colors.grey;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: Text(
          buttonText,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _markArrivedAtRestaurant() async {
    try {
      await _firestoreService.updateOrderStatus(
        _currentOrder!.id,
        OrderStatus.driver_at_restaurant,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Marked as arrived at restaurant'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _markPickedUp() async {
    try {
      await _firestoreService.updateOrderStatus(
        _currentOrder!.id,
        OrderStatus.out_for_delivery,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📦 Order picked up! Now delivering to customer...'),
          backgroundColor: Colors.blue,
        ),
      );
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
        content: const Text('Mark this order as delivered?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.updateOrderStatus(
          _currentOrder!.id,
          OrderStatus.delivered,
        );

        await _firestoreService.removeOrderFromDriver(
          widget.driver.id,
          _currentOrder!.id,
        );

        double earnings = _currentOrder!.deliveryFee * 0.8;
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driver.id)
            .update({
          'todayEarnings': FieldValue.increment(earnings),
          'totalDeliveries': FieldValue.increment(1),
          'isAvailable': true,
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Delivery complete! You earned \$${earnings.toStringAsFixed(2)}'),
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

  void _openNavigation(GeoPoint destination) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _callCustomer(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}