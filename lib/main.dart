import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:location_permissions/location_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'dart:developer' as developer;

import 'debug_screen.dart';

void main() {
  return runApp(
    const MaterialApp(home: HomePage()),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Some state management stuff
  bool _foundDeviceWaitingToConnect = false;
  bool _scanStarted = false;
  bool _connected = false;
  String _logData = "";
  String _debugData = "";
  String peripheralName = "TRUNDLE9000";

// Bluetooth related variables
  late DiscoveredDevice _peripheralDevice;
  final flutterReactiveBle = FlutterReactiveBle();
  late StreamSubscription<DiscoveredDevice> _scanStream;

  late QualifiedCharacteristic _logDataCharacteristic;
  late QualifiedCharacteristic _debugDataCharacteristic;

  // UUID of this device
  final Uuid serviceUuid = Uuid.parse("e280122a-c45b-44dc-a340-d3ac899dc88b");

  //final Uuid characteristicUuid = Uuid.parse("40614d40-dab6-49b8-921e-a72261b844ba");
  final Uuid logDataCharacteristicUuid = Uuid.parse("5a8e5d70-7e5e-4a1f-8a2d-5a5e8c5f5ca5");
  final Uuid debugDataCharacteristicUuid = Uuid.parse("40614d40-dab6-49b8-921e-a72261b844bb");

  void _startScan() async {
    // Platform permissions handling stuff
    developer.log('starting scan', name: 'my.app.category');
    bool permGranted = false;
    setState(() {
      _scanStarted = true;
    });
    PermissionStatus permission;
    if (Platform.isAndroid) {
      permission = await LocationPermissions().requestPermissions();
      if (permission == PermissionStatus.granted) permGranted = true;
    } else if (Platform.isIOS) {
      permGranted = true;
    }
    // Main scanning logic
    if (permGranted) {
      _scanStream = flutterReactiveBle.scanForDevices(withServices: [serviceUuid]).listen((device) {
        if (device.name == peripheralName) {
          developer.log('found TRUNDLE9000', name: 'my.app.category');
          setState(() {
            _peripheralDevice = device;
            _foundDeviceWaitingToConnect = true;
          });
        }
      });
    }
  }

  void _connectToDevice() {
    // We're done scanning, we can cancel it
    _scanStream.cancel();
    // Let's listen to our connection so we can make updates on a state change
    Stream<ConnectionStateUpdate> _currentConnectionStream = flutterReactiveBle
        .connectToAdvertisingDevice(id: _peripheralDevice.id, prescanDuration: const Duration(seconds: 1), withServices: [serviceUuid, logDataCharacteristicUuid]);
    _currentConnectionStream.listen((event) {
      switch (event.connectionState) {
        case DeviceConnectionState.connected:
          {
            _logDataCharacteristic = QualifiedCharacteristic(serviceId: serviceUuid, characteristicId: logDataCharacteristicUuid, deviceId: event.deviceId);
            _debugDataCharacteristic = QualifiedCharacteristic(serviceId: serviceUuid, characteristicId: debugDataCharacteristicUuid, deviceId: event.deviceId);
            setState(() {
              _foundDeviceWaitingToConnect = false;
              _connected = true;
            });
            _subscribeToLogData(); // Add this line
            _subscribeToDebugData(context); // Add this line
            break;
          }
        // ... (same as before)
      }
    });
  }

  void _subscribeToLogData() {
    developer.log('subscribing to log data', name: 'my.app.category');
    // Subscribe to notifications from logDataCharacteristic
    flutterReactiveBle.subscribeToCharacteristic(_logDataCharacteristic).listen((data) {
      // Convert received data to string
      String receivedData = String.fromCharCodes(data);
      developer.log('received data: ' + receivedData, name: 'my.app.category');
      setState(() {
        // Append received data to _logData
        _logData += receivedData;
        developer.log('received data: ' + receivedData, name: 'my.app.category');
      });
    });
  }

  void _subscribeToDebugData(BuildContext context) {
    developer.log('subscribing to debug data', name: 'my.app.category');
    flutterReactiveBle.subscribeToCharacteristic(_debugDataCharacteristic).listen((data) {
      String receivedData = String.fromCharCodes(data);
      developer.log('received debug data: $receivedData', name: 'my.app.category');

      // Navigate to the DebugScreen with the latest debug data
      developer.log('navigating to debug screen', name: 'my.app.category');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DebugScreen(debugData: receivedData),
        ),
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      //body: Container(),
      body: Center(child: Text(_logData)),
      persistentFooterButtons: [
        // We want to enable this button if the scan has NOT started
        // If the scan HAS started, it should be disabled.
        _scanStarted
            // True condition
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey, // background
                  foregroundColor: Colors.white, // foreground
                ),
                onPressed: () {},
                child: const Icon(Icons.search),
              )
            // False condition
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // background
                  foregroundColor: Colors.white, // foreground
                ),
                onPressed: _startScan,
                child: const Icon(Icons.search),
              ),
        _foundDeviceWaitingToConnect
            // True condition
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // background
                  foregroundColor: Colors.white, // foreground
                ),
                onPressed: _connectToDevice,
                child: const Icon(Icons.bluetooth),
              )
            // False condition
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey, // background
                  foregroundColor: Colors.white, // foreground
                ),
                onPressed: () {},
                child: const Icon(Icons.bluetooth),
              ),
        _connected
            // True condition
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // background
                  foregroundColor: Colors.white, // foreground
                ),
                onPressed: _subscribeToLogData,
                child: const Icon(Icons.celebration_rounded),
              )
            // False condition
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey, // background
                  foregroundColor: Colors.white, // foreground
                ),
                onPressed: () {},
                child: const Icon(Icons.celebration_rounded),
              ),
        _connected
            // True condition
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // background
                  foregroundColor: Colors.white, // foreground
                ),
                // Subscribe to debug data when button is pressed
                onPressed: () => _subscribeToDebugData(context),
                child: const Icon(Icons.bug_report), // Change this icon as per your requirement
              )
            // False condition
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey, // background
                  foregroundColor: Colors.white, // foreground
                ),
                onPressed: () {},
                child: const Icon(Icons.bug_report), // Change this icon as per your requirement
              ),
      ],
    );
  }
}
