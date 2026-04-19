import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final handwritingViewModelProvider = NotifierProvider<HandwritingViewModel, HandwritingState>(
  HandwritingViewModel.new,
);

class HandwritingState {
  final bool isProcessing;
  final bool isSpiralDetected;
  final bool isCapturing;
  final String? capturedFilePath;
  final Uint8List? overlayBytes;

  const HandwritingState({
    this.isProcessing = false,
    this.isSpiralDetected = false,
    this.isCapturing = false,
    this.capturedFilePath,
    this.overlayBytes,
  });

  HandwritingState copyWith({
    bool? isProcessing,
    bool? isSpiralDetected,
    bool? isCapturing,
    String? capturedFilePath,
    Uint8List? overlayBytes,
  }) {
    return HandwritingState(
      isProcessing: isProcessing ?? this.isProcessing,
      isSpiralDetected: isSpiralDetected ?? this.isSpiralDetected,
      isCapturing: isCapturing ?? this.isCapturing,
      capturedFilePath: capturedFilePath ?? this.capturedFilePath,
      overlayBytes: overlayBytes ?? this.overlayBytes,
    );
  }
}

class HandwritingViewModel extends Notifier<HandwritingState> {
  @override
  HandwritingState build() {
    return const HandwritingState();
  }

  void setProcessing(bool value) {
    state = state.copyWith(isProcessing: value);
  }

  void setSpiralDetected(bool value) {
    state = state.copyWith(isSpiralDetected: value);
  }

  void setCapturing(bool value) {
    state = state.copyWith(isCapturing: value);
  }

  void setCapturedFilePath(String? path) {
    state = state.copyWith(capturedFilePath: path);
  }

  void setOverlayBytes(Uint8List? bytes) {
    state = state.copyWith(overlayBytes: bytes);
  }
}
