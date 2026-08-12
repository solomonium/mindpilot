import 'dart:ui';
import 'package:mindpilot/export.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

/// Full-screen QR scanner that supports:
///  1. Live camera scanning — point at any MindPilot QR code
///  2. Pick from gallery — choose a saved QR image and the app decodes it
///
/// Handles two QR formats produced by AppShareSheet:
///  • mindpilot://group/<groupId>/<encodedName>  → join group lobby
///  • Any URL (download link)                   → open in browser
class QrScanJoinScreen extends StatefulWidget {
  const QrScanJoinScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'QrScanJoinScreen'),
        builder: (_) => const QrScanJoinScreen(),
      ),
    );
  }

  @override
  State<QrScanJoinScreen> createState() => _QrScanJoinScreenState();
}

class _QrScanJoinScreenState extends State<QrScanJoinScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  final ImagePicker _imagePicker = ImagePicker();

  bool _isProcessing = false;
  bool _torchOn = false;
  String? _statusMessage;

  static const _accent = Color(0xFFCCFF00);

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // ── QR decode handler (camera or gallery) ────────────────────────────────
  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;
    await _processQrValue(rawValue);
  }

  Future<void> _processQrValue(String value) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning…';
    });

    try {
      // ── MindPilot group deep-link ─────────────────────────────────────
      if (value.startsWith('mindpilot://group/')) {
        final parts = value.replaceFirst('mindpilot://group/', '').split('/');
        if (parts.length >= 2) {
          final groupId = parts[0];
          final groupName = Uri.decodeComponent(parts.sublist(1).join('/'));
          await _joinGroup(groupId, groupName);
          return;
        }
      }

      // ── Plain URL — try opening in browser ────────────────────────────
      final uri = Uri.tryParse(value);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        setState(() => _statusMessage = 'Opening link…');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // ── Unknown format ────────────────────────────────────────────────
      setState(() {
        _statusMessage = 'Unknown QR code. Please scan a MindPilot invite QR.';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _joinGroup(String groupId, String groupName) async {
    setState(() => _statusMessage = 'Joining "$groupName"…');

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Please sign in to join a group.';
        _isProcessing = false;
      });
      return;
    }

    try {
      final provider = context.read<GroupQuizProvider>();
      await provider.directJoinGroup(groupId);
      provider.listenToGroup(groupId);

      if (!mounted) return;
      // Pop scanner then push lobby
      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'GroupLobbyScreen'),
          builder: (_) => GroupLobbyScreen(groupId: groupId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Could not join group: $e';
        _isProcessing = false;
      });
    }
  }

  // ── Gallery picker ────────────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Reading QR from image…';
      });

      // Pause live scanner while we analyze the image
      await _scannerController.stop();

      final BarcodeCapture? result =
          await _scannerController.analyzeImage(picked.path);

      if (result == null || result.barcodes.isEmpty) {
        setState(() {
          _statusMessage =
              'No QR code found in that image. Try a different photo.';
          _isProcessing = false;
        });
        await _scannerController.start();
        return;
      }

      final rawValue = result.barcodes.first.rawValue ?? '';
      await _processQrValue(rawValue);
      if (mounted && !_isProcessing) {
        await _scannerController.start();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Could not read image: $e';
        _isProcessing = false;
      });
      await _scannerController.start();
    }
  }

  void _resetScan() {
    setState(() {
      _isProcessing = false;
      _statusMessage = null;
    });
    _scannerController.start();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cutoutSize = size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Live camera feed ──────────────────────────────────────────
          MobileScanner(
            controller: _scannerController,
            onDetect: _isProcessing ? null : _handleDetection,
          ),

          // ── Dark overlay with transparent cutout ──────────────────────
          _ScanOverlay(cutoutSize: cutoutSize),

          // ── Content layer ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: PrimaryText(
                            text: 'Scan QR to Join',
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Torch toggle
                      GestureDetector(
                        onTap: () async {
                          await _scannerController.toggleTorch();
                          setState(() => _torchOn = !_torchOn);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _torchOn
                                ? _accent.withOpacity(0.2)
                                : Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _torchOn ? _accent : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            _torchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: _torchOn ? _accent : Colors.white54,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Spacer to push cutout to center
                SizedBox(height: size.height * 0.1),

                // Cutout label above
                PrimaryText(
                  text: 'Point at a MindPilot QR code',
                  color: Colors.white70,
                  fontSize: 14,
                  textAlign: TextAlign.center,
                ),
                12.verticalSpace,

                // Animated corner brackets around cutout
                SizedBox(
                  width: cutoutSize,
                  height: cutoutSize,
                  child: _isProcessing
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: _accent,
                                strokeWidth: 2.5,
                              ),
                              12.verticalSpace,
                              PrimaryText(
                                text: _statusMessage ?? 'Processing…',
                                color: Colors.white,
                                fontSize: 13,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : const _ScannerBrackets(),
                ),

                12.verticalSpace,

                // Error / status message
                if (_statusMessage != null && !_isProcessing) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            SecondaryText(
                              text: _statusMessage!,
                              color: Colors.white70,
                              fontSize: 13,
                              textAlign: TextAlign.center,
                            ),
                            8.verticalSpace,
                            GestureDetector(
                              onTap: _resetScan,
                              child: PrimaryText(
                                text: 'Tap to scan again',
                                color: _accent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Bottom panel
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pill handle
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          SecondaryText(
                            text:
                                'Received a QR image on WhatsApp? Save it to your photos, then tap below.',
                            color: Colors.white54,
                            fontSize: 12,
                            textAlign: TextAlign.center,
                          ),

                          16.verticalSpace,

                          // Pick from gallery
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.black,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              onPressed:
                                  _isProcessing ? null : _pickFromGallery,
                              icon: const Icon(
                                Icons.photo_library_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'Pick QR from Gallery',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay: darkens everything except the cutout
// ─────────────────────────────────────────────────────────────────────────────
class _ScanOverlay extends StatelessWidget {
  final double cutoutSize;
  const _ScanOverlay({required this.cutoutSize});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(cutoutSize: cutoutSize),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double cutoutSize;
  const _OverlayPainter({required this.cutoutSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.6);
    final cx = size.width / 2;
    final cy = size.height / 2 - 10;
    final half = cutoutSize / 2;
    final rect = Rect.fromLTWH(cx - half, cy - half, cutoutSize, cutoutSize);

    // Full screen
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(20)),
        )
        ..fillType = PathFillType.evenOdd,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated corner brackets
// ─────────────────────────────────────────────────────────────────────────────
class _ScannerBrackets extends StatefulWidget {
  const _ScannerBrackets();

  @override
  State<_ScannerBrackets> createState() => _ScannerBracketsState();
}

class _ScannerBracketsState extends State<_ScannerBrackets>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  static const _accent = Color(0xFFCCFF00);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.6 + _anim.value * 0.4;
        return CustomPaint(
          painter: _BracketPainter(opacity: opacity, color: _accent),
        );
      },
    );
  }
}

class _BracketPainter extends CustomPainter {
  final double opacity;
  final Color color;
  const _BracketPainter({required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arm = 28.0;
    const r = 8.0;

    void corner(Offset topLeft, bool flipX, bool flipY) {
      final dx = flipX ? -1.0 : 1.0;
      final dy = flipY ? -1.0 : 1.0;
      final o = topLeft;

      final path = Path()
        ..moveTo(o.dx + dx * arm, o.dy)
        ..lineTo(o.dx + dx * r, o.dy)
        ..arcToPoint(
          Offset(o.dx, o.dy + dy * r),
          radius: const Radius.circular(r),
          clockwise: !(flipX ^ flipY),
        )
        ..lineTo(o.dx, o.dy + dy * arm);

      canvas.drawPath(path, paint);
    }

    final w = size.width;
    final h = size.height;
    corner(Offset.zero, false, false);
    corner(Offset(w, 0), true, false);
    corner(Offset(0, h), false, true);
    corner(Offset(w, h), true, true);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) =>
      old.opacity != opacity;
}
