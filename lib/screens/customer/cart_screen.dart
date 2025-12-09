// lib/screens/customer/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/restaurant_model.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/user_model.dart';
import '../../../../models/order_model.dart';
import '../../services/firestore_service.dart';
import 'order_tracking_screen.dart';

class CartScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  final UserModel user;
  final Map<String, int> cart;

  const CartScreen({
    super.key,
    required this.restaurant,
    required this.user,
    required this.cart,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _addressController = TextEditingController(text: '123 Main St, Atlanta, GA');
  bool _isLoading = false;
  List<MenuItemModel> _menuItems = [];

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _loadMenuItems() async {
    // Load menu items to get details for cart
    final stream = _firestoreService.getMenuItems(widget.restaurant.id);
    stream.first.then((items) {
      setState(() {
        _menuItems = items.where((item) => widget.cart.containsKey(item.id)).toList();
      });
    });
  }

  double get _subtotal {
    double total = 0;
    for (var item in _menuItems) {
      int quantity = widget.cart[item.id] ?? 0;
      total += item.price * quantity;
    }
    return total;
  }

  double get _deliveryFee => 2.99;
  double get _tax => _subtotal * 0.08;
  double get _total => _subtotal + _deliveryFee + _tax;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
      ),
      body: _menuItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Restaurant info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.restaurant, color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.restaurant.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      widget.restaurant.address,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cart items
                      Text(
                        'Order Items',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ..._menuItems.map((item) => _buildCartItem(item)),

                      const SizedBox(height: 16),

                      // Delivery address
                      Text(
                        'Delivery Address',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.location_on),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Order summary
                      Text(
                        'Order Summary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildSummaryRow('Subtotal', _subtotal),
                              _buildSummaryRow('Delivery Fee', _deliveryFee),
                              _buildSummaryRow('Tax', _tax),
                              const Divider(height: 24),
                              _buildSummaryRow('Total', _total, isBold: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Place order button
                Container(
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
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _placeOrder,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Place Order - \$${_total.toStringAsFixed(2)}'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCartItem(MenuItemModel item) {
    int quantity = widget.cart[item.id] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.fastfood),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${item.price.toStringAsFixed(2)} × $quantity',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Text(
              '\$${(item.price * quantity).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    setState(() => _isLoading = true);

    try {
      // Create order items
      List<OrderItem> orderItems = _menuItems.map((item) {
        return OrderItem(
          menuItemId: item.id,
          name: item.name,
          price: item.price,
          quantity: widget.cart[item.id]!,
        );
      }).toList();

      // Create order
      OrderModel order = OrderModel(
        id: '', // Will be set by Firestore
        customerId: widget.user.id,
        customerName: widget.user.name,
        customerPhone: widget.user.phone,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        items: orderItems,
        subtotal: _subtotal,
        deliveryFee: _deliveryFee,
        tax: _tax,
        total: _total,
        status: OrderStatus.pending,
        deliveryLocation: const GeoPoint(33.7490, -84.3880), // Default location
        deliveryAddress: _addressController.text,
        restaurantLocation: widget.restaurant.location,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      String orderId = await _firestoreService.createOrder(order);

      // Navigate to order tracking
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(
              orderId: orderId,
              user: widget.user,
            ),
          ),
          (route) => route.isFirst, // Remove all routes except home
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing order: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}