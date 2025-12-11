// lib/screens/shared/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/driver_model.dart';
import '../../models/restaurant_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditProfileDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // Profile Picture
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: widget.user.profileImageUrl != null
                            ? NetworkImage(widget.user.profileImageUrl!)
                            : null,
                        child: widget.user.profileImageUrl == null
                            ? Icon(
                                _getRoleIcon(),
                                size: 50,
                                color: Theme.of(context).primaryColor,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _getRoleColor(),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            _getRoleIcon(),
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getRoleLabel(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Basic Info Section
            _buildSection(
              'Basic Information',
              [
                _buildInfoTile(Icons.email, 'Email', widget.user.email),
                _buildInfoTile(Icons.phone, 'Phone', widget.user.phone),
                _buildInfoTile(
                  Icons.calendar_today,
                  'Member Since',
                  _formatDate(widget.user.createdAt),
                ),
              ],
            ),

            // Role-specific sections
            if (widget.user.role == UserRole.driver)
              _buildDriverSection()
            else if (widget.user.role == UserRole.restaurant)
              _buildRestaurantSection(),

            // Account Actions Section
            _buildSection(
              'Account',
              [
                _buildActionTile(
                  Icons.lock_outline,
                  'Change Password',
                  Colors.blue,
                  _changePassword,
                ),
                _buildActionTile(
                  Icons.help_outline,
                  'Help & Support',
                  Colors.orange,
                  _showSupport,
                ),
                _buildActionTile(
                  Icons.privacy_tip_outlined,
                  'Privacy Policy',
                  Colors.purple,
                  _showPrivacyPolicy,
                ),
                _buildActionTile(
                  Icons.logout,
                  'Logout',
                  Colors.red,
                  _handleLogout,
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(
        label,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  // Driver-specific section
  Widget _buildDriverSection() {
    return FutureBuilder<DriverModel?>(
      future: _firestoreService.getDriver(widget.user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        DriverModel driver = snapshot.data!;
        return _buildSection(
          'Driver Information',
          [
            _buildInfoTile(Icons.directions_car, 'Vehicle Type', driver.vehicleType),
            _buildInfoTile(Icons.confirmation_number, 'License Plate', driver.licensePlate),
            _buildInfoTile(
              Icons.star,
              'Rating',
              '${driver.rating.toStringAsFixed(1)} ⭐',
            ),
            _buildInfoTile(
              Icons.delivery_dining,
              'Total Deliveries',
              driver.totalDeliveries.toString(),
            ),
            _buildInfoTile(
              Icons.attach_money,
              'Total Earnings',
              '\$${driver.todayEarnings.toStringAsFixed(2)}',
            ),
          ],
        );
      },
    );
  }

  // Restaurant-specific section
  Widget _buildRestaurantSection() {
    return FutureBuilder<RestaurantModel?>(
      future: _firestoreService.getRestaurant(widget.user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        RestaurantModel restaurant = snapshot.data!;
        return _buildSection(
          'Restaurant Information',
          [
            _buildInfoTile(Icons.restaurant, 'Restaurant Name', restaurant.name),
            _buildInfoTile(Icons.category, 'Cuisine Type', restaurant.cuisineType),
            _buildInfoTile(Icons.location_on, 'Address', restaurant.address),
            _buildInfoTile(
              Icons.star,
              'Rating',
              '${restaurant.rating.toStringAsFixed(1)} ⭐',
            ),
            _buildInfoTile(
              Icons.access_time,
              'Delivery Time',
              '${restaurant.estimatedDeliveryTime} mins',
            ),
            ListTile(
              leading: Icon(
                restaurant.isOpen ? Icons.check_circle : Icons.cancel,
                color: restaurant.isOpen ? Colors.green : Colors.red,
              ),
              title: const Text('Status'),
              subtitle: Text(
                restaurant.isOpen ? 'Open' : 'Closed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: restaurant.isOpen ? Colors.green : Colors.red,
                ),
              ),
              trailing: Switch(
                value: restaurant.isOpen,
                onChanged: (value) => _toggleRestaurantStatus(value),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getRoleIcon() {
    switch (widget.user.role) {
      case UserRole.customer:
        return Icons.person;
      case UserRole.restaurant:
        return Icons.restaurant;
      case UserRole.driver:
        return Icons.delivery_dining;
    }
  }

  Color _getRoleColor() {
    switch (widget.user.role) {
      case UserRole.customer:
        return Colors.blue;
      case UserRole.restaurant:
        return Colors.orange;
      case UserRole.driver:
        return Colors.green;
    }
  }

  String _getRoleLabel() {
    switch (widget.user.role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.restaurant:
        return 'Restaurant Owner';
      case UserRole.driver:
        return 'Delivery Driver';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: widget.user.name);
    final phoneController = TextEditingController(text: widget.user.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              try {
                await Provider.of<AuthProvider>(context, listen: false)
                    .updateProfile(
                  userId: widget.user.id,
                  name: nameController.text,
                  phone: phoneController.text,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!')),
                  );
                  // The AuthProvider will automatically update and notify listeners
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final emailController = TextEditingController(text: widget.user.email);

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'We will send a password reset link to your email address.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              readOnly: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Provider.of<AuthProvider>(context, listen: false)
            .resetPassword(widget.user.email);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset link sent to your email!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _showSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need help? Contact us:'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.email, size: 20),
                const SizedBox(width: 8),
                const Text('support@foodrunner.com'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 20),
                const SizedBox(width: 8),
                const Text('+1 (555) 123-4567'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Food Runner Privacy Policy\n\n'
            'We collect and process your personal information to provide you with our food delivery services...\n\n'
            'Your data is stored securely and we never share it with third parties without your consent...\n\n'
            'For full details, visit: www.foodrunner.com/privacy',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Provider.of<AuthProvider>(context, listen: false).signOut();
        // Navigation is handled automatically by AuthWrapper
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
          
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout error: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleRestaurantStatus(bool isOpen) async {
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.user.id)
          .update({'isOpen': isOpen});

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOpen ? 'Restaurant is now open' : 'Restaurant is now closed'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}