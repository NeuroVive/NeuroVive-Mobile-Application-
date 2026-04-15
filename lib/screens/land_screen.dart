import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../utils.dart';
import '../widgets/animated_text_button.dart';

class LandScreen extends ConsumerWidget {
  const LandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didpop,_) async{
        if(!didpop)
        {

          await handleBack(context);
        }

      },
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Placeholder(),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AnimatedTextButton(
                    normalColor: Theme.of(context).colorScheme.onSecondary,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    onPressed: () {
                      context.push('/voice');
                    },
                    text: "Voice",
                  ),
                  AnimatedTextButton(
                    normalColor: Theme.of(context).colorScheme.onSecondary,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    onPressed: () {
                      context.push('/handwriting');
                    },
                    text: "hand writing",
                  ),
                  AnimatedTextButton(
                    normalColor: Theme.of(context).colorScheme.onSecondary,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    onPressed: () {
                      context.push('/pen');
                    },
                    text: "pen",
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
