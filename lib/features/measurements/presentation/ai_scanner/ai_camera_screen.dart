import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme.dart';
import '../../../checkout/models/order_payload.dart';

/// Custom camera capture surface for the AI Body Scanner.
///
/// Walks the user through two shots:
///   1. **Front** — full body, facing the lens.
///   2. **Side** — 90° rotation, arms down.
///
/// A dashed human silhouette is painted over the preview as a framing
/// guide. Once both frames are captured we push the scanning screen,
/// passing the two [File] handles (and the original [OrderPayload]) so
/// the full context reaches the review screen.
class AiCameraScreen extends StatefulWidget {
  final OrderPayload? payload;

  const AiCameraScreen({super.key, this.payload});

  @override
  State<AiCameraScreen> createState() => _AiCameraScreenState();
}

enum _CaptureStep { front, side }

class _AiCameraScreenState extends State<AiCameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  Future<void>? _initFuture;

  _CaptureStep _step = _CaptureStep.front;
  File? _frontImage;
  File? _sideImage;
  bool _capturing = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _initError = 'No camera available on this device.');
        return;
      }
      // Prefer the back camera — wider field of view, better for a full
      // body frame at 6–7 ft away.
      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      setState(
        () => _initError =
            'Camera unavailable: ${e.description ?? e.code}. Check permissions.',
      );
    } catch (e) {
      setState(() => _initError = 'Camera unavailable: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final shot = await controller.takePicture();
      final file = File(shot.path);
      if (_step == _CaptureStep.front) {
        setState(() {
          _frontImage = file;
          _step = _CaptureStep.side;
          _capturing = false;
        });
      } else {
        setState(() {
          _sideImage = file;
          _capturing = false;
        });
        _goToScanning();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
    }
  }

  void _goToScanning() {
    final front = _frontImage;
    final side = _sideImage;
    if (front == null || side == null) return;
    context.push(
      '/measurements/ai-scan-scanning',
      extra: AiScanPayload(
        order: widget.payload,
        frontImage: front,
        sideImage: side,
      ),
    );
  }

  void _retake() {
    setState(() {
      _frontImage = null;
      _sideImage = null;
      _step = _CaptureStep.front;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (_initError != null) {
              return _buildError(_initError!);
            }
            if (snapshot.connectionState != ConnectionState.done ||
                _controller == null ||
                !_controller!.value.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            return _buildCamera();
          },
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined,
              size: 48, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    final isFront = _step == _CaptureStep.front;
    final prompt = isFront
        ? 'Step back so your full body is in the frame. Face forward.'
        : 'Great. Now turn 90° to your right for a side profile.';
    final stepLabel = isFront ? 'STEP 1 OF 2 · FRONT' : 'STEP 2 OF 2 · SIDE';

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Live preview ──
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.previewSize?.height ?? 360,
              height: _controller!.value.previewSize?.width ?? 640,
              child: CameraPreview(_controller!),
            ),
          ),
        ),

        // ── Darkening vignette so the overlay + copy read well ──
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(140),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withAlpha(180),
                  ],
                  stops: const [0.0, 0.18, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),

        // ── Dashed silhouette overlay ──
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SilhouettePainter(isFront: isFront),
            ),
          ),
        ),

        // ── Top bar: step pill + close ──
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(130),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.accentContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stepLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ],
          ),
        ),

        // ── Prompt card ──
        Positioned(
          top: 70,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(150),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(30)),
            ),
            child: Row(
              children: [
                Icon(
                  isFront ? Icons.person_rounded : Icons.directions_walk_rounded,
                  size: 18,
                  color: AppColors.accentContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    prompt,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Bottom controls ──
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Thumbnails of captured shots
              if (_frontImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _thumb(_frontImage!, 'FRONT'),
                      if (_sideImage != null) ...[
                        const SizedBox(width: 12),
                        _thumb(_sideImage!, 'SIDE'),
                      ],
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _bottomAction(
                    icon: Icons.refresh_rounded,
                    label: 'Retake',
                    onTap: _frontImage == null ? null : _retake,
                  ),
                  _shutterButton(),
                  _bottomAction(
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Tips',
                    onTap: () => _showTips(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumb(File file, String tag) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accentContainer, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tag,
          style: GoogleFonts.manrope(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppColors.accentContainer,
          ),
        ),
      ],
    );
  }

  Widget _shutterButton() {
    return GestureDetector(
      onTap: _capturing ? null : _capture,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _capturing ? 30 : 58,
            height: _capturing ? 30 : 58,
            decoration: BoxDecoration(
              color: _capturing
                  ? AppColors.accent
                  : AppColors.accentContainer,
              shape: _capturing ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: _capturing ? BorderRadius.circular(6) : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capture tips',
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            _tipLine('Line your body up inside the dashed silhouette.'),
            _tipLine('Feet shoulder-width apart, arms slightly away.'),
            _tipLine('Phone at waist height, 6–7 ft away.'),
            _tipLine('Plain wall behind you works best.'),
          ],
        ),
      ),
    );
  }

  Widget _tipLine(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 16, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Simple carrier for the 3-tuple of (order payload, front image, side
/// image) we need to thread from the camera screen through to the review
/// screen. Using a purpose-built class keeps `state.extra` typed end to
/// end instead of stuffing everything into a generic Map.
class AiScanPayload {
  final OrderPayload? order;
  final File frontImage;
  final File sideImage;

  const AiScanPayload({
    required this.order,
    required this.frontImage,
    required this.sideImage,
  });
}

/// Paints a dashed human silhouette. Two variants are supported: a
/// front-facing outline (hips wider, arms held out) and a side profile
/// (narrower, subtle S-curve for posture). We draw with a dashed stroke
/// so the guide reads as instructional UI rather than a blocking mask.
class _SilhouettePainter extends CustomPainter {
  final bool isFront;
  _SilhouettePainter({required this.isFront});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final topY = size.height * 0.14;
    final availableH = size.height * 0.72;

    final glowPaint = Paint()
      ..color = AppColors.accentContainer.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final strokePaint = Paint()
      ..color = AppColors.accentContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = isFront
        ? _frontPath(centerX, topY, availableH, size.width)
        : _sidePath(centerX, topY, availableH, size.width);

    // Soft accent glow behind the dashed stroke
    canvas.drawPath(path, glowPaint);

    // Dashed outline
    final dashed = _dashPath(path, dashLength: 9, gapLength: 7);
    canvas.drawPath(dashed, strokePaint);
  }

  Path _frontPath(double cx, double topY, double h, double fullW) {
    // Proportions tuned to read as a person inside a 9:16 portrait frame.
    final headR = h * 0.07;
    final shoulderW = h * 0.22;
    final hipW = h * 0.18;
    final torsoTopY = topY + headR * 2 + h * 0.01;
    final torsoBottomY = torsoTopY + h * 0.38;
    final feetY = topY + h;

    final p = Path();

    // Head
    p.addOval(Rect.fromCircle(
      center: Offset(cx, topY + headR),
      radius: headR,
    ));

    // Neck + shoulders + torso outline (closed)
    p.moveTo(cx - headR * 0.45, topY + headR * 1.9);
    p.lineTo(cx - shoulderW, torsoTopY + h * 0.02);
    p.lineTo(cx - hipW, torsoBottomY);
    // Legs taper to feet
    p.lineTo(cx - hipW * 0.55, feetY);
    p.lineTo(cx - hipW * 0.1, feetY);
    p.lineTo(cx - hipW * 0.05, torsoBottomY + h * 0.04);
    p.lineTo(cx + hipW * 0.05, torsoBottomY + h * 0.04);
    p.lineTo(cx + hipW * 0.1, feetY);
    p.lineTo(cx + hipW * 0.55, feetY);
    p.lineTo(cx + hipW, torsoBottomY);
    p.lineTo(cx + shoulderW, torsoTopY + h * 0.02);
    p.lineTo(cx + headR * 0.45, topY + headR * 1.9);
    p.close();

    // Arms (separate paths held slightly away from body)
    final armTopL = Offset(cx - shoulderW * 0.9, torsoTopY + h * 0.05);
    final armBottomL = Offset(cx - shoulderW * 1.05, torsoBottomY - h * 0.05);
    p.moveTo(armTopL.dx, armTopL.dy);
    p.lineTo(armBottomL.dx, armBottomL.dy);
    p.lineTo(armBottomL.dx - 6, armBottomL.dy + 12);

    final armTopR = Offset(cx + shoulderW * 0.9, torsoTopY + h * 0.05);
    final armBottomR = Offset(cx + shoulderW * 1.05, torsoBottomY - h * 0.05);
    p.moveTo(armTopR.dx, armTopR.dy);
    p.lineTo(armBottomR.dx, armBottomR.dy);
    p.lineTo(armBottomR.dx + 6, armBottomR.dy + 12);

    return p;
  }

  Path _sidePath(double cx, double topY, double h, double fullW) {
    // A simple side profile: head in profile, shoulder bulge at the back,
    // chest forward, slight butt curve, single straight leg.
    final headR = h * 0.07;
    final feetY = topY + h;

    final p = Path();

    // Head (offset slightly forward to suggest a profile)
    p.addOval(Rect.fromCircle(
      center: Offset(cx - headR * 0.3, topY + headR),
      radius: headR,
    ));

    // Back curve
    p.moveTo(cx + headR * 0.3, topY + headR * 1.8);
    p.cubicTo(
      cx + headR * 1.4, topY + h * 0.18, // upper back
      cx + headR * 1.8, topY + h * 0.32, // mid back
      cx + headR * 1.4, topY + h * 0.52, // lower back
    );
    p.cubicTo(
      cx + headR * 2.0, topY + h * 0.6, // butt curve
      cx + headR * 1.4, topY + h * 0.72,
      cx + headR * 0.5, feetY,
    );
    // Foot tip (back)
    p.lineTo(cx + headR * 1.1, feetY);
    p.lineTo(cx + headR * 1.1, feetY - 2);

    // Front curve coming back up
    p.moveTo(cx - headR * 0.6, topY + headR * 1.8);
    p.cubicTo(
      cx - headR * 0.4, topY + h * 0.18,
      cx - headR * 1.1, topY + h * 0.32, // chest out
      cx - headR * 0.7, topY + h * 0.5,
    );
    p.cubicTo(
      cx - headR * 0.4, topY + h * 0.65,
      cx - headR * 0.3, topY + h * 0.82,
      cx - headR * 0.2, feetY,
    );
    // Foot tip (front)
    p.lineTo(cx - headR * 1.0, feetY);
    p.lineTo(cx - headR * 1.0, feetY - 2);

    // Arm resting at side
    p.moveTo(cx + headR * 0.9, topY + h * 0.22);
    p.cubicTo(
      cx + headR * 0.4, topY + h * 0.35,
      cx + headR * 0.2, topY + h * 0.42,
      cx + headR * 0.35, topY + h * 0.52,
    );

    return p;
  }

  /// Approximates a dashed version of [source] by sampling along each
  /// contour. This is slightly more expensive than using a shader stroke
  /// but it gives us crisp, uniform dashes on curved paths.
  Path _dashPath(Path source, {required double dashLength, required double gapLength}) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLength : gapLength;
        if (draw) {
          dashed.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter old) =>
      old.isFront != isFront;
}
