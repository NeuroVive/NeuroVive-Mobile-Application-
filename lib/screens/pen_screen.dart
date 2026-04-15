import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';
import '../services/bluetooth_service.dart';
import '../app_constants.dart';
import '../notifiers/smart_pen_notifier.dart';

// Providers
final bluetoothServiceProvider = Provider<BluetoothSensorService>((ref) {
  final service = BluetoothSensorService();
  ref.onDispose(() => service.dispose());
  return service;
});

final scanResultsProvider = StreamProvider<List<BleDevice>>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  final controller = StreamController<List<BleDevice>>();

  final subscription = service.scanResults.listen((device) {
    controller.add([device]); // You'll need to accumulate devices
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

final connectionStateProvider = StreamProvider<BluetoothConnectionState>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.connectionState;
});

final sensorPacketProvider = StreamProvider<SensorPacket?>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.packets.map((packet) => packet);
});

class BluetoothConnectionPage extends ConsumerStatefulWidget {
  const BluetoothConnectionPage({super.key});

  @override
  ConsumerState<BluetoothConnectionPage> createState() => _BluetoothConnectionPageState();
}

class _BluetoothConnectionPageState extends ConsumerState<BluetoothConnectionPage> {
  final List<BleDevice> _discoveredDevices = [];
  StreamSubscription? _scanSubscription;
  bool _isInitialized = false;
  bool _isCheckingConnection = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final service = ref.read(bluetoothServiceProvider);
    await service.initialize();

    // Check if there's an existing connection
    await _checkExistingConnection(service);

    // Initialize SmartPen service if not using real application
    if (!AppConstants.useRealApplication) {
      final smartPenNotifier = ref.read(smartPenNotifierProvider.notifier);
      await smartPenNotifier.initialize();
    }

