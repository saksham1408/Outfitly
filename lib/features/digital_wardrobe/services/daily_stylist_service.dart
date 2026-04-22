import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/wardrobe_item.dart';

/// The structured outfit produced by [DailyStylistService] — the Gemini
/// response JSON rehydrated into the user's actual [WardrobeItem]s so
/// the dashboard can render the real photos in a Mix & Match stack.
@immutable
class DailyOutfit {
  final WardrobeItem? top;
  final WardrobeItem? bottom;
  final WardrobeItem? shoes;
  final List<WardrobeItem> accessories;
  final String reasoning;

  const DailyOutfit({
    this.top,
    this.bottom,
    this.shoes,
    this.accessories = const [],
    required this.reasoning,
  });

  /// Fallback shown when the API key is missing or Gemini rejects the
  /// call. Picks the newest item in each category so the user still
  /// sees *something* on screen — better UX than an error state for a
  /// "surprise me" feature.
  factory DailyOutfit.fallback(List<WardrobeItem> inventory) {
    WardrobeItem? firstOf(String cat) {
      for (final i in inventory) {
        if (i.category == cat) return i;
      }
      return null;
    }

    return DailyOutfit(
      top: firstOf('Top'),
      bottom: firstOf('Bottom'),
      shoes: firstOf('Shoes'),
      accessories: [
        for (final i in inventory)
          if (i.category == 'Accessory') i,
      ].take(1).toList(),
      reasoning:
          'Your AI stylist is warming up — here\'s a quick pick from '
          'your most recent uploads while we reconnect.',
    );
  }

  bool get isEmpty =>
      top == null && bottom == null && shoes == null && accessories.isEmpty;
}

/// Wraps the Gemini API to turn the user's own wardrobe + today's
/// context (weather, occasion) into a [DailyOutfit].
///
/// Design goals:
///   * Deterministic shape — the prompt pins the response to a known
///     JSON schema with `id` pointers so we can match back to the
///     original [WardrobeItem] objects.
///   * Never throws — a missing API key or a malformed response both
///     resolve to [DailyOutfit.fallback]. The UI should show the
///     fallback without special-casing.
///   * Low temperature (0.7) so the stylist picks sensible pairings,
///     but not so low that it always returns the same 3 items.
class DailyStylistService {
  static const String _modelName = 'gemini-1.5-flash';

  GenerativeModel? _buildModel() {
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_key_here') {
      debugPrint(
        'DailyStylistService: GEMINI_API_KEY missing — using fallback.',
      );
      return null;
    }
    return GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        // Strongly request raw JSON — avoids the ```json fencing that
        // older Gemini builds sometimes emit.
        responseMimeType: 'application/json',
        temperature: 0.7,
        maxOutputTokens: 512,
      ),
    );
  }

  /// Build an outfit from `userClothes` that suits `weather` + `event`.
  ///
  /// `userClothes` is the full wardrobe snapshot; the prompt tells
  /// Gemini it MUST only pick from this list. The returned JSON is
  /// expected to contain id pointers, which we resolve here.
  Future<DailyOutfit> generateDailyOutfitFromWardrobe({
    required List<WardrobeItem> userClothes,
    required String weather,
    required String event,
  }) async {
    if (userClothes.isEmpty) {
      return const DailyOutfit(
        reasoning: 'Add a few items to your digital closet first — '
            'the stylist needs clothes to work with.',
      );
    }

    final model = _buildModel();
    if (model == null) return DailyOutfit.fallback(userClothes);

    final inventoryJson =
        jsonEncode(userClothes.map((i) => i.toStylistJson()).toList());

    final prompt = '''
You are a personal stylist. The weather is $weather and the event is $event.
Here is the user's wardrobe inventory in JSON format: $inventoryJson.
Build the perfect outfit using ONLY the items provided in this inventory.

Return a single raw JSON object with EXACTLY these keys:
  "top":         the id string of the chosen Top      (or null if none fits)
  "bottom":      the id string of the chosen Bottom   (or null if none fits)
  "shoes":       the id string of the chosen Shoes    (or null if none fits)
  "accessories": an array of 0–2 id strings for Accessory items
  "reasoning":   a short sentence explaining why this combination works,
                 referencing the weather and event.

Do not include markdown formatting, backticks, or commentary. Output the
JSON object and nothing else. Use only ids that appear in the inventory.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final raw = response.text;
      if (raw == null || raw.isEmpty) {
        debugPrint('DailyStylistService: empty Gemini response.');
        return DailyOutfit.fallback(userClothes);
      }

      final decoded = _decodeJson(raw);
      if (decoded == null) {
        debugPrint('DailyStylistService: non-JSON response:\n$raw');
        return DailyOutfit.fallback(userClothes);
      }

      return _rehydrate(decoded, userClothes);
    } catch (e, st) {
      debugPrint('DailyStylistService: Gemini call failed — $e\n$st');
      return DailyOutfit.fallback(userClothes);
    }
  }

  // ── internals ──────────────────────────────────────────────

  DailyOutfit _rehydrate(
    Map<String, dynamic> body,
    List<WardrobeItem> inventory,
  ) {
    final byId = {for (final i in inventory) i.id: i};

    WardrobeItem? pick(dynamic raw) {
      if (raw is String && raw.isNotEmpty) return byId[raw];
      return null;
    }

    final accessoriesRaw = body['accessories'];
    final accessories = <WardrobeItem>[];
    if (accessoriesRaw is List) {
      for (final a in accessoriesRaw) {
        final item = pick(a);
        if (item != null) accessories.add(item);
      }
    }

    final reasoning = (body['reasoning'] as String?)?.trim() ??
        'A balanced pick from your closet for the day.';

    return DailyOutfit(
      top: pick(body['top']),
      bottom: pick(body['bottom']),
      shoes: pick(body['shoes']),
      accessories: accessories,
      reasoning: reasoning,
    );
  }

  /// Tolerant JSON decoder — strips ```json fences if the model
  /// slipped and emitted them despite the response_mime_type hint.
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
