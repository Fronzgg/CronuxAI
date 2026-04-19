import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Замени на свой Render URL после деплоя
  static const String baseUrl = 'https://cronuxai.onrender.com/api';
  // Для локальной разработки:
  // static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android эмулятор
  // static const String baseUrl = 'http://192.168.x.x:3000/api'; // реальный телефон

  static Future<String> chat({
    required String message,
    required String model,
    required List<Map<String, String>> history,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'model': model, 'history': history}),
    ).timeout(const Duration(seconds: 60));

    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return data['response'] as String;
  }

  static Future<String> search(String query) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return '';
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['results'] as String? ?? '';
    } catch (_) { return ''; }
  }
}
