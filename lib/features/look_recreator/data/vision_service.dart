import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/recreated_design.dart';

/// Gemini Vision wrapper that reverse-engineers a garment from a photo.
///
/// Mirrors the architecture of [AiStylistService] (same fallback
/// posture, same JSON-only response config) so the customer app has
/// one consistent shape for "ask Gemini something". The single public
/// method, [analyzeOutfit], always resolves: any failure path yields
/// [RecreatedDesign.fallback] and logs the cause to the debug console.
///
/// Why `gemini-1.5-flash`: it's faster and ~10× cheaper than -pro for
/// vision tasks, and the response we want is short structured JSON,
/// not creative prose. If the image is genuinely complex (multi-piece
/// looks, tricky drapery) we can promote to -pro later — the call site
/// won't have to change.
class VisionService {
  static const String _modelName = 'gemini-1.5-flash';

  GenerativeModel? _buildModel() {
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_key_here') {
      debugPrint('VisionService: GEMINI_API_KEY missing — using fallback.');
      return null;
    }
    return GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        // Slightly cooler than the stylist service — we want grounded
        // garment analysis, not creative riffs.
        temperature: 0.4,
        maxOutputTokens: 512,
      ),
    );
  }

  /// Reverse-engineer the outfit in [image] under the user's [budget]
  /// and [occasion] constraints. Always resolves; error paths yield
  /// [RecreatedDesign.fallback].
  ///
  /// [budget] is one of `'Under ₹2000'`, `'Under ₹5000'`, `'No Limit'`.
  /// [occasion] is one of `'Make it Wedding-Appropriate'`,
  /// `'Make it Casual'`, `'Exact Match'`. The prompt accepts these
  /// strings verbatim — the model handles them as natural language.
  Future<RecreatedDesign> analyzeOutfit(
    File image,
    String budget,
    String occasion,
  ) async {
    final model = _buildModel();
    if (model == null) return RecreatedDesign.fallback;

    final bytes = await image.readAsBytes();
    final mimeType = _guessMimeType(image.path);

    // System prompt mandated by the AI Look Recreator spec. The
    // {budget} / {occasion} interpolation is the only mutation —
    // every other token is verbatim.
    final prompt =
        'Act as a master tailor. Analyze the clothing in the attached image. '
        'The user\'s budget is $budget and they want to tweak the look to be '
        '$occasion. Based on these constraints, identify the garment details '
        'to recreate this look. You MUST return ONLY a raw, valid JSON object '
        'with the following keys: \'fabric_type\' (suggested local fabric '
        'matching the budget), \'collar_style\', \'sleeve_design\', '
        '\'fit_type\', \'estimated_price\' (a single integer in INR based on '
        'the budget constraint), and \'stylist_notes\' (a brief explanation '
        'of your choices).';

    try {
      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, bytes),
        ]),
      ]);

      final raw = response.text;
      if (raw == null || raw.isEmpty) {
        debugPrint('VisionService: empty response from Gemini.');
        return RecreatedDesign.fallback;
      }

      final decoded = _decodeJson(raw);
      if (decoded == null) {
        debugPrint(
          'VisionService: could not parse Gemini response as JSON:\n$raw',
        );
        return RecreatedDesign.fallback;
      }
      return RecreatedDesign.fromJson(decoded);
    } catch (e, st) {
      debugPrint('VisionService: Gemini call failed — $e\n$st');
      return RecreatedDesign.fallback;
    }
  }

  /// Tolerant JSON decoder. `responseMimeType: application/json` is
  /// usually enough, but Gemini occasionally still wraps output in
  /// triple-backtick fences — strip them before decoding.
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

  /// `image_picker` returns paths from the system camera roll which
  /// are typically `.jpg` or `.heic`. Map them to MIME types Gemini
  /// understands; default to `image/jpeg` for unknown extensions
  /// since that's the safest re-encode target on iOS.
  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }
}
