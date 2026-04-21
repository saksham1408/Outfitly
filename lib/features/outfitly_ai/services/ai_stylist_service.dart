import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/outfit_recommendation.dart';

/// Wraps the Google Gemini API to turn a user's mood + event + weather
/// into a structured [OutfitRecommendation]. The service is defensive
/// by design: any failure path (missing key, network blip, malformed
/// JSON) resolves to [OutfitRecommendation.fallback] so the UI never
/// has to handle exceptions.
class AiStylistService {
  static const String _modelName = 'gemini-1.5-flash';

  /// Response MIME type `application/json` is strongly preferred by
  /// the API to force well-formed JSON without backticks or prose.
  GenerativeModel? _buildModel() {
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_key_here') {
      debugPrint('AiStylistService: GEMINI_API_KEY missing — using fallback.');
      return null;
    }
    return GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.9,
        maxOutputTokens: 512,
      ),
    );
  }

  /// Generates an outfit recommendation for the given context. Always
  /// resolves — errors are logged and swallowed into the fallback.
  Future<OutfitRecommendation> generateOutfit(
    String mood,
    String event,
    String weather,
  ) async {
    final model = _buildModel();
    if (model == null) return OutfitRecommendation.fallback;

    final prompt =
        "You are an elite, high-end fashion stylist for the app Outfitly. "
        "The user feels $mood, the weather is $weather, and they are going to $event. "
        "Suggest a complete outfit. You MUST return ONLY a raw, valid JSON object "
        "with the following exact keys: 'top', 'bottom', 'shoes', 'accessories', "
        "and 'reasoning'. Do not include markdown formatting or backticks.";

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final raw = response.text;
      if (raw == null || raw.isEmpty) {
        debugPrint('AiStylistService: empty response from Gemini.');
        return OutfitRecommendation.fallback;
      }

      final decoded = _decodeJson(raw);
      if (decoded == null) {
        debugPrint(
          'AiStylistService: could not parse Gemini response as JSON:\n$raw',
        );
        return OutfitRecommendation.fallback;
      }

      return OutfitRecommendation.fromJson(decoded);
    } catch (e, st) {
      debugPrint('AiStylistService: Gemini call failed — $e\n$st');
      return OutfitRecommendation.fallback;
    }
  }

  /// Tolerant JSON decoder. Even with `responseMimeType = application/json`,
  /// some models occasionally wrap output in ```json fences — strip them
  /// before decoding to keep the happy path hands-free.
  Map<String, dynamic>? _decodeJson(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?'), '').trim();
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    }
    try {
      final obj = jsonDecode(cleaned);
      if (obj is Map<String, dynamic>) return obj;
      return null;
    } catch (_) {
      return null;
    }
  }
}
