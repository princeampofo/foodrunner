// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;
  
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        // User is logged in, fetch user data
        await _loadUserData(firebaseUser.uid);
      } else {
        // User is logged out
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String userId) async {
    try {
      UserModel? userData = await _authService.getUserData(userId);
      _currentUser = userData;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
      _currentUser = null;
      notifyListeners();
    }
  }

  // Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      UserModel? user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
        additionalData: additionalData,
      );

      _isLoading = false;
      
      if (user != null) {
        _currentUser = user;
        notifyListeners();
        return true;
      }
      
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Sign in
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      UserModel? user = await _authService.signIn(
        email: email,
        password: password,
      );

      _isLoading = false;
      
      if (user != null) {
        _currentUser = user;
        notifyListeners();
        return true;
      }
      
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signOut();
      
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Update profile
  Future<void> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? profileImageUrl,
  }) async {
    try {
      await _authService.updateProfile(
        userId: userId,
        name: name,
        phone: phone,
        profileImageUrl: profileImageUrl,
      );

      // Reload user data
      await _loadUserData(userId);
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }
}