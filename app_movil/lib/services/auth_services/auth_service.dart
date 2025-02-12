import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final String baseUrl = 'https://tu-api-django.com/api';

  Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/token/'),
      body: {
        'username': username,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final token = json.decode(response.body)['token'];
      await _saveToken(token);
      return token;
    }
    throw Exception('Error en la autenticación');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}