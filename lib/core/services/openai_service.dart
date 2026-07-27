import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class OpenAIService {
  Future<({String? category, String? suggestion})> suggestCategory(
      String title) async {
    if (AppConfig.openaiApiKey == 'YOUR_OPENAI_API_KEY' ||
        AppConfig.openaiApiKey.isEmpty) {
      return (category: null, suggestion: null);
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.openaiApiKey}',
        },
        body: json.encode({
          'model': AppConfig.openaiModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Eres un asistente que categoriza enlaces de videos. '
                      'Responde SOLO en formato JSON con dos campos: '
                      '"category" con el nombre de una categoría existente adecuada '
                      'y "suggestion" con una breve explicación de 1 frase. '
                      'Categorías sugeridas: Tecnología, Música, Deportes, Cocina, '
                      'Comedia, Tutoriales, Viajes, Fitness, Moda, Educación, Motivación, '
                      'Entretenimiento, Noticias, Ciencia, Arte. '
                      'Si ninguna aplica bien, sugiere una nueva categoría creativa.',
            },
            {
              'role': 'user',
              'content': 'Categoriza este video: "$title"',
            },
          ],
          'temperature': 0.3,
          'max_tokens': 100,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String?;

        if (content != null) {
          final cleaned = content
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();

          final parsed = json.decode(cleaned) as Map<String, dynamic>;
          return (
            category: parsed['category'] as String?,
            suggestion: parsed['suggestion'] as String?,
          );
        }
      }
    } catch (_) {}

    return (category: null, suggestion: null);
  }
}
