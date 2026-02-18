import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user.dart';
import '../config/api_config.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  String? _token;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _token != null;
  String? get token => _token;

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': email, // FastAPI OAuth2 uses 'username' field
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];

        // For now, create a mock user. Later, fetch user details from /me endpoint
        _currentUser = User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          username: email.split('@')[0],
          email: email,
          firstName: 'User',
          lastName: 'Name',
          phoneNumber: '',
        );

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<bool> register(
    String username,
    String email,
    String password,
    String firstName,
    String lastName,
    String phoneNumber,
  ) async {
    try {
      final payload = {
        'email': email,
        'nom': lastName,
        'prenom': firstName,
        'telephone': phoneNumber,
        'mot_de_passe': password,
        'role': 'GESTIONNAIRE',
      };

      debugPrint('Registration payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      debugPrint('Registration response status: ${response.statusCode}');
      debugPrint('Registration response body: ${response.body}');

      if (response.statusCode == 200) {
        // Auto-login after registration
        return await login(email, password);
      }
      return false;
    } catch (e) {
      debugPrint('Register error: $e');
      return false;
    }
  }

  Future<void> fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentUser = User.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch profile error: $e');
    }
  }

  Future<bool> updateProfile(User user, {String? password}) async {
    try {
      final Map<String, dynamic> body = user.toJson();
      if (password != null && password.isNotEmpty) {
        body['mot_de_passe'] = password;
      }
      // Remove ID as it shouldn't be sent for update usually, or depends on backend
      body.remove('id_utilisateur');
      body.remove('role'); // Role cannot be updated by user
      body.remove('statut');

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentUser = User.fromJson(data);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Update profile error: $e');
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/users/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        logout();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete account error: $e');
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _token = null;
    notifyListeners();
  }
}
