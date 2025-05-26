import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;
  String get _baseUrl => StorageService.apiUrl;

  // Getters
  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get error => _error;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('userData');
    final token = prefs.getString('token');

    if (userData != null && token != null) {
      _user = json.decode(userData);
      _token = token;

      // Try to restore Supabase session
      try {
        if (_supabase.auth.currentUser == null) {
          // If no session, try to sign in with stored credentials
          final email = _user?['email'] as String?;
          final password = prefs.getString('supabase_password');
          if (email != null && password != null) {
            await _supabase.auth.signInWithPassword(
              email: email,
              password: password,
            );
          }
        }
      } catch (e) {
        print('Error restoring Supabase session: $e');
      }

      notifyListeners();
    }
  }

  // Initialize auth state
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        _user = userData;

        // Try to restore Supabase session
        try {
          if (_supabase.auth.currentUser == null) {
            // If no session, try to sign in with stored credentials
            final email = userData['email'] as String?;
            final prefs = await SharedPreferences.getInstance();
            final password = prefs.getString('supabase_password');
            if (email != null && password != null) {
              await _supabase.auth.signInWithPassword(
                email: email,
                password: password,
              );
            }
          }
        } catch (e) {
          print('Error restoring Supabase session: $e');
        }

        // Set loading to false only after all async ops
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false; // Also set loading to false on error
      notifyListeners();
    }
  }

  // Register
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First create user in Supabase
      final supabaseResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (supabaseResponse.user == null) {
        throw Exception('Failed to create Supabase user');
      }

      // Then create user in your backend
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'role': role,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        _user = data['user'];
        _token = data['token'];

        // Store credentials for session restoration
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', json.encode(_user));
        await prefs.setString('token', _token!);
        await prefs.setString('supabase_password', password);
        return true;
      } else {
        // If backend registration fails, we should clean up the Supabase user
        // You might want to implement this cleanup in your backend
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First login to your backend
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // After successful backend login, sign in to Supabase
        final supabaseResponse = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (supabaseResponse.user == null) {
          throw Exception('Failed to authenticate with Supabase');
        }

        _user = data['user'];
        _token = data['token'];

        // Store credentials for session restoration
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', json.encode(_user));
        await prefs.setString('token', _token!);
        await prefs.setString('supabase_password',
            password); // Store password for session restoration

        return true;
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      print('Attempting to log out...');
      // Sign out from Supabase
      await _supabase.auth.signOut();
      print('Supabase sign out successful.');

      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userData');
      print('Removed userData from SharedPreferences.');
      await prefs.remove('token');
      print('Removed token from SharedPreferences.');
      await prefs.remove('supabase_password'); // Remove stored password
      print('Removed supabase_password from SharedPreferences.');

      _user = null;
      _token = null;
      print('AuthProvider state cleared.');
      notifyListeners();
      print('Listeners notified.');
    } catch (e) {
      _error = e.toString();
      print('Logout error: $_error');
      notifyListeners();
    }
  }

  // Update profile
  Future<bool> updateProfile({
    String? username,
    String? email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.updateProfile(
        username: username,
        email: email,
      );
      _user = response['user'];
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
