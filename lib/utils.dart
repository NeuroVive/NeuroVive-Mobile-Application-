import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurovive/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'icons/neurovive_icons.dart';

// ─────────────────────────────────────────────
// Back Button Handling
// ─────────────────────────────────────────────

Future<bool> handleBack(BuildContext context) async {
  final location = GoRouter.of(context).state.uri.path;

  if (location == '/results') {
    context.go('/');
    return false;
  }

  if (location == '/') {
    exit(0);
  }

  if (context.canPop()) {
    context.pop();
    return true;
  }

  return false;
}

// ─────────────────────────────────────────────
// Show Instructions Dispatcher
// ─────────────────────────────────────────────

void showCurrentInstructions(BuildContext context, String currentPath) {
  switch (currentPath) {
    case '/voice':
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            _buildHelpInstructionsSheetForVoiceRecord(context),
      );
      break;

    case '/handwriting':
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            _buildHelpInstructionsSheetForHandwriting(context),
      );
      break;
  }
}

// ─────────────────────────────────────────────
// SharedPreferences – show help once
// ─────────────────────────────────────────────

final showHelpOnceProvider = FutureProvider.family<bool, String>((
  ref,
  key,
) async {
  final prefs = await SharedPreferences.getInstance();
  final storageKey = 'help_shown_$key';

  final shown = prefs.getBool(storageKey) ?? false;

  if (!shown) {
    await prefs.setBool(storageKey, true);
    return true;
  }

  return false;
});

// ─────────────────────────────────────────────
// VOICE INSTRUCTIONS
// ─────────────────────────────────────────────

Widget _buildHelpInstructionsSheetForVoiceRecord(BuildContext context) {
  return DraggableScrollableSheet(
    initialChildSize: 0.75,
    minChildSize: 0.5,
    maxChildSize: 0.9,
    builder: (context, scrollController) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildSectionTitle(
                    AppLocalizations.of(context)!.voiceHelpFirstMain,
                  ),
                  const SizedBox(height: 8),
                  _buildBulletPoint(
                    AppLocalizations.of(
                      context,
                    )!.voiceHelpFirstMainFirstSubTitle,
                    AppLocalizations.of(
                      context,
                    )!.voiceHelpFirstMainFirstSubDesc,
                  ),
                  _buildBulletPoint(
                    AppLocalizations.of(
                      context,
                    )!.voiceHelpFirstMainSecondSubTitle,
                    AppLocalizations.of(
                      context,
                    )!.voiceHelpFirstMainSecondSubDesc,
                  ),
                  const SizedBox(height: 16),
                  _buildDashedDivider(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────
// HANDWRITING INSTRUCTIONS
// ─────────────────────────────────────────────

Widget _buildHelpInstructionsSheetForHandwriting(BuildContext context) {
  final PageController pageController = PageController();
  final ValueNotifier<int> currentPage = ValueNotifier<int>(0);

  const int totalPages = 3;

  const Color teal = Color(0xFF2A7F7F);
  const Color darkBlue = Color(0xFF1E3A5F);
  const Color spiralBlue = Color(0xFF5FA8D3);

  void goTo(int page) {
    if (page < 0 || page >= totalPages) return;
    pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    currentPage.value = page;
  }

  return DraggableScrollableSheet(
    initialChildSize: 0.75,
    minChildSize: 0.6,
    maxChildSize: 0.95,
    builder: (context, scrollController) {
      return Column(
        children: [
          // White Content Container
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Neurovive.close,
                            color: spiralBlue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Handwriting Test Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: spiralBlue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable + Pageable Content
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // PageView
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: PageView(
                            controller: pageController,
                            onPageChanged: (i) => currentPage.value = i,
                            children: [
                              // Slide 1
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width *
                                        0.75,
                                    child: Image.asset(
                                      "assets/images/spiral.png",
                                      color: Color.fromRGBO(95, 162, 203, 1),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  const Text(
                                    'Draw a spiral',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromRGBO(35, 68, 116, 1),
                                    ),
                                  ),
                                ],
                              ),

                              // Slide 2
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 280,
                                    height: 280,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CustomPaint(
                                          size: const Size(280, 280),
                                          painter: _ScannerBracketPainter(
                                            color: Color.fromRGBO(70, 209, 192, 1),
                                          ),
                                        ),
                                        SizedBox(
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.75,
                                          child: Image.asset(
                                            "assets/images/spiral.png",
                                              color: Color.fromRGBO(95, 162, 203, 1),
                                          ),
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
                                      color: Color.fromRGBO(35, 68, 116, 1),
                                    ),
                                  ),
                                ],
                              ),

                              // Slide 3
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTextSection('Preparation:', [
                                      'Use a blank, unlined white sheet of paper.',
                                      'Use a dark pen (black or blue ink).',
                                      'Place the paper on a flat surface.',
                                    ], teal),
                                    const SizedBox(height: 16),
                                    _buildTextSection('Drawing the Spiral:', [
                                      'Start from a dot in the center.',
                                      'Draw 5 continuous outward rotations.',
                                      'Draw naturally. Do not hide shakiness.',
                                    ], teal),
                                    const SizedBox(height: 16),
                                    _buildTextSection('Capturing the Photo:', [
                                      'Ensure good lighting.',
                                      'Hold phone parallel to paper.',
                                      'Align spiral inside guide.',
                                    ], teal),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
SizedBox(height: 50,),
                        // Navigation
                        ValueListenableBuilder<int>(
                          valueListenable: currentPage,
                          builder: (_, value, __) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: value > 0
                                      ? () => goTo(value - 1)
                                      : null,
                                  icon: Icon(
                                    Neurovive.arrow_left,
                                    size: 20,
                                    color: value > 0
                                        ? Color.fromRGBO(35, 68, 116, 1)
                                        : Color.fromRGBO(162, 162, 162, 1),
                                  ),
                                ),
                                const SizedBox(width: 40),
                                IconButton(
                                  onPressed: value < totalPages - 1
                                      ? () => goTo(value + 1)
                                      : () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    value < totalPages - 1
                                        ? Neurovive.arrow_right
                                        : Icons.check_circle_outline,
                                    size: value < totalPages - 1 ? 20 : 40 ,
                                    color: Color.fromRGBO(35, 68, 116, 1),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

// ─────────────────────────────────────────────
// Slides
// ─────────────────────────────────────────────

Widget _buildSlide1(Color spiralBlue, Color darkBlue) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Image.asset("assets/images/spiral.png"),
      const SizedBox(height: 32),
      Text(
        'Draw a spiral',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: darkBlue,
        ),
      ),
    ],
  );
}

Widget _buildSlide2(Color teal, Color spiralBlue, Color darkBlue) {
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
              painter: _ScannerBracketPainter(color: teal),
            ),
            CustomPaint(
              size: const Size(190, 190),
              painter: _SpiralPainter(color: spiralBlue),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
      Text(
        'Take a photo for your spiral',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: darkBlue,
        ),
      ),
    ],
  );
}

