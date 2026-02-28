import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import './../services/api.dart';

enum JobStatus {
  success, // 0
  error, // 1
}

class Response {
  final JobStatus status;
  final String? prediction;
  final double? confidence;
  final String? message;

  Response({
    required this.status,
    this.prediction,
    this.confidence,
    this.message,
  });

  @override
  String toString() {
    switch (status) {
      case JobStatus.success:
        return "the results are \r\n "
            "Prediction: $prediction \r\n"
            "Confidence: $confidence \r\n";
      case JobStatus
          .error: // this will not occuire since we will go back to the send voice screen instead of here
        return "error happened \r\n "
            "Error: $message \r\n";

    }
  }

  factory Response.fromJson(Map<String, dynamic> json) {
    return Response(
      status: switch (json['status']) {
        'success' => JobStatus.success,
        'error' => JobStatus.error,
        _ => JobStatus.error,
      },
      prediction: json['label'] as String?,
      confidence: (json['probability'] as num?)?.toDouble(),
      message: json['message'] as String?,
    );
  }
}

final fileUploadProvider =
AsyncNotifierProvider<FileUploadNotifier, Response?>(FileUploadNotifier.new);

class FileUploadNotifier extends AsyncNotifier<Response?> {
  @override
  Future<Response?> build() async {
    return null; // idle
  }

  /// Generic upload function
  Future<void> upload({
    required String path,
    required Future<Response> Function(String path) uploadFunction,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      if (kIsWeb) {
        return Response(
          status: JobStatus.success,
          prediction: "Demo result",
          confidence: 0.9,
        );
      }

      // Call the API-specific upload function
      final parsedResponse = await uploadFunction(path);

      return parsedResponse;
    });
  }
}
