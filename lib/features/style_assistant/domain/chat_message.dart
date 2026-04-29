/// One bubble in the AI Stylist chat.
///
/// Kept tiny on purpose — the chat is ephemeral (we don't persist
/// the running transcript yet), so all we need is the role, the
/// text, and a timestamp for the "just now" / "2m ago" hint.
class ChatMessage {
  /// Whether this bubble is from the human user (right side, brand
  /// colour) or the AI stylist (left side, frosted/glass).
  final ChatRole role;
  final String text;
  final DateTime sentAt;

  /// `pending` is true while we're awaiting Gemini's reply. The
  /// chat UI uses it to render a typing-indicator bubble in place
  /// of the empty AI message that's about to be filled in.
  final bool pending;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.sentAt,
    this.pending = false,
  });

  ChatMessage copyWith({String? text, bool? pending}) => ChatMessage(
        role: role,
        text: text ?? this.text,
        sentAt: sentAt,
        pending: pending ?? this.pending,
      );

  bool get isUser => role == ChatRole.user;
  bool get isAi => role == ChatRole.ai;
}

enum ChatRole { user, ai }
