import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/theme.dart';
import '../../catalog/models/product_model.dart';

/// Full-screen AR Virtual Try-On:
///
///   • Live camera preview (front-facing by default — selfie framing is what
///     converts, you want to see yourself wearing it).
///   • Product image composited on top, draggable and pinch-scalable via
///     [InteractiveViewer] so the user can align the garment with their body.
///   • Frosted bottom panel with a mocked AI size suggestion + shutter.
///   • Shutter captures the merged view (camera + overlay) through the
///     `screenshot` package and pushes it into the native share sheet.
///
/// The screen expects a [ProductModel] via `GoRouter` `extra`. If none is
/// passed we bail out gracefully so a bad deep link can't crash the app.
class VirtualTryOnScreen extends StatefulWidget {
  final ProductModel product;

  const VirtualTryOnScreen({super.key, required this.product});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen>
    with WidgetsBindingObserver {
  // ── Camera ──
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _activeCameraIndex = 0;
  String? _initError;

  // ── Capture ──
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _capturing = false;

  // ── Garment overlay transform ──
  // InteractiveViewer owns its transform; we keep a controller so we can
  // reset alignment after a flip (which visually mirrors the preview).
  final TransformationController _overlayTransform =
      TransformationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera(preferFront: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _overlayTransform.dispose();
    super.dispose();
  }

  // Release the camera when the app is backgrounded; rebind on resume.
  // Essential on iOS — the OS will yank the feed otherwise and we come
  // back to a frozen frame.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(preferFront: _isFrontActive);
    }
  }

  bool get _isFrontActive {
    if (_cameras.isEmpty || _activeCameraIndex >= _cameras.length) return true;
    return _cameras[_activeCameraIndex].lensDirection ==
        CameraLensDirection.front;
  }

  Future<void> _initCamera({required bool preferFront}) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _initError = 'No camera available on this device.');
        return;
      }
      final desired = preferFront
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final idx = _cameras.indexWhere((c) => c.lensDirection == desired);
      _activeCameraIndex = idx >= 0 ? idx : 0;

      final controller = CameraController(
        _cameras[_activeCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initError = null;
      });
    } on CameraException catch (e) {
      setState(() =>
          _initError = 'Camera unavailable: ${e.description ?? e.code}.');
    } catch (e) {
      setState(() => _initError = 'Camera unavailable: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _capturing) return;
    final next = (_activeCameraIndex + 1) % _cameras.length;
    _activeCameraIndex = next;

    final old = _controller;
    setState(() => _controller = null);
    await old?.dispose();

    final controller = CameraController(
      _cameras[next],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      // Reset the garment transform so the user doesn't end up with a
      // mirrored offset after flipping.
      _overlayTransform.value = Matrix4.identity();
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      setState(() =>
          _initError = 'Camera unavailable: ${e.description ?? e.code}.');
    }
  }

  Future<void> _captureAndShare() async {
    if (_capturing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _capturing = true);
    try {
      final Uint8List? bytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 60),
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      if (bytes == null) {
        throw Exception('Could not capture the try-on frame.');
      }

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/vastrahub_tryon_$ts.png');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text:
            'Trying on "${widget.product.name}" on VASTRAHUB — what do you think?',
        subject: 'VASTRAHUB Virtual Try-On',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Share failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// Mocked AI size suggestion. Designed so it can be swapped out for a
  /// real call into `AiMeasurementService` later without touching the UI.
  /// Today it keys off the product category so the copy at least feels
  /// tailored ("Size 30" for trousers vs "Size M" for a shirt).
  _SizeSuggestion _computeSizeSuggestion() {
    final slug = (widget.product.categorySlug ?? '').toLowerCase();
    final name = widget.product.name.toLowerCase();
    final isBottom = slug.contains('trouser') ||
        slug.contains('pant') ||
        slug.contains('bottom') ||
        name.contains('trouser') ||
        name.contains('pant');
    if (isBottom) {
      return const _SizeSuggestion(
        label: 'Size 32',
        rationale: 'Based on your last scan, a 32" waist sits best.',
      );
    }
    return const _SizeSuggestion(
      label: 'Size M',
      rationale: 'Based on your profile, M fits your shoulders best.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera + garment overlay (the *only* layers captured) ──
          Screenshot(
            controller: _screenshotController,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCameraLayer(),
                _buildGarmentOverlay(),
              ],
            ),
          ),

          // ── Non-captured chrome (top bar, bottom panel, hints) ──
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(),
                _buildHint(),
                _buildBottomPanel(),
              ],
            ),
          ),

          if (_capturing) _buildCapturingVeil(),
        ],
      ),
    );
  }

  // ───────────────────────── Layers ─────────────────────────

  Widget _buildCameraLayer() {
    if (_initError != null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _initError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: Colors.white.withAlpha(220),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }
    // Fill the screen with the preview while keeping the native aspect ratio.
    // This crops a little off the sides on most phones but feels much more
    // like a real AR mirror than a letter-boxed preview.
    final size = MediaQuery.of(context).size;
    final previewSize = controller.value.previewSize;
    final ratio = previewSize == null
        ? controller.value.aspectRatio
        : previewSize.height / previewSize.width;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.width,
        height: size.width / ratio,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildGarmentOverlay() {
    final images = widget.product.images;
    if (images.isEmpty) {
      // Nothing to overlay — still let the user snap a selfie.
      return const SizedBox.shrink();
    }
    final imageUrl = images.first;

    // InteractiveViewer gives us pinch-to-zoom + pan for free, centered on
    // the child. We keep the image itself a fixed fraction of the screen
    // so the starting scale is sensible on every device.
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.85,
        heightFactor: 0.55,
        child: InteractiveViewer(
          transformationController: _overlayTransform,
          minScale: 0.4,
          maxScale: 4.0,
          boundaryMargin: const EdgeInsets.all(400),
          clipBehavior: Clip.none,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  color: Colors.white.withAlpha(180),
                  strokeWidth: 2,
                ),
              );
            },
            errorBuilder: (context, error, stack) => _buildGarmentFallback(),
          ),
        ),
      ),
    );
  }

  Widget _buildGarmentFallback() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(120),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(60)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checkroom_rounded,
                color: Colors.white70, size: 48),
            const SizedBox(height: 8),
            Text(
              widget.product.name,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _chromeButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.pop(),
            tooltip: 'Close',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(110),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Text(
              'VIRTUAL TRY-ON',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          _chromeButton(
            icon: Icons.cameraswitch_rounded,
            onTap: _cameras.length < 2 ? null : _flipCamera,
            tooltip: 'Flip camera',
          ),
        ],
      ),
    );
  }

  Widget _chromeButton({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(onTap == null ? 60 : 110),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Icon(
              icon,
              color: Colors.white.withAlpha(onTap == null ? 120 : 255),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHint() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(120),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pinch_rounded,
                color: Colors.white.withAlpha(220), size: 14),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Pinch to resize · Drag to align',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withAlpha(220),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final suggestion = _computeSizeSuggestion();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFrostedPanel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Size suggestion row ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(60),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.accentLight.withAlpha(120),
                        ),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI SIZE SUGGESTION',
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                              color: Colors.white.withAlpha(180),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              text: 'We recommend: ',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withAlpha(230),
                              ),
                              children: [
                                TextSpan(
                                  text: suggestion.label,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            suggestion.rationale,
                            style: GoogleFonts.manrope(
                              fontSize: 10.5,
                              height: 1.35,
                              color: Colors.white.withAlpha(170),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Shutter row ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.newsreader(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _buildShutter(),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Capture · Share to WhatsApp, Instagram & more',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: Colors.white.withAlpha(160),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShutter() {
    return GestureDetector(
      onTap: _captureAndShare,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(_capturing ? 120 : 20),
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(6),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _capturing
                ? AppColors.accent
                : Colors.white.withAlpha(240),
          ),
          child: _capturing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCapturingVeil() {
    return IgnorePointer(
      ignoring: true,
      child: Container(color: Colors.white.withAlpha(30)),
    );
  }
}

/// Lightweight value class so a real AI hook can return both the sizing
/// label and the "why" in one place.
class _SizeSuggestion {
  final String label;
  final String rationale;

  const _SizeSuggestion({required this.label, required this.rationale});
}

/// A reusable dark frosted panel that sits at the bottom of the AR view.
/// Pulled out so the main widget tree stays readable.
class BackdropFrostedPanel extends StatelessWidget {
  final Widget child;

  const BackdropFrostedPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(40)),
        ),
      ),
      child: child,
    );
  }
}
