import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace with your actual Cloudflare Worker URL
  static const String baseUrl = 'https://gse-stock-api.gabriel-dahaman.workers.dev';

  Future<List<Map<String, dynamic>>> getStocks() async {
    final response = await http.get(Uri.parse('$baseUrl/api/stocks'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load stocks');
  }

  Future<Map<String, dynamic>> getStock(String symbol) async {
    final response = await http.get(Uri.parse('$baseUrl/api/stocks/$symbol'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load stock');
  }

  Future<List<Map<String, dynamic>>> getHistory(String symbol, String period) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/stocks/$symbol/history?period=$period'),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load history');
  }

  Future<Map<String, dynamic>> getAIInsight(String symbol) async {
    final response = await http.get(Uri.parse('$baseUrl/api/stocks/$symbol/ai'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load AI insight');
  }

  Future<void> createAlert({
    required int userId,
    required String symbol,
    required String alertType,
    required double targetValue,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/alerts'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'symbol': symbol,
        'alert_type': alertType,
        'target_value': targetValue,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create alert');
    }
  }

  Future<List<Map<String, dynamic>>> getAlerts(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/alerts?user_id=$userId'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load alerts');
  }

  Future<void> deleteAlert(int alertId) async {
    await http.delete(Uri.parse('$baseUrl/api/alerts/$alertId'));
  }
}