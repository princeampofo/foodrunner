// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      UserModel user = UserModel(
        id: userCredential.user!.uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.id).set(user.toMap());

      // Create role-specific document
      if (role == UserRole.driver && additionalData != null) {
        await _firestore.collection('drivers').doc(user.id).set({
          ...additionalData,
          'name': name,
          'phone': phone,
          'email': email,
          'vehicleType': additionalData['vehicleType'] ?? '',
          'licensePlate': additionalData['licensePlate'] ?? '',
          'vehicleImageUrl': null,
          'currentLocation': null,
          'geohash': null,
          'isOnline': false,
          'isAvailable': false,
          'activeOrderIds': [],
          'maxCapacity': 4,
          'rating': 5.0,
          'totalDeliveries': 0,
          'todayEarnings': 0.0,
          'lastUpdated': null,
          'heading': 0.0,             
          'speed': 0.0,               
          'accuracy': 0.0,            
        });
      } else if (role == UserRole.restaurant && additionalData != null) {
        await _firestore.collection('restaurants').doc(user.id).set({
          ...additionalData,
          'ownerId': user.id,
          'rating': 0.0,
          'totalRatings': 0,
          'isOpen': true,
        });
      }

      return user;
    } catch (e) {
      debugPrint('Sign up error: $e');
      rethrow;
    }
  }

  // Sign in
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get user data from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      return UserModel.fromFirestore(userDoc);
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  // Get user data
  Future<UserModel?> getUserData(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      }
      return null;
    } catch (e) {
      debugPrint('Get user data error: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final userId = _auth.currentUser?.uid;
      
      if (userId != null) {
        // Get user data to check role
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
        
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          String role = userData['role'] ?? '';
          
          // If driver, mark as offline before logout
          if (role == 'driver') {
            await _firestore.collection('drivers').doc(userId).update({
              'isOnline': false,
              'isAvailable': false,
            });
          }
        }
      }
      
      // Sign out from Firebase Auth
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Update profile
  Future<void> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? profileImageUrl,
  }) async {
    Map<String, dynamic> updates = {};
    
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;
    
    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update(updates);
    }
  }
}