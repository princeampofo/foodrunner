// lib/screens/driver/active_delivery_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../models/order_model.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import '../../services/driver_simulator_service.dart';

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
  Timer? _distanceCheckTimer;
  
  OrderModel? _currentOrder;
  DriverModel? _currentDriver;
  
  Set<Marker> _markers = {};
  double? _distanceToDestination;
  bool _isNavigating = false; // Track if navigation has started
  
  // Distance thresholds (in meters)
  static const double ARRIVAL_THRESHOLD = 50.0; // 50 meters
  static const double COMPLETION_THRESHOLD = 30.0; // 30 meters

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _currentDriver = widget.driver;
    
    _initializeScreen();
    _listenToOrderUpdates();
    _listenToDriverUpdates();
    _startDistanceMonitoring();
    
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _driverSubscription?.cancel();
    _distanceCheckTimer?.cancel();
    _mapController?.dispose();
    _simulatorService.stopSimulation();
    super.dispose();
  }

  void _initializeScreen() {
    _updateMarkers();
  }

  void _listenToOrderUpdates() {
    _orderSubscription = _firestoreService.streamOrder(_currentOrder!.id).listen(
      (order) {
        OrderStatus oldStatus = _currentOrder!.status;
        
        setState(() {
          _currentOrder = order;
        });
        
        _updateMarkers();
        
        if (oldStatus != order.status) {
          _handleStatusChange(oldStatus, order.status);
        }
      },
    );
  }

  void _listenToDriverUpdates() {
    _driverSubscription = _firestoreService.streamDriver(widget.driver.id).listen(
      (driver) {
        setState(() {
          _currentDriver = driver;
        });
        _updateCameraPosition();
      },
    );
  }

  void _startDistanceMonitoring() {
    // Check distance every 2 seconds
    _distanceCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _calculateDistanceToDestination();
    });
  }

  void _calculateDistanceToDestination() {
    if (_currentDriver?.currentLocation == null || _currentOrder == null) return;

    GeoPoint destination;
    
    if (_currentOrder!.status == OrderStatus.driver_assigned ||
        _currentOrder!.status == OrderStatus.driver_at_restaurant) {
      destination = _currentOrder!.restaurantLocation;
    } else if (_currentOrder!.status == OrderStatus.out_for_delivery ||
               _currentOrder!.status == OrderStatus.arriving) {
      destination = _currentOrder!.deliveryLocation;
    } else {
      return;
    }

    double distance = Geolocator.distanceBetween(
      _currentDriver!.currentLocation!.latitude,
      _currentDriver!.currentLocation!.longitude,
      destination.latitude,
      destination.longitude,
    );

    setState(() {
      _distanceToDestination = distance;
    });

    if (_distanceToDestination! % 100 < 2) { // Log every ~100m
      debugPrint('📏 Distance to destination: ${distance.toStringAsFixed(1)}m');
    }
  }

  void _handleStatusChange(OrderStatus oldStatus, OrderStatus newStatus) {
    debugPrint('🔄 Status changed: ${oldStatus.toString().split('.').last} → ${newStatus.toString().split('.').last}');
    
    // Stop simulation when arriving at restaurant
    if (newStatus == OrderStatus.driver_at_restaurant) {
      debugPrint('🛑 Arrived at restaurant - stopping simulation');
      _simulatorService.stopSimulation();
      setState(() {
        _isNavigating = false;
      });
    }
    
    // Stop simulation when delivery is complete
    if (newStatus == OrderStatus.delivered) {
      debugPrint('🛑 Delivery complete - stopping simulation');
      _simulatorService.stopSimulation();
      setState(() {
        _isNavigating = false;
      });
    }
  }

  // Start navigation to restaurant
  void _startNavigationToRestaurant() {
    if (_isNavigating) {
      debugPrint('⚠️ Already navigating');
      return;
    }

    debugPrint('🚗 Starting navigation to restaurant');
    
    GeoPoint startLocation = _currentDriver!.currentLocation ??
        const GeoPoint(33.7490, -84.3880);

    _simulatorService.startSimulation(
      driverId: widget.driver.id,
      startLocation: startLocation,
      endLocation: _currentOrder!.restaurantLocation,
      speedKmh: 40,
    );

    setState(() {
      _isNavigating = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.navigation, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('🚗 Navigating to ${_currentOrder!.restaurantName}'),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Start navigation to customer
  void _startNavigationToCustomer() {
    if (_isNavigating) {
      debugPrint('⚠️ Already navigating');
      return;
    }

    debugPrint('🚗 Starting navigation to customer');
    
    GeoPoint startLocation = _currentDriver!.currentLocation ??
        _currentOrder!.restaurantLocation;

    _simulatorService.startSimulation(
      driverId: widget.driver.id,
      startLocation: startLocation,
      endLocation: _currentOrder!.deliveryLocation,
      speedKmh: 40,
    );

    setState(() {
      _isNavigating = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.navigation, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('🚗 Delivering to ${_currentOrder!.customerName}'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateMarkers() {
    if (_currentOrder == null) return;

    Set<Marker> markers = {};

    // Only show destination marker (restaurant OR customer based on status)
    bool isGoingToRestaurant = _currentOrder!.status == OrderStatus.driver_assigned ||
        _currentOrder!.status == OrderStatus.driver_at_restaurant;

    if (isGoingToRestaurant) {
      // Show restaurant
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(
            _currentOrder!.restaurantLocation.latitude,
            _currentOrder!.restaurantLocation.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: _currentOrder!.restaurantName,
            snippet: 'Pickup location',
          ),
        ),
      );
    } else {
      // Show customer
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(
            _currentOrder!.deliveryLocation.latitude,
            _currentOrder!.deliveryLocation.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: _currentOrder!.customerName,
            snippet: 'Delivery location',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _updateCameraPosition() {
    if (_mapController == null) return;

    // Focus on destination marker
    GeoPoint destination = (_currentOrder!.status == OrderStatus.driver_assigned ||
                           _currentOrder!.status == OrderStatus.driver_at_restaurant)
        ? _currentOrder!.restaurantLocation
        : _currentOrder!.deliveryLocation;

    _mapController!.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(destination.latitude, destination.longitude),
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

    bool isGoingToRestaurant = _currentOrder!.status == OrderStatus.driver_assigned ||
        _currentOrder!.status == OrderStatus.driver_at_restaurant;

    String destinationName = isGoingToRestaurant
        ? _currentOrder!.restaurantName
        : _currentOrder!.customerName;

    GeoPoint destination = isGoingToRestaurant
        ? _currentOrder!.restaurantLocation
        : _currentOrder!.deliveryLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_currentOrder!.id.substring(0, 8)}'),
        actions: [
          // Navigation status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _isNavigating
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
                          'Navigating',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                          'Idle',
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
          // Simplified map showing only destination
          Expanded(
            flex: 1,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(destination.latitude, destination.longitude),
                zoom: 15,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),

          // Driver controls and info
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDestinationCard(isGoingToRestaurant, destinationName, destination),
                  const SizedBox(height: 16),
                  if (_distanceToDestination != null) _buildDistanceCard(),
                  const SizedBox(height: 16),
                  _buildOrderInfo(),
                  const SizedBox(height: 24),
                  _buildActionButtons(isGoingToRestaurant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(bool isGoingToRestaurant, String name, GeoPoint destination) {
    return Card(
      color: isGoingToRestaurant ? Colors.orange[50] : Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isGoingToRestaurant ? Icons.restaurant : Icons.home,
                  color: isGoingToRestaurant ? Colors.orange : Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGoingToRestaurant ? 'Pickup Location' : 'Delivery Location',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Navigate button - starts simulation
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isNavigating 
                    ? null 
                    : (isGoingToRestaurant 
                        ? _startNavigationToRestaurant 
                        : _startNavigationToCustomer),
                icon: Icon(_isNavigating ? Icons.navigation : Icons.play_arrow),
                label: Text(_isNavigating ? 'Navigating...' : 'Start Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isNavigating ? Colors.grey : Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: Colors.grey[400],
                ),
              ),
            ),
            
            // Stop navigation button (when navigating)
            if (_isNavigating) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _simulatorService.stopSimulation();
                    setState(() {
                      _isNavigating = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🛑 Navigation stopped'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Navigation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceCard() {
    String distanceText;
    Color cardColor;
    
    if (_distanceToDestination! >= 1000) {
      distanceText = '${(_distanceToDestination! / 1000).toStringAsFixed(1)} km away';
      cardColor = Colors.blue;
    } else if (_distanceToDestination! > 100) {
      distanceText = '${_distanceToDestination!.toStringAsFixed(0)} m away';
      cardColor = Colors.blue;
    } else {
      distanceText = '${_distanceToDestination!.toStringAsFixed(0)} m away';
      cardColor = Colors.green; // Close to destination
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, color: cardColor, size: 20),
          const SizedBox(width: 8),
          Text(
            distanceText,
            style: TextStyle(
              color: cardColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentOrder!.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _currentOrder!.customerPhone,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Call customer (simplified for demo)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling ${_currentOrder!.customerPhone}...')),
                    );
                  },
                  icon: const Icon(Icons.phone, color: Colors.green),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              '${_currentOrder!.items.length} items • \$${_currentOrder!.total.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isGoingToRestaurant) {
    // Determine which button to show based on status and distance
    String? buttonText;
    VoidCallback? onPressed;
    Color? backgroundColor;
    bool isEnabled = false;

    if (_currentOrder!.status == OrderStatus.driver_assigned) {
      buttonText = 'Arrived at Restaurant';
      backgroundColor = Colors.orange;
      // Only enable if within 50 meters
      isEnabled = _distanceToDestination != null && 
                  _distanceToDestination! <= ARRIVAL_THRESHOLD;
      onPressed = isEnabled ? _markArrivedAtRestaurant : null;
    } else if (_currentOrder!.status == OrderStatus.driver_at_restaurant) {
      buttonText = 'Picked Up Order';
      backgroundColor = Colors.blue;
      isEnabled = true; // Always enabled once at restaurant
      onPressed = _markPickedUp;
    } else if (_currentOrder!.status == OrderStatus.out_for_delivery ||
               _currentOrder!.status == OrderStatus.arriving) {
      buttonText = 'Complete Delivery';
      backgroundColor = Colors.green;
      // Only enable if within 30 meters
      isEnabled = _distanceToDestination != null && 
                  _distanceToDestination! <= COMPLETION_THRESHOLD;
      onPressed = isEnabled ? _completeDelivery : null;
    }

    if (buttonText == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Distance requirement message
        if (!isEnabled && _distanceToDestination != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentOrder!.status == OrderStatus.driver_assigned
                        ? 'Get within 50m of restaurant to mark arrival'
                        : 'Get within 30m of customer to complete delivery',
                    style: TextStyle(
                      color: Colors.amber[900],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Action button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEnabled ? backgroundColor : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
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
      
      // Reset navigation state for next leg
      setState(() {
        _isNavigating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📦 Order picked up! Now click Navigate to start delivery.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
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
        content: const Text('Confirm delivery completion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
}