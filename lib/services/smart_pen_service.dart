import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:ffi/ffi.dart' as ffi;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// Define the C function signatures
typedef ComputeFeaturesC = Pointer<Float> Function(
  Pointer<Float> x,
  Pointer<Float> y,
  Pointer<Float> pressure,
  Pointer<Float> azimuth,
  Pointer<Float> altitude,
  Pointer<Float> accX,
  Pointer<Float> accY,
  Int32 nSamples,
  Pointer<Int32> outSize,
);

typedef ComputeFeaturesDart = Pointer<Float> Function(
  Pointer<Float> x,
  Pointer<Float> y,
  Pointer<Float> pressure,
  Pointer<Float> azimuth,
  Pointer<Float> altitude,
  Pointer<Float> accX,
  Pointer<Float> accY,
  int nSamples,
  Pointer<Int32> outSize,
);

typedef FreeFeaturesC = Void Function(Pointer<Float> ptr);
typedef FreeFeaturesDart = void Function(Pointer<Float> ptr);

typedef SmartPenFeaturesVersionC = Pointer<ffi.Utf8> Function();
typedef SmartPenFeaturesVersionDart = Pointer<ffi.Utf8> Function();

typedef SmartPenFeaturesLastErrorC = Pointer<ffi.Utf8> Function();
typedef SmartPenFeaturesLastErrorDart = Pointer<ffi.Utf8> Function();

typedef ComputeStatisticalSingleC = Void Function(
  Pointer<Float> signal,
  Int32 n,
  Pointer<Float> out,
);
typedef ComputeStatisticalSingleDart = void Function(
  Pointer<Float> signal,
  int n,
  Pointer<Float> out,
);

typedef ComputeButtonStatusC = Void Function(
  Pointer<Float> pressure,
  Int32 n,
  Pointer<Uint8> out,
);
typedef ComputeButtonStatusDart = void Function(
  Pointer<Float> pressure,
  int n,
  Pointer<Uint8> out,
);

class SmartPenService {
  static const String libraryName = 'libSmartPen.so';
  static const int penFeaturesCount = 354;
  static const int penStatisticsCount = 11;
  static const double penSamplingRate = 150.0;
  static const double penDt = 1.0 / 150.0;
  static const int penMinSamples = 150;
  static const double penPressureThreshold = 0.05;

  late DynamicLibrary _library;

