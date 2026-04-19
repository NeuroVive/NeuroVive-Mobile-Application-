import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/smart_pen_service.dart';

final smartPenServiceProvider = Provider<SmartPenService>((ref) {
  return SmartPenService();
});

class SmartPenState {
  final bool isInitialized;
  final bool isLoading;
  final bool isComputing;
  final List<double>? features;
  final List<double>? statistics;
  final List<int>? buttonStatus;
  final String? error;

  const SmartPenState({
    this.isInitialized = false,
    this.isLoading = false,
    this.isComputing = false,
    this.features,
    this.statistics,
    this.buttonStatus,
    this.error,
  });

  SmartPenState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isComputing,
    List<double>? features,
    List<double>? statistics,
    List<int>? buttonStatus,
    String? error,
  }) {
    return SmartPenState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isComputing: isComputing ?? this.isComputing,
      features: features ?? this.features,
      statistics: statistics ?? this.statistics,
      buttonStatus: buttonStatus ?? this.buttonStatus,
      error: error ?? this.error,
    );
  }
}

class SmartPenViewModel extends Notifier<SmartPenState> {
  late SmartPenService _service;

  @override
  SmartPenState build() {
    _service = ref.watch(smartPenServiceProvider);
    return const SmartPenState();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.initialize();
      state = state.copyWith(isInitialized: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> computeFeatures({
    required List<double> x,
    required List<double> y,
    required List<double> pressure,
    required List<double> azimuth,
    required List<double> altitude,
    required List<double> accX,
    required List<double> accY,
  }) async {
    if (!state.isInitialized) {
      await initialize();
    }

    state = state.copyWith(isComputing: true, error: null);

    try {
      final features = _service.computeFeatures(
        x: x,
        y: y,
        pressure: pressure,
        azimuth: azimuth,
        altitude: altitude,
        accX: accX,
        accY: accY,
      );

      if (features != null) {
        state = state.copyWith(features: features, isComputing: false);
      } else {
        state = state.copyWith(error: _service.getLastError(), isComputing: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isComputing: false);
    }
  }

  Future<void> computeFeaturesWithMockData(int nSamples) async {
    final mockData = _service.generateMockData(nSamples);
    await computeFeatures(
      x: mockData['x']!,
      y: mockData['y']!,
      pressure: mockData['pressure']!,
      azimuth: mockData['azimuth']!,
      altitude: mockData['altitude']!,
      accX: mockData['accX']!,
      accY: mockData['accY']!,
    );
  }

  void computeStatistics(List<double> signal) {
    final stats = _service.computeStatisticalSingle(signal);
    state = state.copyWith(statistics: stats);
  }

  void computeButtonStatus(List<double> pressure) {
    final status = _service.computeButtonStatus(pressure);
    state = state.copyWith(buttonStatus: status);
  }

  void reset() {
    state = const SmartPenState();
  }
}

final smartPenViewModelProvider = NotifierProvider<SmartPenViewModel, SmartPenState>(
  SmartPenViewModel.new,
);
