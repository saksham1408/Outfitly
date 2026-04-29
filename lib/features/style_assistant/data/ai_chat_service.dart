import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../domain/style_profile.dart';

/// Wraps a Gemini [ChatSession] so the conversation maintains
/// context turn-after-turn, instead of re-prompting from scratch
/// on every send.
///
/// Why a class (not a free function): a chat session is stateful
/// — Gemini keeps the running history in [ChatSession] — so the
/// caller wants ONE long-lived instance per visible chat. We
/// build that instance once in [start], then route every user
/// message through [send] which delegates to `chat.sendMessage`.
///
/// The [StyleProfile] passed to [start] is folded into the
/// system instruction so Gemini "remembers" the user's traits
/// silently — the user never has to repeat themselves and the
/// profile never appears in the visible message list.
///
/// Failure posture: matches the rest of the app — any exception
/// path (missing key, network, API error) returns a friendly
/// fallback string rather than throwing, so the chat UI doesn't
/// have to handle errors inline. We do log to the debug console
/// so engineering can diagnose when it happens in development.
class AiChatService {
  // gemini-1.5-flash is the same model the existing
  // AiStylistService and VisionService use — fast, cheap, plenty
  // smart for conversational style advice. If we ever want
  // longer/more nuanced replies we can promote to -pro without
  // touching the call sites.
  static const String _modelName = 'gemini-1.5-flash';

  /// Friendly fallback line. Returned (instead of throwing) if
  /// the API key is missing, the network fails, or Gemini
  /// returns an empty body. The chat UI renders it as a normal
  /// AI message so the user gets *something* readable.
  static const String _fallbackReply =
      "I'm having trouble reaching the stylist right now. "
      "Try again in a moment — your profile is still saved.";

  ChatSession? _chat;
  bool _started = false;

  /// True once [start] has been called — even if the underlying
  /// model couldn't be created (no API key). The chat UI uses
  /// this to know whether it can call [send] yet.
  bool get isReady => _started;

  /// Build the system instruction that pre-loads the user's
  /// profile into Gemini's context. Public + static so unit
  /// tests can assert the exact wording without instantiating
  /// the service or hitting the network.
  ///
  /// Format follows the spec in the feature brief verbatim;
  /// only the empty-occasions case is softened so we don't
  /// emit "frequently attends []" if the user picked nothing.
  static String buildSystemInstruction(StyleProfile profile) {
    final body = profile.bodyType.trim().isEmpty
        ? 'unspecified'
        : profile.bodyType;
    final skin = profile.skinTone.trim().isEmpty
        ? 'unspecified'
        : profile.skinTone;

    final occasionsClause = profile.occasions.isEmpty
        ? 'occasions they have not specified yet'
        : profile.occasions.join(', ');

    return 'You are an elite personal stylist for Outfitly. '
        'The user you are talking to has a $body body type, '
        '$skin skin tone, and frequently attends $occasionsClause. '
        'Tailor all your fashion advice, fabric suggestions, and '
        'fit recommendations to flatter these specific traits. '
        'Be conversational, stylish, and concise.';
  }

  /// Spin up a fresh chat session loaded with the user's
  /// profile. Idempotent within an instance — calling it twice
  /// just rebuilds the session (useful if the profile changes
  /// after a quiz retake).
  void start(StyleProfile profile) {
    _started = true;

    final apiKey = dotenv.maybeGet('GEMINI_API_KEY');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_key_here') {
      debugPrint(
        'AiChatService: GEMINI_API_KEY missing — chat will fall back.',
      );
      _chat = null;
      return;
    }

    final model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      // Conversational replies — looser temperature than the
      // structured-JSON services, but capped tokens so we
      // don't get rambling 800-word essays.
      generationConfig: GenerationConfig(
        temperature: 0.85,
        maxOutputTokens: 600,
      ),
      // System instruction goes here (NOT as a regular user
      // turn) — that way it stays invisible to the message
      // list and Gemini treats it as ground truth instead of
      // user input it can be argued out of.
      systemInstruction: Content.system(buildSystemInstruction(profile)),
    );

    _chat = model.startChat();
  }

  /// Send a single user turn and await Gemini's reply. Always
  /// resolves with a string — if anything goes wrong the user
  /// sees [_fallbackReply], not an exception.
  Future<String> send(String userMessage) async {
    final chat = _chat;
    if (chat == null) return _fallbackReply;

    try {
      final response = await chat.sendMessage(Content.text(userMessage));
      final raw = response.text;
      if (raw == null || raw.trim().isEmpty) {
        debugPrint('AiChatService: empty response from Gemini.');
        return _fallbackReply;
      }
      return raw.trim();
    } catch (e, st) {
      debugPrint('AiChatService.send failed — $e\n$st');
      return _fallbackReply;
    }
  }

  /// Drop the underlying session so the next [start] gets a
  /// clean slate. Called when the user explicitly clears the
  /// chat or when the host widget disposes.
  void reset() {
    _chat = null;
    _started = false;
  }
}