  late ComputeFeaturesDart _computeFeatures;
  late FreeFeaturesDart _freeFeatures;
  late SmartPenFeaturesVersionDart _version;
  late SmartPenFeaturesLastErrorDart _lastError;
  late ComputeStatisticalSingleDart _computeStatisticalSingle;
  late ComputeButtonStatusDart _computeButtonStatus;

  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'SmartPenService currently supports Android only. '
        'Use a valid Android .so library or run mock mode when testing on other platforms.',
      );
    }

    // Load the shared library directly from JNI libs
    _library = DynamicLibrary.open('libSmartPen.so');

    // Bind functions
    _computeFeatures = _library.lookupFunction<ComputeFeaturesC, ComputeFeaturesDart>('compute_features');
    _freeFeatures = _library.lookupFunction<FreeFeaturesC, FreeFeaturesDart>('free_features');
    _version = _library.lookupFunction<SmartPenFeaturesVersionC, SmartPenFeaturesVersionDart>('SmartPen_features_version');
    _lastError = _library.lookupFunction<SmartPenFeaturesLastErrorC, SmartPenFeaturesLastErrorDart>('SmartPen_features_last_error');
    _computeStatisticalSingle = _library.lookupFunction<ComputeStatisticalSingleC, ComputeStatisticalSingleDart>('compute_statistical_single');
    _computeButtonStatus = _library.lookupFunction<ComputeButtonStatusC, ComputeButtonStatusDart>('compute_button_status');
  }

  /// Computes the 354 features from the sensor data.
  /// @param x List of x coordinates from PMW3901
  /// @param y List of y coordinates from PMW3901
  /// @param pressure List of pressure values from FSR
  /// @param azimuth List of azimuth values from MPU6050
  /// @param altitude List of altitude values from MPU6050
  /// @param accX List of accelerometer x values from MPU6050
  /// @param accY List of accelerometer y values from MPU6050
  /// @return List of 354 float features, or null if error
  List<double>? computeFeatures({
    required List<double> x,
    required List<double> y,
    required List<double> pressure,
    required List<double> azimuth,
    required List<double> altitude,
    required List<double> accX,
    required List<double> accY,
  }) {
    if (x.length != y.length ||
        x.length != pressure.length ||
        x.length != azimuth.length ||
        x.length != altitude.length ||
        x.length != accX.length ||
        x.length != accY.length) {
      throw ArgumentError('All input lists must have the same length');
    }

    final nSamples = x.length;
    if (nSamples < penMinSamples) {
      throw ArgumentError('Minimum $penMinSamples samples required');
    }

    // Allocate native arrays
    final xPtr = _allocateFloatArray(x);
    final yPtr = _allocateFloatArray(y);
    final pressurePtr = _allocateFloatArray(pressure);
    final azimuthPtr = _allocateFloatArray(azimuth);
    final altitudePtr = _allocateFloatArray(altitude);
    final accXPtr = _allocateFloatArray(accX);
    final accYPtr = _allocateFloatArray(accY);
    final outSizePtr = ffi.calloc<Int32>();

    try {
      final resultPtr = _computeFeatures(
        xPtr,
        yPtr,
        pressurePtr,
        azimuthPtr,
        altitudePtr,
        accXPtr,
        accYPtr,
        nSamples,
        outSizePtr,
      );

      if (resultPtr == nullptr) {
        return null; // Error
      }

      final outSize = outSizePtr.value;
      final features = <double>[];
      for (int i = 0; i < outSize; i++) {
        features.add(resultPtr[i]);
      }

      _freeFeatures(resultPtr);
      return features;
    } finally {
      // Free allocated memory
      ffi.calloc.free(xPtr);
      ffi.calloc.free(yPtr);
      ffi.calloc.free(pressurePtr);
      ffi.calloc.free(azimuthPtr);
      ffi.calloc.free(altitudePtr);
      ffi.calloc.free(accXPtr);
      ffi.calloc.free(accYPtr);
      ffi.calloc.free(outSizePtr);
    }
  }

  /// Frees the features array returned by computeFeatures.
  /// Note: In Dart, we handle this internally, but this is exposed for completeness.
  void freeFeatures(Pointer<Float> ptr) {
    _freeFeatures(ptr);
  }

  /// Gets the version of the SmartPen features library.
  /// @return Version string
  String getVersion() {
    final ptr = _version();
    final version = ptr.toDartString();
    ffi.calloc.free(ptr);
    return version;
  }

  /// Gets the last error message from the library.
  /// @return Error message string
  String getLastError() {
    final ptr = _lastError();
    final error = ptr.toDartString();
    ffi.calloc.free(ptr);
    return error;
  }

  /// Computes 11 statistical values for a single signal.
  /// @param signal List of float values
  /// @return List of 11 statistical values (max, min, mean, median, etc.)
  List<double> computeStatisticalSingle(List<double> signal) {
    final signalPtr = _allocateFloatArray(signal);
    final outPtr = ffi.calloc<Float>(penStatisticsCount);

    try {
      _computeStatisticalSingle(signalPtr, signal.length, outPtr);

      final stats = <double>[];
      for (int i = 0; i < penStatisticsCount; i++) {
        stats.add(outPtr[i]);
      }
      return stats;
    } finally {
      ffi.calloc.free(signalPtr);
      ffi.calloc.free(outPtr);
    }
  }

  /// Computes button status from pressure data.
  /// @param pressure List of pressure values
  /// @return List of button status values
  List<int> computeButtonStatus(List<double> pressure) {
    final pressurePtr = _allocateFloatArray(pressure);
    final outPtr = ffi.calloc<Uint8>(pressure.length);

    try {
      _computeButtonStatus(pressurePtr, pressure.length, outPtr);

      final status = <int>[];
      for (int i = 0; i < pressure.length; i++) {
        status.add(outPtr[i]);
      }
      return status;
    } finally {
      ffi.calloc.free(pressurePtr);
      ffi.calloc.free(outPtr);
    }
  }

  /// Generates mock data for testing.
  /// @param nSamples Number of samples to generate
  /// @return Map with mock sensor data
  Map<String, List<double>> generateMockData(int nSamples) {
    final random = Random();
    return {
      'x': List.generate(nSamples, (_) => random.nextDouble() * 100),
      'y': List.generate(nSamples, (_) => random.nextDouble() * 100),
      'pressure': List.generate(nSamples, (_) => random.nextDouble()),
      'azimuth': List.generate(nSamples, (_) => random.nextDouble() * 360),
      'altitude': List.generate(nSamples, (_) => random.nextDouble() * 90),
      'accX': List.generate(nSamples, (_) => (random.nextDouble() - 0.5) * 20),
      'accY': List.generate(nSamples, (_) => (random.nextDouble() - 0.5) * 20),
    };
  }

  Pointer<Float> _allocateFloatArray(List<double> data) {
    final ptr = ffi.calloc<Float>(data.length);
    for (int i = 0; i < data.length; i++) {
      ptr[i] = data[i];
    }
    return ptr;
  }
}