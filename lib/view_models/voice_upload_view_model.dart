import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_response.dart';
import '../services/api.dart';

final voiceUploadViewModelProvider = AsyncNotifierProvider<VoiceUploadViewModel, Response?>(
  VoiceUploadViewModel.new,
);

class VoiceUploadViewModel extends AsyncNotifier<Response?> {
  @override
  Future<Response?> build() async {
    return null;
  }

  Future<void> upload({
    required String path,
    required Future<Response> Function(String path) uploadFunction,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      if (kIsWeb) {
        return Response(
          status: JobStatus.success,
          prediction: 'Demo result',
          confidence: 0.9,
        );
      }

      return await uploadFunction(path);
    });
  }
}
