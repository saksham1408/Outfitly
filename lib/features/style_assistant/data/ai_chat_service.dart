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
  // gemini-2.5-flash-lite is what we actually want here:
  //
  //   1. It has *real* free-tier quota — `gemini-2.0-flash` is
  //      paid-tier-only on newer projects (limit: 0 in the free
  //      bucket), and `gemini-2.5-flash` works but routes a huge
  //      slice of every reply through internal "thinking"
  //      tokens, silently truncating mid-sentence under any
  //      sane maxOutputTokens.
  //   2. It's Google's lightweight chat-tuned variant — no
  //      thinking overhead, lowest latency, the full token
  //      budget streams straight into visible text.
  //
  // We measured `thoughtsTokenCount: 0` and `finishReason: STOP`
  // on a real 450-token stylist prompt during integration. This
  // is the right model for conversational style advice. Promote
  // to `gemini-2.5-pro` only if reply quality measurably suffers.
  static const String _modelName = 'gemini-2.5-flash-lite';

  /// Friendly fallback line. Returned (instead of throwing) if
  /// the API key is missing, the network fails, or Gemini
  /// returns an empty body. The chat UI renders it as a normal
  /// AI message so the user gets *something* readable.
  static const String _fallbackReply =
      "I'm having trouble reaching the stylist right now. "
      "Try again in a moment — your profile is still saved.";

  ChatSession? _chat;
  bool _started = false;

  /// Cached so [send] can rebuild the chat session inline if a
  /// turn fails — without forcing the UI layer to know about the
  /// `start(profile)` ↔ `send(message)` lifecycle ordering.
  StyleProfile? _profile;

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
    _profile = profile;
    _chat = _buildChat(profile);
  }

  /// Internal: builds (or null-returns) a fresh [ChatSession].
  /// Pulled out so [send]'s self-heal path can reuse it without
  /// duplicating the apiKey/GenerationConfig wiring.
  ChatSession? _buildChat(StyleProfile profile) {
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_key_here') {
      debugPrint(
        'AiChatService: GEMINI_API_KEY missing — chat will fall back.',
      );
      return null;
    }

    final model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      // Conversational replies — looser temperature than the
      // structured-JSON services. 1024 tokens is generous for a
      // stylist's paragraph-of-advice without inviting essays;
      // crucially it leaves enough headroom that a reply can't
      // get truncated mid-sentence on a slightly-longer answer.
      generationConfig: GenerationConfig(
        temperature: 0.85,
        maxOutputTokens: 1024,
      ),
      // System instruction goes here (NOT as a regular user
      // turn) — that way it stays invisible to the message
      // list and Gemini treats it as ground truth instead of
      // user input it can be argued out of.
      systemInstruction: Content.system(buildSystemInstruction(profile)),
    );

    return model.startChat();
  }

  /// Send a single user turn and await Gemini's reply. Always
  /// resolves with a string — if anything goes wrong the user
  /// sees [_fallbackReply], not an exception.
  ///
  /// Self-heals on failure: when [ChatSession.sendMessage] throws,
  /// the running [_chat] often has a half-written model turn
  /// pinned in its history (e.g. after a `MAX_TOKENS` truncation
  /// or transient network blip), and every subsequent call will
  /// keep failing on that same poisoned turn. We rebuild the
  /// session from the cached [_profile] before returning so the
  /// user's *next* message goes through a clean chat instance.
  /// They lose the prior conversational context — fair price for
  /// the chat staying alive instead of bricking on every turn.
  Future<String> send(String userMessage) async {
    final chat = _chat;
    if (chat == null) return _fallbackReply;

    try {
      final response = await chat.sendMessage(Content.text(userMessage));
      final raw = response.text;
      if (raw == null || raw.trim().isEmpty) {
        debugPrint('AiChatService: empty response from Gemini.');
        // Empty body is usually a finishReason: SAFETY or
        // OTHER — also worth recycling the session so we don't
        // fire the same dead turn again on retry.
        _recycleChat();
        return _fallbackReply;
      }
      return raw.trim();
    } catch (e, st) {
      debugPrint('AiChatService.send failed — $e\n$st');
      _recycleChat();
      return _fallbackReply;
    }
  }

  /// Tear down the current [ChatSession] and stand up a fresh
  /// one from the same profile. No-op if we don't have a profile
  /// cached (which only happens before [start] has been called).
  void _recycleChat() {
    final profile = _profile;
    if (profile == null) {
      _chat = null;
      return;
    }
    _chat = _buildChat(profile);
  }

  /// Drop the underlying session so the next [start] gets a
  /// clean slate. Called when the user explicitly clears the
  /// chat or when the host widget disposes.
  void reset() {
    _chat = null;
    _started = false;
    _profile = null;
  }
}
