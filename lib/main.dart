import 'package:neurovive/screens/land_screen.dart';
import 'package:neurovive/screens/result_screen.dart';
import 'package:neurovive/screens/send_voice_screen.dart';
import 'package:neurovive/themes/main_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import './utils.dart';
import './screens/handwriting_screen.dart';
import './screens/record_screen2.dart';
import 'icons/neurovive_icons.dart';
import 'l10n/app_localizations.dart';
import 'notifiers/voice_upload_notifier.dart';

//router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      return null;
    },

    routes: [
      ShellRoute(
        builder: (context, state, child) {
          String routeName = state.topRoute?.path ?? '';
          final String pageName = state.topRoute?.name ?? ///todo: EID, add a switch statement here to make the names of the pages use the localization
              AppLocalizations.of(context)!.noNameError;
          final String currentPath = state.uri.path
              .split('?')
              .first;


          ThemeData theme = switch (routeName) {
            '/voice' => Mainthemes.greenBackgroundTheme,
            '/handwriting' => Mainthemes.blueBackgroundTheme,
            _ => Mainthemes.whiteBackgroundTheme,
          };

          ref.listen<AsyncValue<bool>>(
            showHelpOnceProvider(currentPath),
                (_, next) {
              next.whenOrNull(
                data: (shouldShow) {
                  if (!shouldShow) return;

                  showCurrentInstructions(context, currentPath);
                },
              );
            },
          );


          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didpop,_) async{
              if(!didpop)
              {

                await handleBack(context);
              }

            },
            child: Theme(
              data: theme,
              child: Builder(
                builder: (context) {

                  return Scaffold(
                    backgroundColor: Theme
                        .of(context)
                        .scaffoldBackgroundColor,

                    appBar: AppBar(
                      elevation: 0,
                      leading: !(currentPath == '/' ||
                          currentPath == '/sendvoice' )

                          ? IconButton(
                        onPressed: () {
                         handleBack(context);
                        },
                        icon: Icon(Neurovive.arrow_left),
                        color: Theme
                            .of(context)
                            .colorScheme
                            .onPrimary,
                      )
                          : const SizedBox.shrink(),

                      title: Text(
                        pageName == '#' ? "" : pageName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Theme
                              .of(context)
                              .colorScheme
                              .onPrimary,
                        ),
                      ),
                      centerTitle: true,
                      actions: [
                        (currentPath == '/voice' || currentPath == '/handwriting')

                        /// later u will add the pages that has instructions for them here
                            ?
                        IconButton(
                          icon: Icon(
                            Neurovive.info,
                            color: Theme
                                .of(context)
                                .colorScheme
                                .onPrimary,
                            size: 30,
                          ),
                          onPressed: () {
                            showCurrentInstructions(context, currentPath);
                          },
                        ) : const SizedBox.shrink(),
                      ],
                    ),

                    body: child,
                  );
                },
              ),
            ),
          );
        },

        routes: [
          GoRoute(
            path: '/',
            name: 'NeuroVive',
            pageBuilder: (context, state) =>
                CustomTransitionPage(
                  key: state.pageKey,
                  child: const LandScreen(),
                  transitionDuration: const Duration(milliseconds: 10),
                  reverseTransitionDuration: const Duration(milliseconds: 10),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: Tween<double>(
                        begin: 1,
                        end: 0,
                      ).animate(secondaryAnimation),
                      child: child,
                    );
                  },
                ),
          ),
          GoRoute(
            path: '/voice',
            name: 'Voice Record',
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const RecordScreen2(),
                transitionDuration: const Duration(milliseconds: 10),
                // Hero duration
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              );
            },
          ),
          GoRoute(
            path: '/handwriting',
            name: 'Handwriting Test',
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const LiveShapeDetectionScreen(),
                transitionDuration: const Duration(milliseconds: 10),
                // Hero duration
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              );
            },
          ),
          GoRoute(
            path: '/sendvoice',
            name: '#',
            builder: (context, state) {
              // Ensure extra is not null and has the correct type
              final extra = state.extra;
              if (extra is! (String, FileType)) {
                throw Exception('Expected a (String, FileType) tuple in state.extra');
              }

              final (filePath, type) = extra; // destructure tuple
              return SendVoiceScreen(filePath: filePath, type: type);
            },
          ),
          GoRoute(
              path: '/results',
              name: 'Medical Report',
              builder: (context, state) {
                final results = state.extra as Response;
                return  ResultScreen(result: results);

              })
        ],
      ),


    ],
    errorBuilder: (context, state) => const Placeholder(),
  );
});


//language provider
final localProvider = StateProvider<Locale>((ref) {
  return const Locale('en');
});


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    // DeviceOrientation.portraitDown, // include this if you want upside-down allowed
  ]);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localProvider);
    return MaterialApp.router(
      theme: ThemeData(
        fontFamily: 'Roboto', // Set as default font
      ),
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}


