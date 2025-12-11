// lib/screens/driver/order_request_modal.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/driver_assignment_service.dart';

class OrderRequestModal extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> requestData;
  final String requestId;

  const OrderRequestModal({
    super.key,
    required this.driverId,
    required this.requestData,
    required this.requestId,
  });

  @override
  State<OrderRequestModal> createState() => _OrderRequestModalState();
}

class _OrderRequestModalState extends State<OrderRequestModal> {
  final DriverAssignmentService _assignmentService = DriverAssignmentService();
  
  int _remainingSeconds = 30;
  Timer? _timer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds <= 0) {
          _autoReject();
        }
      }
    });
  }

  void _autoReject() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final distance = (widget.requestData['distance'] as double) / 1000;
    final earnings = widget.requestData['estimatedEarnings'] as double;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer circle
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: _remainingSeconds / 30,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _remainingSeconds > 10 ? Colors.orange : Colors.red,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      _remainingSeconds.toString(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'seconds',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // New Order Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'NEW ORDER',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Restaurant info
            Text(
              widget.requestData['restaurantName'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.requestData['itemCount']} items',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  Icons.location_on,
                  '${distance.toStringAsFixed(1)} km',
                  'Distance',
                  Colors.blue,
                ),
                _buildStatCard(
                  Icons.attach_money,
                  '\$${earnings.toStringAsFixed(2)}',
                  'Earnings',
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Delivery address
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.place, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.requestData['customerAddress'],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => _handleReject(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _handleAccept(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAccept() async {
    setState(() => _isProcessing = true);
    _timer?.cancel();

    try {
      // Assign order to this driver
      await _assignmentService.assignOrderToDriver(
        widget.requestData['orderId'],
        widget.driverId,
        widget.requestData['driverName'],
      );

      // Update request status
      await FirebaseFirestore.instance
          .collection('orderRequests')
          .doc(widget.requestId)
          .update({'status': 'accepted'});

      if (mounted) {
        Navigator.pop(context, true); // Return true for accepted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        Navigator.pop(context, false);
      }
    }
  }

  Future<void> _handleReject() async {
    _timer?.cancel();

    // Update request status
    await FirebaseFirestore.instance
        .collection('orderRequests')
        .doc(widget.requestId)
        .update({'status': 'rejected'});

    if (mounted) {
      Navigator.pop(context, false);
    }
  }
}