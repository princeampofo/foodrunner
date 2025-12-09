// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
// import 'screens/auth/auth_screen.dart';
// import 'screens/customer/customer_home_screen.dart';
// import 'screens/restaurant/restaurant_dashboard_screen.dart';
// import 'screens/driver/driver_home_screen.dart';
// import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Food Runner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.orange,
          scaffoldBackgroundColor: Colors.grey[50],
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading while checking auth state
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is not authenticated
        if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
          // return const AuthScreen();
        }

        // User is authenticated - route based on role
        // UserModel user = authProvider.currentUser!;
        
        // switch (user.role) {
        //   case UserRole.customer:
        //     return CustomerHomeScreen(user: user);
        //   case UserRole.restaurant:
        //     return RestaurantDashboardScreen(user: user);
        //   case UserRole.driver:
        //     return DriverHomeScreen(user: user);
        // }

        return const Scaffold(
          body: Center(
            child: Text('Role-based screen not implemented yet.'),
          ),
        );
      },
    );
  }
}