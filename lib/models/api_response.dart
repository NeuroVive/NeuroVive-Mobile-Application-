import 'package:flutter/foundation.dart';

enum JobStatus {
  success,
  error,
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
      case JobStatus.error:
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
