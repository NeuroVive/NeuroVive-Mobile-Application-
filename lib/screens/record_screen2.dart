import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurovive/screens/send_voice_screen.dart';

import '../icons/neurovive_icons.dart';
import '../l10n/app_localizations.dart';
import '../utils.dart';
import '../view_models/voice_record_view_model.dart';
import '../widgets/mic_button.dart';

class RecordScreen2 extends ConsumerWidget {
  const RecordScreen2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceRecordViewModelProvider);
    final viewModel = ref.read(voiceRecordViewModelProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didpop, _) async {
        if (!didpop) {
          await handleBack(context);
        }
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MicButton(
              amplitudeStream: viewModel.amplitudeStream,
              isRecording: state.isRecording,
              onTap: () => viewModel.toggleRecording(),
            ),
            const SizedBox(height: 5),
            Text(
              '${state.seconds.toString().padLeft(2, '0')}/${state.currentMaxSeconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: const Divider(color: Colors.white, thickness: 1),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.recordOrder,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              state.isFirstPhase
                  ? AppLocalizations.of(context)!.toneA
                  : AppLocalizations.of(context)!.toneO,
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 93, 245, 225),
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                const SizedBox(height: 25),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (state.isRecording || state.doneRecording)
                      Container(
                        height: 90,
                        width: MediaQuery.of(context).size.width * 0.89,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: Colors.white,
                        ),
                      ),
                    if (state.isRecording || state.doneRecording)
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.1,
                        child: Container(
                          height: 50,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.fromARGB(255, 187, 70, 72),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Neurovive.close,
                              color: Colors.white,
                              size: 15,
                            ),
                            onPressed: () async {
                              await viewModel.cancelRecording();
                            },
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (state.isPaused || (!state.isRecording && !state.doneRecording))
                              ? const Color.fromARGB(255, 187, 70, 72)
                              : (!state.doneRecording
                                  ? const Color.fromARGB(255, 34, 75, 68)
                                  : Colors.grey),
                        ),
                        child: IconButton(
                          icon: Icon(
                            (state.isPaused || state.doneRecording || !state.isRecording)
                                ? Icons.play_arrow_rounded
                                : Icons.pause,
                            color: Colors.white,
                            size: 55,
                          ),
                          onPressed: state.doneRecording ? null : () => viewModel.toggleRecording(),
                        ),
                      ),
                    ),
                    if (state.isRecording || state.doneRecording)
                      Positioned(
                        right: MediaQuery.of(context).size.width * 0.1,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: state.doneRecording
                                ? const Color.fromARGB(255, 106, 210, 196)
                                : Colors.grey,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: state.doneRecording
                                ? () {
                                    if (state.filePath != null) {
                                      context.go('/sendvoice', extra: (state.filePath, FileType.voice));
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

                    //  Pause /  Resume
                    Container(
                      padding: EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (isPaused ||
                                  (!isRecording &&
                                      !doneRecording)) // if not recording and didnt finish recording that means we didnt start recording yet, so the color be red
                              ? Color.fromARGB(255, 187, 70, 72)
                              : (!doneRecording
                                    ? Color.fromARGB(255, 34, 75, 68)
                                    : Colors.grey),
                        ),
                        child: IconButton(
                          icon: Icon(
                            (isPaused || doneRecording || !isRecording)
                                ? Icons.play_arrow_rounded
                                : Icons.pause,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            size: 55,
                          ),
                          onPressed: doneRecording ? null : toggleRecording,
                        ),
                      ),
                    ),

                    //  submit
                    if (isRecording || doneRecording)
                      Positioned(
                        right: MediaQuery.of(context).size.width * 0.1,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: doneRecording
                                ? Color.fromARGB(255, 106, 210, 196)
                                : Colors.grey,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.check,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              size: 30,
                            ),
                            onPressed: doneRecording
                                ? submitVoice
                                : null, // only enable when the user finishes all the recording
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    recorder.stopRecording();
    _timer?.cancel();
    super.dispose();
  }
}
