import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';
import '../services/bluetooth_service.dart';
import '../view_models/smart_pen_view_model.dart';
import '../app_constants.dart';

final bluetoothServiceProvider = Provider<BluetoothSensorService>((ref) {
  final service = BluetoothSensorService();
  ref.onDispose(service.dispose);
  return service;
});

final bluetoothConnectionViewModelProvider = NotifierProvider<BluetoothConnectionViewModel, BluetoothConnectionViewState>(
  BluetoothConnectionViewModel.new,
);

class BluetoothConnectionViewState {
  final bool isInitialized;
  final bool isCheckingConnection;
  final List<BleDevice> discoveredDevices;

  const BluetoothConnectionViewState({
    this.isInitialized = false,
    this.isCheckingConnection = true,
    this.discoveredDevices = const [],
  });

  BluetoothConnectionViewState copyWith({
    bool? isInitialized,
    bool? isCheckingConnection,
    List<BleDevice>? discoveredDevices,
  }) {
    return BluetoothConnectionViewState(
      isInitialized: isInitialized ?? this.isInitialized,
      isCheckingConnection: isCheckingConnection ?? this.isCheckingConnection,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
    );
  }
}

class BluetoothConnectionViewModel extends Notifier<BluetoothConnectionViewState> {
  late final BluetoothSensorService _service;
  StreamSubscription<BleDevice>? _scanSubscription;

  @override
  BluetoothConnectionViewState build() {
    _service = ref.watch(bluetoothServiceProvider);
    return const BluetoothConnectionViewState();
  }

  Future<void> initialize() async {
    state = state.copyWith(isCheckingConnection: true);
    await _service.initialize();
    await _checkExistingConnection();
    if (!AppConstants.useRealApplication) {
      await ref.read(smartPenViewModelProvider.notifier).initialize();
    }
    state = state.copyWith(isInitialized: true, isCheckingConnection: false);
  }

  Future<void> _checkExistingConnection() async {
    if (_service.connectedDevice == null) {
      return;
    }
    try {
      final isConnected = await _service.isDeviceConnected();
      if (!isConnected) {
        await _service.disconnect();
      }
    } catch (_) {
      await _service.disconnect();
    }
  }

  void _listenScanResults() {
    _scanSubscription?.cancel();
    _scanSubscription = _service.scanResults.listen((device) {
      if (!state.discoveredDevices.any((d) => d.deviceId == device.deviceId)) {
        state = state.copyWith(
          discoveredDevices: [...state.discoveredDevices, device],
        );
      }
    });
  }

  Future<void> startScan() async {
    _scanSubscription?.cancel();
    state = state.copyWith(discoveredDevices: []);
    _listenScanResults();
    await _service.startScan();
  }

  Future<void> stopScan() async {
    await _service.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  Future<void> connectToDevice(BleDevice device) async {
    await _service.connectToDevice(device);
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    state = state.copyWith(discoveredDevices: []);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}
