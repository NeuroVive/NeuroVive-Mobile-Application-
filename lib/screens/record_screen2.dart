import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurovive/screens/send_voice_screen.dart';

import '../icons/neurovive_icons.dart';
import '../l10n/app_localizations.dart';
import '../services/audio_recorder.dart';
import '../utils.dart';
import '../widgets/mic_button.dart';

class RecordScreen2 extends ConsumerStatefulWidget {
  const RecordScreen2({super.key});

  @override
  ConsumerState<RecordScreen2> createState() => _RecordScreen2State();
}

class _RecordScreen2State extends ConsumerState<RecordScreen2> {
  bool isRecording = false;
  bool isPaused = false;
  bool doneRecording = false;

  /// true when the user is recording for the first letter, and false for when they are recording for the second letter
  bool isFirstPhase = true;

  ///max seconds for each phase
  int maxSeconds = 3;

  ///changes from 3 to 6 when the user finishes recording the first letter
  int currentMaxSeconds = 3;
  int seconds = 0;
  Timer? _timer;
  String? filePath;

  //initializing the record service
  final AudioRecorderService recorder = AudioRecorderService();

  void startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        seconds = recorder.getDuration();
      });
      if (seconds >= currentMaxSeconds && isRecording && !isPaused) {
        if (isFirstPhase) {
          toggleRecording();
          isFirstPhase = false;
          currentMaxSeconds += maxSeconds;
        } else {
          stopRecording();
        }
      }
    });
  }

  void toggleRecording() async {
    if (!isRecording) {
      startRecording();
      return;
    }

    if (!isPaused) {
      if (!await recorder.pauseRecording()) {
        return;
      }
        stopTimer();

    } else {

      if (! await recorder.resumeRecording()){
        return;
      }
      startTimer();
    }

    setState(() {
      isPaused = !isPaused;
    });
  }

  void stopRecording() async {
    if (!isRecording) {
      return;
    }
    stopTimer();

    // stoping the record and saving it
    filePath = await recorder.stopRecording();

    setState(() {
      isRecording = false;
      isPaused = false;
      doneRecording = true;
    });

    // displaying the saved file path
    // ScaffoldMessenger.of(
    //   context,
    // ).showSnackBar(SnackBar(content: Text("Saved: $filePath")));
  }

  void cancelRecording() async {
    stopTimer();

    await recorder.stopRecording();

    setState(() {
      isRecording = false;
      isPaused = false;
      seconds = 0;
      doneRecording = false;
      currentMaxSeconds = maxSeconds;
      isFirstPhase = true;
    });
  }

  Future<void> startRecording() async {
    if(kIsWeb) // for testing only
      {
      filePath= "fake path";
        submitVoice();
      }
    if (isRecording) return;

    try {
      await recorder.startRecording();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedRecording),
        ),
      );
      return;
    }

    setState(() {
      isRecording = true;
      currentMaxSeconds = maxSeconds;
      isFirstPhase = true;
      isPaused = false;
      seconds = 0;
    });

    startTimer();
  }

  void submitVoice() {
    context.go('/sendvoice', extra: (filePath,FileType.voice));
  }

  void stopTimer() {
    _timer?.cancel();
  }

  String formatTime(int totalSeconds) {
    return "${totalSeconds.toString().padLeft(2, '0')}/${currentMaxSeconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
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
              amplitudeStream: recorder.amplitudeStream,
              isRecording: isRecording,
              onTap: null,
            ),

            const SizedBox(height: 5),

            Text(
              formatTime(seconds),
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: Divider(color: Colors.white, thickness: 1),
              ),
            ),
            SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.recordOrder,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            Text(
              isFirstPhase ? AppLocalizations.of(context)!.toneA : AppLocalizations.of(context)!.toneO,
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 93, 245, 225),
              ),
            ),
            SizedBox(height: 10),

            Column(
              children: [
                const SizedBox(height: 25),

                Stack(
                  alignment: AlignmentGeometry.center,
                  children: [
                    if (isRecording || doneRecording)
                      Container(
                        height: 90,
                        width: MediaQuery.of(context).size.width * 0.89,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          shape: BoxShape.rectangle,
                          color: Colors.white,
                        ),
                      ),
                    if (isRecording || doneRecording)
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.1,
                        child: Container(
                          //cancel
                          height: 50,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,

                            color: Color.fromARGB(255, 187, 70, 72),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Neurovive.close,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              size: 15,
                            ),
                            onPressed: cancelRecording,
                          ),
                        ),
                      ),

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
