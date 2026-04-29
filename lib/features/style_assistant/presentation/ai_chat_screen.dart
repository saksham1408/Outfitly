import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/ai_chat_service.dart';
import '../domain/chat_message.dart';
import '../domain/style_profile.dart';

/// Conversational AI Stylist tab. Uses a Gemini [ChatSession]
/// (via [AiChatService]) so the conversation accumulates context
/// instead of resetting between turns.
///
/// Layout:
///   • AppBar with the brand wordmark + a "retake quiz" affordance.
///   • Scrolling [ListView] of message bubbles (user right, AI left).
///   • Bottom composer:
///       – horizontally-scrolling row of "spark idea" chips
///       – frosted-glass text field + send button
///
/// We do NOT persist messages between launches — the chat resets
/// every time the tab mounts. This is a deliberate v1 trade-off:
/// keeping the UI ephemeral lets us avoid wiring a chat-history
/// table + RLS policy, and the system instruction (built from the
/// user's permanent [StyleProfile]) means a fresh session is still
/// personalised on the very first message.
class AiChatScreen extends StatefulWidget {
  /// The user's style answers, fetched by the gate that hosts this
  /// screen. Required, not nullable — without a profile we'd be
  /// rendering a generic chat bot, which defeats the point.
  final StyleProfile profile;

  /// Called when the user taps the "Retake quiz" action. The host
  /// (the AI tab gate) flips back to the quiz screen.
  final VoidCallback? onRetakeQuiz;

  const AiChatScreen({
    super.key,
    required this.profile,
    this.onRetakeQuiz,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _service = AiChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _sending = false;

  // Quick-action chips that sit above the text field. These are
  // pre-filled prompts a user can tap to skip typing — same role
  // as the suggestion chips ChatGPT shows on a fresh thread.
  static const _quickPrompts = <String>[
    'Outfit for a Beach Wedding',
    'Recreate a Ranveer Singh wedding look',
    'What suits my body type for office?',
    'Festive look on a tight budget',
    'Colours that flatter my skin tone',
  ];

  @override
  void initState() {
    super.initState();
    _service.start(widget.profile);
    _seedGreeting();
  }

  /// First AI message in the thread — written client-side so the
  /// chat never opens to an empty void. Doesn't burn a Gemini
  /// turn; the actual model only kicks in once the user sends
  /// their first message.
  void _seedGreeting() {
    _messages.add(
      ChatMessage(
        role: ChatRole.ai,
        text:
            "Hi — I'm your Outfitly stylist. I've already got your "
            "body type, skin tone, and the events you dress for, so "
            "go ahead and describe a look or an occasion and I'll "
            "tailor advice just for you.",
        sentAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    _service.reset();
    super.dispose();
  }

  Future<void> _send([String? overrideText]) async {
    final raw = (overrideText ?? _input.text).trim();
    if (raw.isEmpty || _sending) return;

    final userMsg = ChatMessage(
      role: ChatRole.user,
      text: raw,
      sentAt: DateTime.now(),
    );

    // Optimistic update: drop the user's bubble in immediately +
    // a placeholder AI bubble that says "typing…" while we wait.
    final placeholder = ChatMessage(
      role: ChatRole.ai,
      text: '',
      sentAt: DateTime.now(),
      pending: true,
    );

    setState(() {
      _messages.add(userMsg);
      _messages.add(placeholder);
      _sending = true;
      _input.clear();
    });
    _scrollToBottom();

    final reply = await _service.send(raw);
    if (!mounted) return;

    setState(() {
      // Replace the trailing placeholder in place — index is
      // guaranteed because we just appended it in this same
      // setState. Safer than removing+adding because it stops
      // the list scrolling jumping.
      final lastIndex = _messages.length - 1;
      _messages[lastIndex] = _messages[lastIndex]
          .copyWith(text: reply, pending: false);
      _sending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    // Defer to the next frame so the new bubble is laid out
    // before we measure max scrollExtent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.lg,
                AppSpacing.base,
                AppSpacing.base,
              ),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _MessageBubble(message: m),
                );
              },
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleSpacing: AppSpacing.base,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Style Assistant',
                style: GoogleFonts.newsreader(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: AppColors.primary,
                  height: 1.05,
                ),
              ),
              Text(
                'Personalised by your profile',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Retake style quiz',
          icon: const Icon(
            Icons.tune_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          onPressed: widget.onRetakeQuiz,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.sm,
          AppSpacing.base,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Quick-action chips ──
            // Horizontal scroll so we can pack 5+ ideas into a
            // narrow phone width without wrapping into a wall of
            // chips that pushes the text field down.
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) =>
                    _QuickPromptChip(
                  label: _quickPrompts[i],
                  enabled: !_sending,
                  onTap: () => _send(_quickPrompts[i]),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Text field + send button ──
            _ComposerField(
              controller: _input,
              focusNode: _focus,
              sending: _sending,
              onSend: () => _send(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          _AiAvatar(),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.border.withAlpha(120)),
                boxShadow: isUser
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: message.pending
                  ? const _TypingDots()
                  : Text(
                      message.text,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        height: 1.5,
                        color: isUser
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AiAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 15,
      ),
    );
  }
}

/// Three pulsing dots used inside the placeholder AI bubble while
/// we're awaiting Gemini's reply. Cheap to run — one looping
/// AnimationController, dots staggered by phase offset.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot by 1/3 of the cycle so they pulse
            // in sequence rather than all at once.
            final phase = (_ctrl.value + i / 3) % 1.0;
            // Map phase → opacity via a half-sine so the dot
            // fades in and out smoothly.
            final intensity =
                (0.3 + 0.7 * (0.5 + 0.5 * _sin(phase * 6.2832))).clamp(
              0.3,
              1.0,
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.textTertiary
                      .withAlpha((255 * intensity).round()),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // Small inline sine to avoid importing dart:math just for this.
  // Accuracy doesn't matter at all — it's a visual pulse.
  double _sin(double x) {
    // Pretty good Taylor approximation for the |x| < 2π range
    // we care about.
    final t = x;
    final t2 = t * t;
    return t - (t * t2) / 6 + (t * t2 * t2) / 120;
  }
}

// ── Composer ───────────────────────────────────────────────────

class _ComposerField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  const _ComposerField({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: BackdropFilter(
        // Frosted-glass treatment on the composer matches the
        // "soft surface" we use for AI bubbles, so the input
        // reads as part of the same conversation panel rather
        // than a separate UI component.
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withAlpha(220),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: AppColors.border.withAlpha(120),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                    hintText: 'Ask your stylist anything…',
                    hintStyle: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SendButton(sending: sending, onTap: onSend),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool sending;
  final VoidCallback onTap;

  const _SendButton({required this.sending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sending ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: sending
              ? AppColors.primary.withAlpha(120)
              : AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 20,
              ),
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _QuickPromptChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withAlpha(14)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: AppColors.primary.withAlpha(40),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              size: 13,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
