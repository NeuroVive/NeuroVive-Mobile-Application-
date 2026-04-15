import 'dart:async';
import 'package:universal_ble/universal_ble.dart';
import 'dart:typed_data';

// Connection states for UI
enum BluetoothConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error
}

class BluetoothSensorService {
  final PacketParser _parser = PacketParser();
  final StreamController<SensorPacket> _packetController =
  StreamController<SensorPacket>.broadcast();
  late StreamController<BleDevice> _scanResultsController =
  StreamController<BleDevice>.broadcast();
  final StreamController<BluetoothConnectionState> _connectionStateController =
  StreamController<BluetoothConnectionState>.broadcast();

  // Add a buffer for incoming bytes to handle MTU splitting
  final List<int> _receiveBuffer = [];

  // Streams for UI updates
  Stream<SensorPacket> get packets => _packetController.stream;
  Stream<BleDevice> get scanResults => _scanResultsController.stream;
  Stream<BluetoothConnectionState> get connectionState =>
      _connectionStateController.stream;

  BleDevice? connectedDevice;
  BleCharacteristic? characteristic;
  StreamSubscription? _scanSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _notificationSub;
  bool _isScanning = false;

  BluetoothConnectionState _currentState = BluetoothConnectionState.disconnected;
  String? _errorMessage;

