
// Helper function to build help instructions bottom sheet
import 'dart:io';

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