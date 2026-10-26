import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/player_model.dart';

class FplApiService {
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  String baseUrl;

  FplApiService({String? customBaseUrl})
      : baseUrl = customBaseUrl ?? defaultBaseUrl;

  Future<GameweekOverview> fetchOverview() async {
    final uri = Uri.parse('$baseUrl/api/overview');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return GameweekOverview.fromJson(json);
    } else {
      throw Exception('Kunne ikke laste oversikt: ${response.statusCode}');
    }
  }

  Future<List<PlayerRecommendation>> fetchBestBuys({
    String? position,
    double? maxPrice,
    int limit = 20,
    int nextGameweeks = 3,
    String sortBy = 'expected_points',
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'next_gameweeks': nextGameweeks.toString(),
      'sort_by': sortBy,
    };

    if (position != null && position != 'ALL') {
      queryParams['position'] = position;
    }

    if (maxPrice != null && maxPrice < 15.0) {
      queryParams['max_price'] = maxPrice.toStringAsFixed(1);
    }

    final uri = Uri.parse('$baseUrl/api/best-buys').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List results = data['results'] ?? [];
      return results.map((item) => PlayerRecommendation.fromJson(item)).toList();
    } else {
      throw Exception('Kunne ikke laste FPL spillere: ${response.statusCode}');
    }
  }

  Future<List<PlayerRecommendation>> fetchJokers({
    double maxPrice = 6.5,
    double maxOwnership = 20.0,
    int limit = 1,
    int nextGameweeks = 3,
  }) async {
    final queryParams = <String, String>{
      'max_price': maxPrice.toStringAsFixed(1),
      'max_ownership': maxOwnership.toStringAsFixed(1),
      'limit': limit.toString(),
      'next_gameweeks': nextGameweeks.toString(),
    };

    final uri = Uri.parse('$baseUrl/api/jokers').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List results = data['results'] ?? [];
      return results.map((item) => PlayerRecommendation.fromJson(item)).toList();
    } else {
      throw Exception('Kunne ikke laste Joker-spillere: ${response.statusCode}');
    }
  }
}
