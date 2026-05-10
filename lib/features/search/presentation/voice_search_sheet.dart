import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../../core/theme/theme.dart';

/// Modal bottom sheet that captures a voice search query.
///
/// Wraps the `speech_to_text` plugin (SFSpeechRecognizer on iOS,
/// SpeechRecognizer on Android). Shows an expanding pulse while
/// listening, surfaces the interim transcript live, and pops
/// with the final transcript string when the user is done — or
/// `null` if they cancel / the recogniser errors out.
///
/// Permissions:
///   * iOS — needs both NSMicrophoneUsageDescription AND
///     NSSpeechRecognitionUsageDescription in Info.plist.
///   * Android — needs RECORD_AUDIO + the
///     `android.speech.RecognitionService` query in
///     AndroidManifest.xml.
///
/// Both are wired in this PR (commit alongside this widget).
///
/// Open with [showVoiceSearchSheet]; it returns the transcript
/// (trimmed) on success, null on cancel/error.
Future<String?> showVoiceSearchSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const VoiceSearchSheet(),
  );
}

class VoiceSearchSheet extends StatefulWidget {
  const VoiceSearchSheet({super.key});

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final _speech = stt.SpeechToText();
  late final AnimationController _pulseController;

  bool _ready = false;
  bool _listening = false;
  String _transcript = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _bootstrap();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Best-effort stop the recogniser if the user backgrounds the
    // sheet without explicitly tapping Done.
    _speech.stop();
    super.dispose();
  }

  /// Initialise the speech engine and start listening immediately.
  /// On platforms where the user hasn't granted permission, this
  /// triggers the OS prompt as a side-effect of [stt.SpeechToText.initialize].
  Future<void> _bootstrap() async {
    try {
      final ok = await _speech.initialize(
        onError: _onError,
        onStatus: (s) {
          // Auto-stop transitions like 'notListening' / 'done'
          // are propagated as status updates, not via the
          // listen completion callback. We don't auto-pop here
          // — the user can review the transcript and tap Done
          // (or speak again) before returning.
          if (mounted && s == 'notListening' && _listening) {
            setState(() => _listening = false);
          }
        },
      );
      if (!mounted) return;
      setState(() => _ready = ok);
      if (ok) await _startListening();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _startListening() async {
    if (!_ready || _listening) return;
    setState(() {
      _listening = true;
      _transcript = '';
      _error = null;
    });
    try {
      await _speech.listen(
        onResult: _onResult,
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _listening = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _transcript = result.recognizedWords);
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _listening = false;
      _error = _humanizeError(error);
    });
  }

  String _humanizeError(SpeechRecognitionError error) {
    switch (error.errorMsg) {
      case 'error_permission':
        return 'Microphone access is off. Enable it in Settings to use voice search.';
      case 'error_no_match':
        return 'Didn\'t catch that — try again.';
      case 'error_network':
        return 'No internet — voice search needs a connection.';
      case 'error_speech_timeout':
        return 'No speech detected. Tap to try again.';
      default:
        return 'Voice search isn\'t available right now (${error.errorMsg}).';
    }
  }

  void _confirm() {
    final t = _transcript.trim();
    if (t.isEmpty) return;
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sheet grabber.
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'VOICE SEARCH',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _listening
                ? 'Listening…'
                : (_error != null ? 'Couldn\'t hear you' : 'Tap and speak'),
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 24),
          _PulseMic(
            controller: _pulseController,
            listening: _listening,
            onTap: _listening ? _stopListening : _startListening,
          ),
          const SizedBox(height: 24),
          // Transcript or error / hint.
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _error ??
                  (_transcript.isEmpty
                      ? 'Try: "silk sherwani for wedding" or "kurta in linen"'
                      : '"$_transcript"'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: _transcript.isEmpty
                    ? FontWeight.w500
                    : FontWeight.w700,
                color: _error != null
                    ? AppColors.error
                    : (_transcript.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.primary),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withAlpha(70),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _transcript.trim().isEmpty ? null : _confirm,
                    icon: const Icon(
                      Icons.search_rounded,
                      size: 16,
                    ),
                    label: Text(
                      'SEARCH',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated pulsing mic button. Three concentric rings expand
/// outward while listening; tap the inner mic to start/stop.
class _PulseMic extends StatelessWidget {
  const _PulseMic({
    required this.controller,
    required this.listening,
    required this.onTap,
  });

  final AnimationController controller;
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Three rings each at a phase-shifted progress so
                // the visual reads as a continuous pulse.
                if (listening) ...[
                  _ring(
                      progress:
                          (controller.value + 0.0) % 1.0),
                  _ring(
                      progress:
                          (controller.value + 0.33) % 1.0),
                  _ring(
                      progress:
                          (controller.value + 0.66) % 1.0),
                ],
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: listening
                        ? AppColors.accent
                        : AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (listening
                                ? AppColors.accent
                                : AppColors.primary)
                            .withAlpha(70),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    listening
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _ring({required double progress}) {
    final size = 76.0 + (140.0 - 76.0) * progress;
    final alpha = ((1 - progress) * 80).clamp(0, 80).toInt();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withAlpha(alpha),
          width: 2,
        ),
      ),
    );
  }
}
