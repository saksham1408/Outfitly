/// Captured by the Style Quiz and silently injected into the
/// Gemini chat session as a system instruction. Three signals
/// only — body type / skin tone / typical occasions — chosen
/// because they're (a) easy for a non-fashion-literate user to
/// answer and (b) the levers a real stylist asks about first
/// when sizing up a new client.
///
/// Stored 1:1 with `auth.users` in `public.style_profiles`. PK
/// is `user_id`, so writes always upsert in place — there is
/// exactly one StyleProfile per user, evergreen, retake-friendly.
class StyleProfile {
  final String userId;
  final String bodyType;
  final String skinTone;
  final List<String> occasions;

  const StyleProfile({
    required this.userId,
    required this.bodyType,
    required this.skinTone,
    required this.occasions,
  });

  /// Tolerant decoder. We default `occasions` to `[]` rather than
  /// throwing because a row with no occasions still represents a
  /// valid (if minimally informed) profile — the chat just won't
  /// have an "occasions" sentence in its system instruction.
  factory StyleProfile.fromJson(Map<String, dynamic> json) {
    final occRaw = json['occasions'];
    final occasions = occRaw is List
        ? occRaw.map((e) => e.toString()).toList()
        : <String>[];

    return StyleProfile(
      userId: json['user_id']?.toString() ?? '',
      bodyType: json['body_type']?.toString() ?? '',
      skinTone: json['skin_tone']?.toString() ?? '',
      occasions: occasions,
    );
  }

  /// `user_id` is intentionally omitted — the auth context on the
  /// Postgres side fills it in for us via RLS, and including it
  /// in the upsert payload would require the client to know its
  /// own UUID before every write.
  Map<String, dynamic> toUpsertJson() => {
        'user_id': userId,
        'body_type': bodyType,
        'skin_tone': skinTone,
        'occasions': occasions,
      };

  StyleProfile copyWith({
    String? bodyType,
    String? skinTone,
    List<String>? occasions,
  }) {
    return StyleProfile(
      userId: userId,
      bodyType: bodyType ?? this.bodyType,
      skinTone: skinTone ?? this.skinTone,
      occasions: occasions ?? this.occasions,
    );
  }
}
