// lib/screens/customer/order_tracking_screen.dart
import 'package:flutter/material.dart';
import 'rate_order_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../models/order_model.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import '../../services/directions_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final DirectionsService _directionsService = DirectionsService();
  
  GoogleMapController? _mapController;
  StreamSubscription<OrderModel>? _orderSubscription;
  StreamSubscription<DriverModel>? _driverSubscription;
  
  OrderModel? _currentOrder;
  DriverModel? _currentDriver;
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  
  bool _isLoadingRoute = false;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _driverSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadOrderData() async {
    // Listen to order updates
    _orderSubscription = _firestoreService.streamOrder(widget.orderId).listen(
      (order) async {
        OrderStatus? oldStatus = _currentOrder?.status;
        
        setState(() {
          _currentOrder = order;
        });

        // If driver is assigned and we haven't started listening yet
        if (order.driverId != null && _driverSubscription == null) {
          debugPrint('🚗 Driver assigned: ${order.driverName}');
          _startListeningToDriver(order.driverId!);
          
          // Show map once driver is assigned
          setState(() {
            _showMap = true;
          });
          
          // Load initial route (driver to restaurant)
          await _loadRoute();
        }
        
        // Also reload route if we already have a driver and are in an active delivery status
        if (order.driverId != null && _driverSubscription != null && _polylines.isEmpty) {
          if (order.status == OrderStatus.driver_assigned ||
              order.status == OrderStatus.driver_at_restaurant ||
              order.status == OrderStatus.out_for_delivery ||
              order.status == OrderStatus.arriving) {
            debugPrint('🔄 Hot reload detected - reloading route');
            await _loadRoute();
          }
        }

        // Reload route when status changes to key statuses
        if (oldStatus != null && oldStatus != order.status) {
          debugPrint('📍 Status changed from ${oldStatus.toString().split('.').last} to ${order.status.toString().split('.').last}');
          
          // Reload route when driver starts going to restaurant or delivering to customer
          if (order.status == OrderStatus.driver_assigned ||
              order.status == OrderStatus.out_for_delivery) {
            debugPrint('🔄 Reloading route for new status');
            await _loadRoute();
          }
        }

        _updateMarkers();
      },
    );
  }

  void _startListeningToDriver(String driverId) {
    debugPrint('👂 Listening to driver location updates');
    
    _driverSubscription = _firestoreService.streamDriver(driverId).listen(
      (driver) {
        setState(() {
          _currentDriver = driver;
        });
        _updateMarkers(); 
        _updateCameraToDriver();
      },
    );
  }

  Future<void> _loadRoute() async {
    if (_currentOrder == null || _currentOrder!.driverId == null) {
      debugPrint('⚠️ Cannot load route: order or driver not available');
      return;
    }

    setState(() => _isLoadingRoute = true);

    try {
      // Determine route based on order status
      GeoPoint origin;
      GeoPoint destination;

      if (_currentOrder!.status == OrderStatus.driver_assigned ||
          _currentOrder!.status == OrderStatus.driver_at_restaurant) {
        // Driver going to restaurant
        origin = _currentDriver?.currentLocation ?? _currentOrder!.restaurantLocation;
        destination = _currentOrder!.restaurantLocation;
        debugPrint('🗺️ Loading route: Driver → Restaurant');
        debugPrint('   Origin: ${origin.latitude}, ${origin.longitude}');
        debugPrint('   Destination: ${destination.latitude}, ${destination.longitude}');
      } else if (_currentOrder!.status == OrderStatus.out_for_delivery ||
                 _currentOrder!.status == OrderStatus.arriving) {
        // Driver delivering to customer
        origin = _currentDriver?.currentLocation ?? _currentOrder!.restaurantLocation;
        destination = _currentOrder!.deliveryLocation;
        debugPrint('🗺️ Loading route: Restaurant → Customer');
        debugPrint('   Origin: ${origin.latitude}, ${origin.longitude}');
        debugPrint('   Destination: ${destination.latitude}, ${destination.longitude}');
      } else {
        // No active route needed
        debugPrint('ℹ️ No route needed for status: ${_currentOrder!.status}');
        setState(() => _isLoadingRoute = false);
        return;
      }

      final routeInfo = await _directionsService.getRoute(
        origin: origin,
        destination: destination,
      );

      if (routeInfo != null && mounted) {
        Set<Polyline> polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: routeInfo.points.map((geoPoint) {
              return LatLng(geoPoint.latitude, geoPoint.longitude);
            }).toList(),
            color: Colors.blue,
            width: 5,
            geodesic: true,
          ),
        };

        setState(() {
          _polylines = polylines;
        });

        debugPrint('✅ Customer map: Route loaded with ${routeInfo.points.length} points');
        debugPrint('   Distance: ${routeInfo.distanceText}');
        debugPrint('   Duration: ${routeInfo.durationText}');
        
        // Fit map to show route
        _fitMapToRoute(routeInfo.points);
      } else {
        debugPrint('❌ Failed to get route info');
      }
    } catch (e) {
      debugPrint('❌ Error loading route: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  void _updateMarkers() {
    if (_currentOrder == null) return;

    Set<Marker> markers = {};

    // Restaurant marker (if driver hasn't picked up yet)
    if (_currentOrder!.status == OrderStatus.driver_assigned ||
        _currentOrder!.status == OrderStatus.driver_at_restaurant) {
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

    // Customer location 
    markers.add(
      Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(
          _currentOrder!.deliveryLocation.latitude,
          _currentOrder!.deliveryLocation.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: '🏠 Your Location',
          snippet: 'Delivery address',
        ),
      ),
    );

    setState(() {
      _markers = markers;
    });

    // Update driver circle
    _updateDriverCircle();
  }

  void _updateDriverCircle() {
    Set<Circle> circles = {};

    // Show driver circle whenever we have driver location and map is visible
    if (_currentDriver?.currentLocation != null && _showMap) {
      LatLng driverPosition = LatLng(
        _currentDriver!.currentLocation!.latitude,
        _currentDriver!.currentLocation!.longitude,
      );

      debugPrint('🔵 Updating driver circle at: ${driverPosition.latitude}, ${driverPosition.longitude}');

      // Outer pulse circle
      circles.add(
        Circle(
          circleId: const CircleId('driver_pulse'),
          center: driverPosition,
          radius: 70,
          fillColor: Colors.blue.withValues(alpha: 0.4),
          strokeColor: Colors.blue.withValues(alpha: 0.6),
          strokeWidth: 9,
          visible: true,
          zIndex: 999,
        ),
      );

      // Inner solid circle
      circles.add(
        Circle(
          circleId: const CircleId('driver'),
          center: driverPosition,
          radius: 20,
          fillColor: Colors.blue,
          strokeColor: Colors.white,
          strokeWidth: 4,
          visible: true,
          zIndex: 1000,
        ),
      );
    }

    setState(() {
      _circles = circles;
    });
  }

  void _updateCameraToDriver() {
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

  void _fitMapToRoute(List<GeoPoint> points) {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    double padding = 0.005;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentOrder == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    

    bool showLiveTracking = _showMap && 
                           _currentOrder!.driverId != null &&
                           (_currentOrder!.status == OrderStatus.driver_assigned ||
                            _currentOrder!.status == OrderStatus.driver_at_restaurant ||
                            _currentOrder!.status == OrderStatus.out_for_delivery ||
                            _currentOrder!.status == OrderStatus.arriving);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_currentOrder!.id.substring(0, 8)}'),
      ),
      body: Column(
        children: [
          // Map (only show when driver is assigned)
          if (showLiveTracking)
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentOrder!.deliveryLocation.latitude,
                        _currentOrder!.deliveryLocation.longitude,
                      ),
                      zoom: 14,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    circles: _circles,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    mapType: MapType.normal,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      
                      // Reload route if we don't have polylines yet
                      if (_polylines.isEmpty && 
                          _currentOrder!.driverId != null &&
                          (_currentOrder!.status == OrderStatus.driver_assigned ||
                           _currentOrder!.status == OrderStatus.driver_at_restaurant ||
                           _currentOrder!.status == OrderStatus.out_for_delivery ||
                           _currentOrder!.status == OrderStatus.arriving)) {
                        debugPrint('🗺️ Map created but no polylines - loading route');
                        _loadRoute();
                      }
                    },
                  ),
                  if (_isLoadingRoute)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),

          // Order status and details
          Expanded(
            flex: showLiveTracking ? 1 : 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  if (_currentOrder!.status == OrderStatus.delivered && !_currentOrder!.isRated) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RateOrderScreen(order: _currentOrder!),
                            ),
                          );
                        },
                        icon: const Icon(Icons.star),
                        label: const Text('Rate Your Experience'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                  // Show if already rated
                  if (_currentOrder!.isRated) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thanks for your feedback!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildStars(_currentOrder!.restaurantRating ?? 5, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Restaurant',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    _buildStars(_currentOrder!.driverRating ?? 5, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Driver',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_currentOrder!.driverId != null) _buildDriverInfo(),
                  const SizedBox(height: 16),
                  _buildOrderSummary(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _currentOrder!.getStatusColor().withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _currentOrder!.getStatusIcon(),
                color: _currentOrder!.getStatusColor(),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentOrder!.getStatusMessage(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _currentOrder!.getStatusColor(),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusDescription(),
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusDescription() {
    switch (_currentOrder!.status) {
      case OrderStatus.pending:
        return 'Waiting for restaurant to accept';
      case OrderStatus.accepted:
        return 'Restaurant is preparing your order';
      case OrderStatus.preparing:
        return 'Your order is being prepared';
      case OrderStatus.ready_for_pickup:
        return 'Order is ready, finding a driver...';
      case OrderStatus.finding_driver:
        return 'Looking for nearby drivers...';
      case OrderStatus.driver_assigned:
        return 'Driver is heading to the restaurant';
      case OrderStatus.driver_at_restaurant:
        return 'Driver is picking up your order';
      case OrderStatus.out_for_delivery:
        return 'Driver is on the way to you!';
      case OrderStatus.arriving:
        return 'Driver is arriving soon!';
      case OrderStatus.delivered:
        return 'Enjoy your meal!';
      default:
        return '';
    }
  }

  Widget _buildDriverInfo() {
    // Determine driver's current activity
    String driverActivity = '';
    IconData activityIcon = Icons.local_shipping;
    Color activityColor = Colors.blue;
    
    if (_currentOrder!.status == OrderStatus.driver_assigned) {
      driverActivity = 'Heading to restaurant';
      activityIcon = Icons.restaurant;
      activityColor = Colors.orange;
    } else if (_currentOrder!.status == OrderStatus.driver_at_restaurant) {
      driverActivity = 'Picking up order';
      activityIcon = Icons.shopping_bag;
      activityColor = Colors.amber;
    } else if (_currentOrder!.status == OrderStatus.out_for_delivery) {
      driverActivity = 'On the way to you';
      activityIcon = Icons.home;
      activityColor = Colors.green;
    } else if (_currentOrder!.status == OrderStatus.arriving) {
      driverActivity = 'Arriving soon';
      activityIcon = Icons.location_on;
      activityColor = Colors.red;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.delivery_dining, color: Colors.blue[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentOrder!.driverName ?? 'Driver',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_currentDriver != null)
                        Text(
                          '${_currentDriver!.vehicleType} • ${_currentDriver!.licensePlate}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: () {
                    // Call driver (if phone number available)
                    // For demo, we won't implement this and aonly show the button
                  },
                ),
              ],
            ),
            // Show current activity if driver is en route
            if (driverActivity.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: activityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: activityColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(activityIcon, color: activityColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      driverActivity,
                      style: TextStyle(
                        color: activityColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStars(int rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rating, (index) {
        return Icon(
          Icons.star,
          size: size,
          color: Colors.amber,
        );
      }),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ..._currentOrder!.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.quantity}x ${item.name}'),
                      Text('\$${(item.price * item.quantity).toStringAsFixed(2)}'),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '\$${_currentOrder!.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}