    setState(() {
      _isInitialized = true;
      _isCheckingConnection = false;
    });
  }

  Future<void> _checkExistingConnection(BluetoothSensorService service) async {
    // Check if there's a connected device
    if (service.connectedDevice != null) {
      print('Found existing connection to: ${service.connectedDevice!.name}');

      // You might want to verify the connection is still active
      try {
        // Try to read a characteristic or check connection state
        final isConnected = await service.isDeviceConnected();
        if (!isConnected) {
          print('Connection is stale, disconnecting...');
          await service.disconnect();
        }
      } catch (e) {
        print('Error checking connection: $e');
        await service.disconnect();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final packetAsync = ref.watch(sensorPacketProvider);
    final service = ref.watch(bluetoothServiceProvider);
    final smartPenState = ref.watch(smartPenNotifierProvider);
    final smartPenNotifier = ref.read(smartPenNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Sensor Connection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (service.currentState == BluetoothConnectionState.connected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: () => _disconnect(service),
              tooltip: 'Disconnect',
            ),
          if (service.connectedDevice != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Connected: ${service.connectedDevice!.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBodyContent(
        connectionStateAsync,
        packetAsync,
        service,
        smartPenState,
        smartPenNotifier,
      ),
    );
  }

  Widget _buildBodyContent(
    AsyncValue<BluetoothConnectionState> connectionStateAsync,
    AsyncValue<SensorPacket?> packetAsync,
    BluetoothSensorService service,
    SmartPenState smartPenState,
    SmartPenNotifier smartPenNotifier,
  ) {
    if (_isCheckingConnection) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking existing connections...'),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildBody(
      connectionStateAsync,
      packetAsync,
      service,
      smartPenState,
      smartPenNotifier,
    );
  }

  Widget _buildBody(
      AsyncValue<BluetoothConnectionState> connectionStateAsync,
      AsyncValue<SensorPacket?> packetAsync,
      BluetoothSensorService service,
      SmartPenState smartPenState,
      SmartPenNotifier smartPenNotifier,
      ) {
    return connectionStateAsync.when(
      data: (state) {
        return Column(
          children: [
            _buildConnectionStatus(state, service),
            Expanded(
              child: _buildContentForState(state, packetAsync, service, smartPenState, smartPenNotifier),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildConnectionStatus(
      BluetoothConnectionState state,
      BluetoothSensorService service,
      ) {
    Color color;
    String text;
    IconData icon;

    switch (state) {
      case BluetoothConnectionState.connected:
        color = Colors.green;
        text = 'Connected';
        icon = Icons.bluetooth_connected;
        break;
      case BluetoothConnectionState.connecting:
        color = Colors.orange;
        text = 'Connecting...';
        icon = Icons.bluetooth_searching;
        break;
      case BluetoothConnectionState.scanning:
        color = Colors.blue;
        text = 'Scanning for devices...';
        icon = Icons.bluetooth_searching;
        break;
      case BluetoothConnectionState.error:
        color = Colors.red;
        text = service.errorMessage ?? 'Error';
        icon = Icons.error;
        break;
      case BluetoothConnectionState.disconnected:
      default:
        color = Colors.grey;
        text = 'Disconnected';
        icon = Icons.bluetooth_disabled;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: color.withOpacity(0.1),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (service.connectedDevice != null)
                  Text(
                    'Device: ${service.connectedDevice!.name}',
                    style: TextStyle(color: color.withOpacity(0.8)),
                  ),
              ],
            ),
          ),
          if (state == BluetoothConnectionState.disconnected)
            ElevatedButton(
              onPressed: () => _startScan(service),
              child: const Text('Scan'),
            ),
          if (state == BluetoothConnectionState.scanning)
            ElevatedButton(
              onPressed: () => service.stopScan(),
              child: const Text('Stop'),
            ),
        ],
      ),
    );
  }

  Widget _buildContentForState(
      BluetoothConnectionState state,
      AsyncValue<SensorPacket?> packetAsync,
      BluetoothSensorService service,
      SmartPenState smartPenState,
      SmartPenNotifier smartPenNotifier,
      ) {
    // If not using real application, show mock connected view
    if (!AppConstants.useRealApplication) {
      return _buildMockConnectedView(smartPenState, smartPenNotifier);
    }

    // If we're already connected, show the connected view regardless of state
    if (service.connectedDevice != null) {
      return _buildConnectedView(packetAsync, smartPenState, smartPenNotifier);
    }

    switch (state) {
      case BluetoothConnectionState.scanning:
        return _buildScanningView(service);
      case BluetoothConnectionState.connected:
        return _buildConnectedView(packetAsync, smartPenState, smartPenNotifier);
      case BluetoothConnectionState.error:
        return _buildErrorView(service);
      case BluetoothConnectionState.disconnected:
      default:
        return _buildWelcomeView();
    }
  }

  Widget _buildWelcomeView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Device Connected',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Scan" to discover nearby devices',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningView(BluetoothSensorService service) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
        Expanded(
          child: StreamBuilder<BleDevice>(
            stream: service.scanResults,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final device = snapshot.data!;
                if (!_discoveredDevices.any((d) => d.deviceId == device.deviceId)) {
                  _discoveredDevices.add(device);
                }
              }

              if (_discoveredDevices.isEmpty) {
                return const Center(
                  child: Text('No devices found yet...'),
                );
              }

              return ListView.builder(
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(
                        device.name?.isNotEmpty == true
                            ? device.name!
                            : 'Unknown Device',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(device.deviceId),
                      trailing: ElevatedButton(
                        onPressed: () => _connectToDevice(service, device),
                        child: const Text('Connect'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedView(AsyncValue<SensorPacket?> packetAsync, SmartPenState smartPenState, SmartPenNotifier smartPenNotifier) {
    return packetAsync.when(
      data: (packet) {
        if (packet == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Waiting for sensor data...'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.sensors,
                      size: 60,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Packet #${packet.seqNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Packet Info Section
              _buildSectionHeader('Packet Information'),
              _buildDataCard('Packet Type', packet.packetType.toString()),
              _buildDataCard('Sequence Number', packet.seqNumber.toString()),
              _buildDataCard('Timestamp', '${packet.timestamp} ms'),
              _buildDataCard('Checksum', '0x${packet.checkSum.toRadixString(16).toUpperCase().padLeft(2, '0')}'),

              const SizedBox(height: 16),

              // Accelerometer Raw Data
              _buildSectionHeader('Raw Accelerometer'),
              _buildDataCard('Accel X', packet.axRaw.toString()),
              _buildDataCard('Accel Y', packet.ayRaw.toString()),
              _buildDataCard('Accel Z', packet.azRaw.toString()),

              const SizedBox(height: 16),

              // Gyroscope Raw Data
              _buildSectionHeader('Raw Gyroscope'),
              _buildDataCard('Gyro X', packet.gxRaw.toString()),
              _buildDataCard('Gyro Y', packet.gyRaw.toString()),
              _buildDataCard('Gyro Z', packet.gzRaw.toString()),

              const SizedBox(height: 16),

              // Orientation Data
              _buildSectionHeader('Orientation'),
              _buildDataCard('Pitch', '${packet.pitch}°'),
              _buildDataCard('Roll', '${packet.roll}°'),
              _buildDataCard('Altitude', '${packet.altitude} m'),

              const SizedBox(height: 16),

              // Force & Pressure
              _buildSectionHeader('Force & Pressure'),
              _buildDataCard('Jerk Magnitude', packet.jerkMag.toString()),
              _buildDataCard('Raw Pressure', packet.pressureRaw.toString()),
              _buildDataCard('Force', '${packet.forceGram} g'),

              const SizedBox(height: 16),

              // Pen State
              _buildSectionHeader('Pen State'),
              _buildDataCard('Pen State', _getPenStateString(packet.penState)),
              _buildDataCard('Lift Count', packet.liftCount.toString()),
              _buildDataCard('Tremor', packet.tremor.toString()),

              const SizedBox(height: 16),

              // Calibrated Values
              _buildSectionHeader('Calibrated Values'),
              _buildDataCard('Calibrated Accel X', packet.calAx.toString()),
              _buildDataCard('Calibrated Gyro X', packet.calGx.toString()),

              const SizedBox(height: 16),

              // SmartPen Features
              _buildSmartPenSection(smartPenState, smartPenNotifier),

              const SizedBox(height: 30),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Waiting for data...'),
          ],
        ),
      ),
      error: (error, stack) => Center(
        child: Text('Data error: $error'),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildDataCard(String label, String value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartPenSection(SmartPenState smartPenState, SmartPenNotifier smartPenNotifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SmartPen Features'),
        if (smartPenState.isLoading || smartPenState.isComputing)
          const Center(child: CircularProgressIndicator()),
        if (smartPenState.error != null)
          _buildDataCard('Error', smartPenState.error!),
        ElevatedButton(
          onPressed: smartPenState.isComputing
              ? null
              : () => smartPenNotifier.computeFeaturesWithMockData(200), // Use mock data for testing
          child: const Text('Compute Features (Mock Data)'),
        ),
        if (smartPenState.features != null)
          _buildDataCard('Features Count', smartPenState.features!.length.toString()),
        // For brevity, don't display all 354 features, just show first few
        if (smartPenState.features != null && smartPenState.features!.isNotEmpty)
          ...smartPenState.features!.take(5).map((feature) => _buildDataCard('Feature ${smartPenState.features!.indexOf(feature)}', feature.toStringAsFixed(4))),
        if (smartPenState.statistics != null)
          _buildDataCard('Statistics Count', smartPenState.statistics!.length.toString()),
        if (smartPenState.buttonStatus != null)
          _buildDataCard('Button Status Count', smartPenState.buttonStatus!.length.toString()),
      ],
    );
  }

  String _getPenStateString(int penState) {
    switch (penState) {
      case 0:
        return 'Pen Up';
      case 1:
        return 'Pen Down';
      case 2:
        return 'Hovering';
      default:
        return 'Unknown ($penState)';
    }
  }

  Widget _buildMockConnectedView(SmartPenState smartPenState, SmartPenNotifier smartPenNotifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.sensors,
                  size: 60,
                  color: Colors.blue,
                ),
                const SizedBox(height: 8),
                Text(
                  'Mock Pen Data',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Mock Data Section
          _buildSectionHeader('Mock Sensor Data'),
          _buildDataCard('Status', 'Mock Connected'),
          _buildDataCard('Mock Samples', '200'),

          const SizedBox(height: 16),

          // SmartPen Features
          _buildSmartPenSection(smartPenState, smartPenNotifier),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildErrorView(BluetoothSensorService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              service.errorMessage ?? 'An error occurred',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _discoveredDevices.clear();
                _startScan(service);
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startScan(BluetoothSensorService service) async {
    setState(() {
      _discoveredDevices.clear();
    });
    await service.startScan();
  }

  Future<void> _connectToDevice(BluetoothSensorService service, BleDevice device) async {
    await service.connectToDevice(device);
  }

  Future<void> _disconnect(BluetoothSensorService service) async {
    await service.disconnect();
    setState(() {
      _discoveredDevices.clear();
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}