Widget _buildSlide3(Color teal) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextSection('Preparation:', [
          'Use a blank, unlined white sheet of paper.',
          'Use a dark pen (black or blue ink).',
          'Place the paper on a flat surface.',
        ], teal),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// Shared Helpers
// ─────────────────────────────────────────────

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

Widget _buildTextSection(String title, List<String> bullets, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color.fromRGBO(35, 68, 116, 1),
        ),
      ),
      const SizedBox(height: 8),
      ...bullets.map(
        (b) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• ',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Expanded(
                child: Text(
                  b,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildDashedDivider() {
  return CustomPaint(
    size: const Size(double.infinity, 1),
    painter: _DashedLinePainter(),
  );
}

// ─────────────────────────────────────────────
// Custom Painters
// ─────────────────────────────────────────────

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
  bool shouldRepaint(_SpiralPainter oldDelegate) => oldDelegate.color != color;
}

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
    canvas.drawLine(
      const Offset(pad, pad),
      const Offset(pad + len, pad),
      paint,
    );
    canvas.drawLine(
      const Offset(pad, pad),
      const Offset(pad, pad + len),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - pad, pad),
      Offset(size.width - pad - len, pad),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - pad, pad),
      Offset(size.width - pad, pad + len),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(pad, size.height - pad),
      Offset(pad + len, size.height - pad),
      paint,
    );
    canvas.drawLine(
      Offset(pad, size.height - pad),
      Offset(pad, size.height - pad - len),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - pad, size.height - pad),
      Offset(size.width - pad - len, size.height - pad),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - pad, size.height - pad),
      Offset(size.width - pad, size.height - pad - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScannerBracketPainter oldDelegate) =>
      oldDelegate.color != color;
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
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
