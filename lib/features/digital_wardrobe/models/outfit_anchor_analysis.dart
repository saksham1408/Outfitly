import 'package:flutter/foundation.dart';

/// Structured response from Gemini Vision when a user uploads a single
/// garment (the "anchor" piece) and asks the stylist to build outfits
/// around it.
///
/// The shape mirrors the JSON schema pinned in [OutfitDesignerService]'s
/// prompt so a straightforward `fromJson` is enough to hydrate.
@immutable
class OutfitAnchorAnalysis {
  /// What Gemini detected in the uploaded photo.
  final AnchorPiece anchor;

  /// Three outfit ideas that pair with the anchor. May be fewer than 3
  /// if the model returns a short list — the UI degrades gracefully.
  final List<OutfitIdea> outfits;

  const OutfitAnchorAnalysis({
    required this.anchor,
    required this.outfits,
  });
}

/// The garment in the uploaded image, as identified by Gemini.
@immutable
class AnchorPiece {
  /// Coarse category — "Top", "Bottom", "Shoes", "Jacket", "Dress", etc.
  /// Free-form string because Gemini occasionally coins its own labels
  /// (e.g. "Blazer") and we'd rather surface that than drop it.
  final String type;

  /// Dominant color the model sees ("Navy", "Cream", "Forest Green"…).
  final String color;

  /// Style family — Casual / Smart-Casual / Formal / Streetwear / etc.
  final String style;

  const AnchorPiece({
    required this.type,
    required this.color,
    required this.style,
  });

  factory AnchorPiece.fromJson(Map<String, dynamic> j) => AnchorPiece(
        type: _nonEmpty(j['type']) ?? 'Item',
        color: _nonEmpty(j['color']) ?? 'Neutral',
        style: _nonEmpty(j['style']) ?? 'Casual',
      );

  static String? _nonEmpty(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }
}

/// One complete outfit idea. Every slot ([top], [bottom], [shoes]) is
/// optional so the model can describe, say, a dress-only look without
/// awkwardly stuffing something into [bottom].
@immutable
class OutfitIdea {
  /// Short card headline — "Smart Office", "Weekend Brunch", …
  final String title;

  /// Where/when to wear it — "Monday meeting", "Dinner date".
  final String occasion;

  final String? top;
  final String? bottom;
  final String? shoes;
  final List<String> accessories;

  /// Why this combination works. Shown as a subtitle on the card.
  final String reasoning;

  /// ARGB ints (0xFFRRGGBB) representing the outfit's color palette.
  /// Drives the little color-swatch row on each card.
  final List<int> paletteColors;

  const OutfitIdea({
    required this.title,
    required this.occasion,
    this.top,
    this.bottom,
    this.shoes,
    this.accessories = const [],
    required this.reasoning,
    this.paletteColors = const [],
  });

  factory OutfitIdea.fromJson(Map<String, dynamic> j) {
    final pairing = j['pairing'] as Map<String, dynamic>? ?? const {};

    final accs = <String>[];
    final rawAccs = pairing['accessories'];
    if (rawAccs is List) {
      for (final a in rawAccs) {
        if (a is String && a.trim().isNotEmpty) accs.add(a.trim());
      }
    }

    final paletteInts = <int>[];
    final paletteRaw = j['paletteHex'];
    if (paletteRaw is List) {
      for (final hex in paletteRaw) {
        if (hex is String) {
          final parsed = _hexToArgb(hex);
          if (parsed != null) paletteInts.add(parsed);
        }
      }
    }

    return OutfitIdea(
      title: _nonEmpty(j['title']) ?? 'Outfit',
      occasion: _nonEmpty(j['occasion']) ?? '',
      top: _nonEmpty(pairing['top']),
      bottom: _nonEmpty(pairing['bottom']),
      shoes: _nonEmpty(pairing['shoes']),
      accessories: accs,
      reasoning: _nonEmpty(j['reasoning']) ?? '',
      paletteColors: paletteInts,
    );
  }

  static String? _nonEmpty(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  /// `#aabbcc` or `aabbcc` → 0xFFaabbcc. Returns null on malformed input
  /// so bad hex doesn't crash the whole response.
  static int? _hexToArgb(String hex) {
    var cleaned = hex.trim();
    if (cleaned.startsWith('#')) cleaned = cleaned.substring(1);
    if (cleaned.length != 6) return null;
    final v = int.tryParse(cleaned, radix: 16);
    if (v == null) return null;
    return 0xFF000000 | v;
  }
}
