import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_recorder.dart';

final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService();
  ref.onDispose(service.dispose);
  return service;
});

final voiceRecordViewModelProvider = NotifierProvider<VoiceRecordViewModel, VoiceRecordState>(
  VoiceRecordViewModel.new,
);

class VoiceRecordState {
  final bool isRecording;
  final bool isPaused;
  final bool doneRecording;
  final bool isFirstPhase;
  final int maxSeconds;
  final int currentMaxSeconds;
  final int seconds;
  final String? filePath;
  final String? error;

  const VoiceRecordState({
    this.isRecording = false,
    this.isPaused = false,
    this.doneRecording = false,
    this.isFirstPhase = true,
    this.maxSeconds = 3,
    this.currentMaxSeconds = 3,
    this.seconds = 0,
    this.filePath,
    this.error,
  });

  VoiceRecordState copyWith({
    bool? isRecording,
    bool? isPaused,
    bool? doneRecording,
    bool? isFirstPhase,
    int? maxSeconds,
    int? currentMaxSeconds,
    int? seconds,
    String? filePath,
    String? error,
  }) {
    return VoiceRecordState(
      isRecording: isRecording ?? this.isRecording,
      isPaused: isPaused ?? this.isPaused,
      doneRecording: doneRecording ?? this.doneRecording,
      isFirstPhase: isFirstPhase ?? this.isFirstPhase,
      maxSeconds: maxSeconds ?? this.maxSeconds,
      currentMaxSeconds: currentMaxSeconds ?? this.currentMaxSeconds,
      seconds: seconds ?? this.seconds,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
    );
  }
}

class VoiceRecordViewModel extends Notifier<VoiceRecordState> {
  late final AudioRecorderService _recorder;
  Timer? _timer;

  Stream<double> get amplitudeStream => _recorder.amplitudeStream;

  @override
  VoiceRecordState build() {
    _recorder = ref.watch(audioRecorderServiceProvider);
    return const VoiceRecordState();
  }

  Future<void> _startTimer() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!state.isRecording || state.isPaused) return;
      final elapsed = _recorder.getDuration();
      if (elapsed >= state.currentMaxSeconds) {
        if (state.isFirstPhase) {
          final paused = await pauseRecording();
          if (paused) {
            state = state.copyWith(
              isFirstPhase: false,
              currentMaxSeconds: state.currentMaxSeconds + state.maxSeconds,
              seconds: elapsed,
            );
          }
        } else {
          await stopRecording();
        }
      } else {
        state = state.copyWith(seconds: elapsed);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> startRecording() async {
    if (state.isRecording) return;

    if (kIsWeb) {
      state = state.copyWith(
        isRecording: false,
        filePath: 'fake path',
        doneRecording: true,
        isPaused: false,
      );
      return;
    }

    try {
      await _recorder.startRecording();
      state = state.copyWith(
        isRecording: true,
        isPaused: false,
        doneRecording: false,
        isFirstPhase: true,
        currentMaxSeconds: state.maxSeconds,
        seconds: 0,
        error: null,
      );
      await _startTimer();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleRecording() async {
    if (!state.isRecording) {
      await startRecording();
      return;
    }

    if (!state.isPaused) {
      final paused = await pauseRecording();
      if (paused) {
        _stopTimer();
        state = state.copyWith(isPaused: true);
      }
      return;
    }

    final resumed = await resumeRecording();
    if (resumed) {
      state = state.copyWith(isPaused: false);
      await _startTimer();
    }
  }

  Future<bool> pauseRecording() async {
    return await _recorder.pauseRecording();
  }

  Future<bool> resumeRecording() async {
    if (await _recorder.isRecording() && await _recorder.isPaused()) {
      return await _recorder.resumeRecording();
    }
    return false;
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    _stopTimer();
    final path = await _recorder.stopRecording();
    state = state.copyWith(
      isRecording: false,
      isPaused: false,
      doneRecording: true,
      filePath: path,
      seconds: _recorder.getDuration(),
    );
  }

  Future<void> cancelRecording() async {
    _stopTimer();
    await _recorder.stopRecording();
    state = const VoiceRecordState();
  }

  void reset() {
    _stopTimer();
    state = const VoiceRecordState();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
