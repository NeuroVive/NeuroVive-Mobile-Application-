
// Helper function to build help instructions bottom sheet
import 'dart:io';
import 'dart:math' as math;

import 'package:neurovive/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'icons/neurovive_icons.dart';







//for the routing

Future<bool> handleBack(BuildContext context) async { //this has the back button rules, dont forget to call it in the popscope too if u will add a page's rule
  final location = GoRouter.of(context).state.uri.path;

  if (location == '/results') {
    context.go('/');
    return false; // no pop
  }

  if(location == '/')
    {
      exit(0);
    }

  if (context.canPop()) {
    context.pop();
    return true;
  }

  //dont pop if no rules matched
  return false;
}







//for the instructions

void showCurrentInstructions(BuildContext context,String currentPath)
{
  switch (currentPath) {
  ///later we will add the instructions for the other pages here, but the function itself will be in utils.dart
    case '/voice':
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            _buildHelpInstructionsSheetForVoiceRecord(
                context),
      );
      break;
    case '/handwriting':
      Utils.showHandwritingInstructions(context);
      break;
  }

}








final showHelpOnceProvider =
FutureProvider.family<bool, String>((ref, key) async {
  final prefs = await SharedPreferences.getInstance();

  final storageKey = 'help_shown_$key';

  final shown = prefs.getBool(storageKey) ?? false;

  if (!shown) {
    await prefs.setBool(storageKey, true);
    return true; // show help
  }

  return false; // don't show
});



