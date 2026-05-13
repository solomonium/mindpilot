import 'package:mindpilot/export.dart';
import 'package:dio/dio.dart';

class QuoteService {
  final Dio _dio = Dio();

  Future<Map<String, String>?> fetchRandomQuote() async {
    try {
      // zenquotes.io is a free API that doesn't require a key for basic random usage
      final response = await _dio.get('https://zenquotes.io/api/random');
      
      if (response.statusCode == 200 && response.data is List) {
        final data = response.data[0];
        return {
          'quote': data['q'] as String,
          'author': data['a'] as String,
        };
      }
    } catch (e) {
      safePrint('Quote Fetch Error: $e');
    }
    return null;
  }
}
