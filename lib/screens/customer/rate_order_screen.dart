// lib/screens/customer/rate_order_screen.dart
import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../models/rating_model.dart';
import '../../services/rating_service.dart';

class RateOrderScreen extends StatefulWidget {
  final OrderModel order;

  const RateOrderScreen({super.key, required this.order});

  @override
  State<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends State<RateOrderScreen> {
  final RatingService _ratingService = RatingService();
  final PageController _pageController = PageController();
  
  int _currentPage = 0;
  
  // Restaurant rating
  int _restaurantRating = 5;
  final TextEditingController _restaurantReviewController = TextEditingController();
  
  // Driver rating
  int _driverRating = 5;
  final TextEditingController _driverReviewController = TextEditingController();
  
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _restaurantReviewController.dispose();
    _driverReviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildProgressStep(0, 'Restaurant'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildProgressStep(1, 'Driver'),
                ),
              ],
            ),
          ),
          
          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildRestaurantRatingPage(),
                _buildDriverRatingPage(),
              ],
            ),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String label) {
    bool isActive = _currentPage == step;
    bool isCompleted = _currentPage > step;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isActive || isCompleted ? Colors.blue : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.circle,
            size: 16,
            color: isActive || isCompleted ? Colors.white : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive || isCompleted ? Colors.white : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantRatingPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.restaurant,
            size: 80,
            color: Colors.orange[700],
          ),
          const SizedBox(height: 16),
          Text(
            widget.order.restaurantName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'How was your food?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          
          // Star rating
          _buildStarRating(
            rating: _restaurantRating,
            onRatingChanged: (rating) {
              setState(() {
                _restaurantRating = rating;
              });
            },
          ),
          
          const SizedBox(height: 32),
          
          // Review text field
          TextField(
            controller: _restaurantReviewController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Share your experience (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRatingPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.delivery_dining,
            size: 80,
            color: Colors.blue[700],
          ),
          const SizedBox(height: 16),
          Text(
            widget.order.driverName ?? 'Your Driver',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'How was your delivery?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          
          // Star rating
          _buildStarRating(
            rating: _driverRating,
            onRatingChanged: (rating) {
              setState(() {
                _driverRating = rating;
              });
            },
          ),
          
          const SizedBox(height: 32),
          
          // Review text field
          TextField(
            controller: _driverReviewController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Share your experience (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating({
    required int rating,
    required Function(int) onRatingChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        int starValue = index + 1;
        return IconButton(
          onPressed: () => onRatingChanged(starValue),
          icon: Icon(
            starValue <= rating ? Icons.star : Icons.star_border,
            size: 48,
            color: Colors.amber,
          ),
        );
      }),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_currentPage == 0 ? 'Next' : 'Submit'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNext() async {
    if (_currentPage == 0) {
      // Move to driver rating page
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Submit ratings
      await _submitRatings();
    }
  }

  Future<void> _submitRatings() async {
    setState(() => _isSubmitting = true);

    try {
      // Create rating model
      RatingModel rating = RatingModel(
        id: '',
        orderId: widget.order.id,
        customerId: widget.order.customerId,
        customerName: widget.order.customerName,
        restaurantId: widget.order.restaurantId,
        restaurantName: widget.order.restaurantName,
        restaurantRating: _restaurantRating,
        restaurantReview: _restaurantReviewController.text.trim().isEmpty
            ? null
            : _restaurantReviewController.text.trim(),
        driverId: widget.order.driverId!,
        driverName: widget.order.driverName!,
        driverRating: _driverRating,
        driverReview: _driverReviewController.text.trim().isEmpty
            ? null
            : _driverReviewController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Submit rating
      await _ratingService.submitRating(rating);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}