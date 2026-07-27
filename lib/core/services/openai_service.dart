import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AiCategoryResult {
  final String? category;
  final double confidence;

  const AiCategoryResult({this.category, this.confidence = 0.0});

  bool get isHighConfidence => confidence >= 0.7;
}

class OpenAIService {
  Future<({String? category, String? suggestion})> suggestCategory(
      String title) async {
    final result = await classifyWithCategories(title, []);
    return (
      category: result.category,
      suggestion: result.isHighConfidence
          ? null
          : 'Sin suficiente confianza para asignar automáticamente.',
    );
  }

  Future<AiCategoryResult> classifyWithCategories(
    String title,
    List<String> existingCategories,
  ) async {
    if (AppConfig.openaiApiKey == 'YOUR_OPENAI_API_KEY' ||
        AppConfig.openaiApiKey.isEmpty) {
      return const AiCategoryResult();
    }

    final categoryList = existingCategories.isNotEmpty
        ? existingCategories.map((c) => '"$c"').join(', ')
        : 'Tecnología, Música, Deportes, Cocina, Comedia, Tutoriales, '
            'Viajes, Fitness, Moda, Educación, Motivación, '
            'Entretenimiento, Noticias, Ciencia, Arte';

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
                  'Eres un clasificador de videos por categoría. '
                      'Debes elegir la categoría más adecuada entre las disponibles. '
                      'Responde EXCLUSIVAMENTE en formato JSON con estos campos: '
                      '"category": la categoría elegida (debe ser exactamente una de '
                      'las disponibles, o "General" si no aplica ninguna), '
                      '"confidence": un número entre 0.0 y 1.0 que indica tu nivel '
                      'de confianza en la clasificación. '
                      'Si el título no da suficiente información, usa "General" con '
                      'confidence bajo (0.3 o menos). '
                      'Categorías disponibles: $categoryList.',
            },
            {
              'role': 'user',
              'content': 'Clasifica este video: "$title"',
            },
          ],
          'temperature': 0.2,
          'max_tokens': 80,
        }),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String?;

        if (content != null) {
          final cleaned = content
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();

          final parsed = json.decode(cleaned) as Map<String, dynamic>;
          final category = parsed['category'] as String?;
          final confidence = (parsed['confidence'] as num?)?.toDouble() ?? 0.0;

          if (category == null || category.isEmpty || category == 'General') {
            return AiCategoryResult(confidence: confidence);
          }

          return AiCategoryResult(category: category, confidence: confidence);
        }
      }
    } catch (_) {}

    return const AiCategoryResult();
  }
}