Widget _buildHelpInstructionsSheetForVoiceRecord(BuildContext context) {
  return DraggableScrollableSheet(
    initialChildSize: 0.75,
    minChildSize: 0.5,
    maxChildSize: 0.9,
    builder: (context, scrollController) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with X and title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Neurovive.close,
                      color: Color(0xFFB22222),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '     ${AppLocalizations.of(context)!.voiceHelpTitle}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB22222),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildSectionTitle(AppLocalizations.of(context)!.voiceHelpFirstMain),
                  const SizedBox(height: 8),
                  _buildBulletPoint(
                    AppLocalizations.of(context)!.voiceHelpFirstMainFirstSubTitle,
                    AppLocalizations.of(context)!.voiceHelpFirstMainFirstSubDesc,
                  ),
                  _buildBulletPoint(
                    AppLocalizations.of(context)!.voiceHelpFirstMainSecondSubTitle,
                    AppLocalizations.of(context)!.voiceHelpFirstMainSecondSubDesc,
                  ),
                  const SizedBox(height: 16),
                  _buildDashedDivider(),
                  const SizedBox(height: 16),

                  _buildSectionTitle(AppLocalizations.of(context)!.voiceHelpSecondMainTitle),
                  const SizedBox(height: 8),
                  _buildBulletPoint(
                    AppLocalizations.of(context)!.voiceHelpSecondMainFirstSubTitle,
                    AppLocalizations.of(context)!.voiceHelpSecondMainFirstSubDesc,
                  ),
                  _buildBulletPoint(
                    AppLocalizations.of(context)!.voiceHelpSecondMainSecondSubTitle,
                    AppLocalizations.of(context)!.voiceHelpSecondMainSecondSubDesc,
                  ),
                  const SizedBox(height: 16),
                  _buildDashedDivider(),
                  const SizedBox(height: 16),

                  _buildSectionTitle(AppLocalizations.of(context)!.voiceHelpThirdMain),
                  const SizedBox(height: 8),
                  _buildBulletPoint(
                    AppLocalizations.of(context)!.voiceHelpThirdMainFirstSubTitle,
                    AppLocalizations.of(context)!.voiceHelpThirdMainFirstSubDesc,
                  ),
                  _buildBulletPoint(
                    AppLocalizations.of(context)!.voiceHelpThirdMainSecondSubTitle,
                    AppLocalizations.of(context)!.voiceHelpThirdMainSecondSubDesc,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildSectionTitle(String title) {
  return Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
  );
}

Widget _buildBulletPoint(String title, String description) {
  return Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' $description'),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildDashedDivider() {
  return CustomPaint(
    size: const Size(double.infinity, 1),
    painter: _DashedLinePainter(),
  );
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
//  Utils class – reusable app-level utilities
// ─────────────────────────────────────────────

class Utils {
  Utils._(); // prevent instantiation

  /// Shows a 3-slide Handwriting Test instruction bottom sheet.
  static void showHandwritingInstructions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HandwritingInstructionsSheet(),
    );
  }
}

// ── Bottom-sheet stateful widget ──────────────

class _HandwritingInstructionsSheet extends StatefulWidget {
  @override
  State<_HandwritingInstructionsSheet> createState() =>
      _HandwritingInstructionsSheetState();
}

class _HandwritingInstructionsSheetState
    extends State<_HandwritingInstructionsSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 3;

  // Brand colours
  static const Color _teal = Color(0xFF2A7F7F);
  static const Color _darkBlue = Color(0xFF1E3A5F);
  static const Color _spiralBlue = Color(0xFF5FA8D3);
  static const Color _flashYellow = Color(0xFFFFFF00);
  static const Color _flashPurple = Color(0xFFB14DFF);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (page < 0 || page >= _totalPages) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: _darkBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // ── Background Camera/Blur Effect Section ──
          Positioned(
            top: 70, // Below the navigation bar
            left: 0,
            right: 0,
            height: 150,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const NetworkImage('https://i.ibb.co/3mBkzRz/blur-bg.png'), // Placeholder for camera effect or use a gradient
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withAlpha(51), // 255 * 0.2
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  // Yellow Flash Icon
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _flashYellow.withAlpha(204), // 255 * 0.8
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _flashYellow.withAlpha(128), // 255 * 0.5
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.flash_on,
                          color: _flashPurple,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Top Navigation Bar Header ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Handwriting Test',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.white, size: 28),
                    onPressed: () {
                      // Help action
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Instruction Container (White, Rounded) ──
          Positioned(
            top: 200, // Overlapping the blur background slightly
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // Container Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.close,
                            color: _spiralBlue,
                            size: 28,
                            weight: 900,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Handwriting Test Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _spiralBlue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Page View Content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      children: [
                        _buildSlide1(),
                        _buildSlide2(),
                        _buildSlide3(), // Slide 3 usually doesn't need the scrollController if it's not too long, or we can add it back if needed
                      ],
                    ),
                  ),

                  // Bottom Navigation Arrows
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _currentPage > 0
                              ? () => _goTo(_currentPage - 1)
                              : null,
                          icon: Icon(
                            Icons.chevron_left,
                            size: 40,
                            color: _currentPage > 0 ? _darkBlue : Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(width: 40),
                        IconButton(
                          onPressed: _currentPage < _totalPages - 1
                              ? () => _goTo(_currentPage + 1)
                              : () => Navigator.of(context).pop(),
                          icon: Icon(
                            _currentPage < _totalPages - 1 ? Icons.chevron_right : Icons.check_circle_outline,
                            size: 40,
                            color: _darkBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Slide 1: Draw a spiral ──────────────────
  Widget _buildSlide1() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomPaint(
          size: const Size(220, 220),
          painter: _SpiralPainter(color: _spiralBlue),
        ),
        const SizedBox(height: 32),
        const Text(
          'Draw a spiral',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _darkBlue,
          ),
        ),
      ],
    );
  }

  // ── Slide 2: Take a photo ───────────────────
  Widget _buildSlide2() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(260, 260),
                painter: _ScannerBracketPainter(color: _teal),
              ),
              CustomPaint(
                size: const Size(190, 190),
                painter: _SpiralPainter(color: _spiralBlue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Take a photo for your spiral',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _darkBlue,
          ),
        ),
      ],
    );
  }

  // ── Slide 3: Detailed instructions ─────────
  Widget _buildSlide3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextSection(
            'Preparation:',
            [
              'Use a blank, unlined white sheet of paper.',
              'Use a dark pen (black or blue ink) for maximum contrast.',
              'Place the paper on a flat, stable surface.',
            ],
          ),
          _buildDashedDivider(),
          _buildTextSection(
            'Drawing the Spiral:',
            [
              'Start from a dot in the center of the paper.',
              'Draw a continuous line outward in a spiral shape (Archimedes spiral) for about 5 rotations.',
              'Draw at your natural pace. Do not attempt to hide any shakiness—the AI needs to see your natural movement to provide an objective validation.',
            ],
          ),
          _buildDashedDivider(),
          _buildTextSection(
            'Capturing the Photo:',
            [
              'Ensure the room is well-lit to avoid shadows.',
              'Hold your phone directly above the paper, keeping it parallel to the surface.',
              'Align the spiral within the on-screen guide and tap the shutter button.',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection(String title, List<String> bullets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _teal,
          ),
        ),
        const SizedBox(height: 8),
        ...bullets.map((b) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16, color: Colors.black87)),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildDashedDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: UtilsDashedDivider(),
    );
  }
}

class UtilsDashedDivider extends StatelessWidget {
  const UtilsDashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(),
    );
  }
}

// ── Custom painters ────────────────────────────

/// Draws an Archimedean spiral.
class _SpiralPainter extends CustomPainter {
  final Color color;
  const _SpiralPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.05
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = size.width * 0.45;
    const turns = 5.0;
    const steps = 600;

    final path = Path();
    bool first = true;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = t * turns * 2 * math.pi;
      final radius = t * maxRadius;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpiralPainter old) => old.color != color;
}

/// Draws teal scanner-style corner brackets.
class _ScannerBracketPainter extends CustomPainter {
  final Color color;
  const _ScannerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 40.0;
    const pad = 10.0;

    // Top-left
    canvas.drawLine(const Offset(pad, pad), const Offset(pad + len, pad), paint);
    canvas.drawLine(const Offset(pad, pad), const Offset(pad, pad + len), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad - len, pad), paint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + len), paint);

    // Bottom-left
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + len, size.height - pad), paint);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad, size.height - pad - len), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad - len, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - len), paint);
  }

  @override
  bool shouldRepaint(_ScannerBracketPainter old) => old.color != color;
}