  BluetoothConnectionState get currentState => _currentState;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _currentState = BluetoothConnectionState.disconnected;
    _connectionStateController.add(_currentState);
  }

  Future<bool> checkAndRequestPermissions() async {
    try {
      // Check if Bluetooth is available
      final BleState = await UniversalBle.getBluetoothAvailabilityState();
      if (BleState == AvailabilityState.unsupported) {
        _errorMessage = 'Bluetooth is not available on this device';
        _currentState = BluetoothConnectionState.error;
        _connectionStateController.add(_currentState);
        return false;
      }

      // Check if Bluetooth is enabled
      if (BleState != AvailabilityState.poweredOn) {
        _errorMessage = 'Please enable Bluetooth';
        _currentState = BluetoothConnectionState.error;
        _connectionStateController.add(_currentState);
        return false;
      }

      // Check permissions
      var status = await UniversalBle.hasPermissions();
      if (status != true) {
        // Request permissions
        await UniversalBle.requestPermissions();
        status = await UniversalBle.hasPermissions();
        if (status != true) {
          _errorMessage = 'Bluetooth permissions denied';
          _currentState = BluetoothConnectionState.error;
          _connectionStateController.add(_currentState);
          return false;
        }
      }

      return true;
    } catch (e) {
      _errorMessage = 'Permission check failed: $e';
      _currentState = BluetoothConnectionState.error;
      _connectionStateController.add(_currentState);
      return false;
    }
  }

  Future<bool> isDeviceConnected() async {
    if (connectedDevice == null) return false;

    try {
      // Try to get services - if this fails, device might be disconnected
      await connectedDevice!.discoverServices();
      return true;
    } catch (e) {
      print('Device connection check failed: $e');
      return false;
    }
  }

  Future<void> startScan() async {
    // Check permissions first
    if (!await checkAndRequestPermissions()) {
      return;
    }

    try {
      _isScanning = true;
      _currentState = BluetoothConnectionState.scanning;
      _connectionStateController.add(_currentState);

      // Clear previous scan results
      _scanResultsController = StreamController<BleDevice>.broadcast();
      print("Started scanning");

      // Listen for scan results
      _scanSub = UniversalBle.scanStream.listen(
            (BleDevice bleDevice) {
          print("Found device: ${bleDevice.name} (${bleDevice.deviceId})");
          _scanResultsController.add(bleDevice);
        },
        onError: (error) {
          _errorMessage = 'Scan error: $error';
          _currentState = BluetoothConnectionState.error;
          _connectionStateController.add(_currentState);
        },
      );

      // Start scanning
      await UniversalBle.startScan();

      // Auto-stop scan after 50 seconds
      Future.delayed(const Duration(seconds: 50), () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      _errorMessage = 'Failed to start scan: $e';
      _currentState = BluetoothConnectionState.error;
      _connectionStateController.add(_currentState);
    }
  }

  Future<void> stopScan() async {
    _isScanning = false;
    await UniversalBle.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;

    if (_currentState == BluetoothConnectionState.scanning) {
      _currentState = BluetoothConnectionState.disconnected;
      _connectionStateController.add(_currentState);
    }
  }

  Future<void> connectToDevice(BleDevice device) async {
    try {
      _currentState = BluetoothConnectionState.connecting;
      _connectionStateController.add(_currentState);

      // Stop scanning first
      await stopScan();

      // Connect to device
      await device.connect();
      connectedDevice = device;

      // REQUEST MTU - This is critical for receiving large packets
      print('Requesting MTU 64...');
      try {
        int mtu = await device.requestMtu(64);
        print('MTU negotiated to: $mtu bytes');
        if (mtu < 43) {
          print('WARNING: MTU $mtu is less than packet size 43!');
        }
      } catch (e) {
        print('MTU request failed: $e - continuing with default MTU');
      }

      // Monitor connection state
      device.pairingStateStream.listen(
            (state) {
          print('Connection state changed: $state');
          if (state == BluetoothConnectionState.connected) {
            _currentState = BluetoothConnectionState.connected;
          } else if (state == BluetoothConnectionState.disconnected) {
            _currentState = BluetoothConnectionState.disconnected;
            connectedDevice = null;
          }
          _connectionStateController.add(_currentState);
        },
        onError: (error) {
          _errorMessage = 'Connection lost: $error';
          _currentState = BluetoothConnectionState.error;
          _connectionStateController.add(_currentState);
        },
      );

      // Discover services
      print('Discovering services...');
      List<BleService> services = await device.discoverServices();

      // Find the characteristic with notify property
      for (var service in services) {
        print('Found service: ${service.uuid}');
        for (var char in service.characteristics) {
          print('  Characteristic: ${char.uuid} - Properties: ${char.properties}');

          if (char.properties.contains(CharacteristicProperty.notify)) {
            characteristic = char;

            // Listen for incoming bytes
            _notificationSub = characteristic!.onValueReceived.listen(
                  (value) {
                _handleBytes(value);
              },
              onError: (error) {
                print('Notification error: $error');
              },
            );

            // Enable notifications
            await characteristic!.notifications.subscribe();
            print('Subscribed to notifications for ${char.uuid}');
            break;
          }
        }
      }

      _currentState = BluetoothConnectionState.connected;
      _connectionStateController.add(_currentState);
    } catch (e) {
      _errorMessage = 'Connection failed: $e';
      _currentState = BluetoothConnectionState.error;
      _connectionStateController.add(_currentState);
    }
  }

  // FIXED: Buffer incoming bytes and only parse when we have a full packet
  void _handleBytes(List<int> bytes) {
    // Add to buffer
    _receiveBuffer.addAll(bytes);

    // Debug logging
    print('Received ${bytes.length} bytes, buffer now ${_receiveBuffer.length}');
    print('Hex: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    // Process while we have at least a full packet (43 bytes)
    while (_receiveBuffer.length >= 43) {
      // Extract one full packet
      List<int> packetBytes = _receiveBuffer.sublist(0, 43);
      _receiveBuffer.removeRange(0, 43);

      print('Processing full packet of ${packetBytes.length} bytes');

      // Parse the packet
      var packets = _parser.feed(packetBytes);
      for (var p in packets) {
        _packetController.add(p);
        print('Parsed packet seq: ${p.seqNumber}');
      }
    }

    if (_receiveBuffer.isNotEmpty) {
      print('Waiting for more data, ${_receiveBuffer.length} bytes in buffer');
    }
  }

  Future<void> disconnect() async {
    try {
      await _notificationSub?.cancel();
      await characteristic?.unsubscribe();
      await connectedDevice?.disconnect();
      await _connectionSub?.cancel();

      connectedDevice = null;
      characteristic = null;
      _receiveBuffer.clear(); // Clear the buffer

      _currentState = BluetoothConnectionState.disconnected;
      _connectionStateController.add(_currentState);
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  bool get isScanning => _isScanning;

  void dispose() {
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _notificationSub?.cancel();
    _packetController.close();
    _scanResultsController.close();
    _connectionStateController.close();
    _receiveBuffer.clear();
  }
}

class SensorPacket {
  final int packetType;
  final int seqNumber;
  final int timestamp;
  final int axRaw;
  final int ayRaw;
  final int azRaw;
  final int gxRaw;
  final int gyRaw;
  final int gzRaw;
  final int pitch;
  final int roll;
  final int altitude;
  final int jerkMag;
  final int pressureRaw;
  final int forceGram;
  final int penState;
  final int liftCount;
  final int tremor;
  final int calAx;
  final int calGx;
  final int checkSum;

  SensorPacket({
    required this.packetType,
    required this.seqNumber,
    required this.timestamp,
    required this.axRaw,
    required this.ayRaw,
    required this.azRaw,
    required this.gxRaw,
    required this.gyRaw,
    required this.gzRaw,
    required this.pitch,
    required this.roll,
    required this.altitude,
    required this.jerkMag,
    required this.pressureRaw,
    required this.forceGram,
    required this.penState,
    required this.liftCount,
    required this.tremor,
    required this.calAx,
    required this.calGx,
    required this.checkSum,
  });

  @override
  String toString() {
    return "packetType: $packetType, seqNumber: $seqNumber, timestamp: $timestamp, "
        "axRaw: $axRaw, ayRaw: $ayRaw, azRaw: $azRaw, gxRaw: $gxRaw, gyRaw: $gyRaw, gzRaw: $gzRaw, "
        "pitch: $pitch, roll: $roll, altitude: $altitude, jerkMag: $jerkMag, pressureRaw: $pressureRaw, "
        "forceGram: $forceGram, penState: $penState, liftCount: $liftCount, tremor: $tremor, "
        "calAx: $calAx, calGx: $calGx, checkSum: $checkSum";
  }
}

class PacketParser {
  static const int packetSize = 43;
  final List<int> _buffer = [];

  List<SensorPacket> feed(List<int> incoming) {
    _buffer.addAll(incoming);
    List<SensorPacket> packets = [];

    while (_buffer.length >= packetSize) {
      List<int> raw = _buffer.sublist(0, packetSize);
      _buffer.removeRange(0, packetSize);
      packets.add(_parsePacket(raw));
    }

    return packets;
  }

  SensorPacket _parsePacket(List<int> data) {
    ByteData byteData = Uint8List.fromList(data).buffer.asByteData();
    int offset = 0;

    // Read packetType (byte 0)
    int packetType = byteData.getUint8(offset);
    offset += 1;

    // Read seqNumber (byte 1)
    int seqNumber = byteData.getUint8(offset);
    offset += 1;

    // Read timestamp (bytes 2-5)
    int timestamp = byteData.getUint32(offset, Endian.little);
    offset += 4;

    // Read axRaw (bytes 6-7)
    int axRaw = byteData.getInt16(offset, Endian.little);
    offset += 2;

    // Read ayRaw (bytes 8-9)
    int ayRaw = byteData.getInt16(offset, Endian.little);
    offset += 2;

    // Read azRaw (bytes 10-11)
    int azRaw = byteData.getInt16(offset, Endian.little);
    offset += 2;

    // Read gxRaw (bytes 12-13)
    int gxRaw = byteData.getInt16(offset, Endian.little);
    offset += 2;

    // Read gyRaw (bytes 14-15)
    int gyRaw = byteData.getInt16(offset, Endian.little);
    offset += 2;

    // Read gzRaw (bytes 16-17)
    int gzRaw = byteData.getInt16(offset, Endian.little);
    offset += 2;

    // Read pitch (bytes 18-19)
    int pitch = byteData.getInt16(offset, Endian.little);
    offset += 2;

    // Read roll (bytes 20-21)
    int roll = byteData.getInt16(offset, Endian.little);
    offset += 2;

    // Read altitude (bytes 22-23)
    int altitude = byteData.getInt16(offset, Endian.little);
    offset += 2;

    // Read jerkMag (bytes 24-25)
    int jerkMag = byteData.getUint16(offset, Endian.little);
    offset += 2;

    // Read pressureRaw (bytes 26-27)
    int pressureRaw = byteData.getUint16(offset, Endian.little);
    offset += 2;

    // Read forceGram (bytes 28-29)
    int forceGram = byteData.getUint16(offset, Endian.little);
    offset += 2;

    // Read penState (byte 30)
    int penState = byteData.getUint8(offset);
    offset += 1;

    // Read liftCount (byte 31)
    int liftCount = byteData.getUint8(offset);
    offset += 1;

    // Read tremor (bytes 32-33)
    int tremor = byteData.getUint16(offset, Endian.little);
    offset += 2;

    // Read calAx (bytes 34-37)
    int calAx = byteData.getInt32(offset, Endian.little);
    offset += 4;

    // Read calGx (bytes 38-41)
    int calGx = byteData.getInt32(offset, Endian.little);
    offset += 4;

    // Read checkSum (byte 42)
    int checkSum = byteData.getUint8(offset);

    return SensorPacket(
      packetType: packetType,
      seqNumber: seqNumber,
      timestamp: timestamp,
      axRaw: axRaw,
      ayRaw: ayRaw,
      azRaw: azRaw,
      gxRaw: gxRaw,
      gyRaw: gyRaw,
      gzRaw: gzRaw,
      pitch: pitch,
      roll: roll,
      altitude: altitude,
      jerkMag: jerkMag,
      pressureRaw: pressureRaw,
      forceGram: forceGram,
      penState: penState,
      liftCount: liftCount,
      tremor: tremor,
      calAx: calAx,
      calGx: calGx,
      checkSum: checkSum,
    );
  }
}