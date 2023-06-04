import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:location_permissions/location_permissions.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:developer' as developer;
import 'debug_screen.dart';

void main() {
  //initFirebase();
  return runApp(
    const MaterialApp(home: HomePage()),
  );
}

Future<void> initFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
  Map<String, dynamic> debugData = {};
  int _expectedLength = 0;
  Map<String, dynamic> _logDataMap = {};
  String peripheralName = "TRUNDLE9000";
  String buffer = '';
  String _displayMessage = 'Press the looking glass symbol to start scan';
  bool _isMeasurementActive = false;


// Bluetooth related variables
  late DiscoveredDevice _peripheralDevice;
  final flutterReactiveBle = FlutterReactiveBle();
  late StreamSubscription<DiscoveredDevice> _scanStream;

  late QualifiedCharacteristic _logDataCharacteristic;
  late QualifiedCharacteristic _debugDataCharacteristic;
  late QualifiedCharacteristic _commandCharacteristic;

  // UUID of this device
  final Uuid serviceUuid = Uuid.parse("e280122a-c45b-44dc-a340-d3ac899dc88b");

  //final Uuid characteristicUuid = Uuid.parse("40614d40-dab6-49b8-921e-a72261b844ba");
  final Uuid logDataCharacteristicUuid = Uuid.parse("5a8e5d70-7e5e-4a1f-8a2d-5a5e8c5f5ca5");
  final Uuid debugDataCharacteristicUuid = Uuid.parse("40614d40-dab6-49b8-921e-a72261b844bb");
  final Uuid commandCharacteristicUuid = Uuid.parse("b4720eaa-d15e-4252-8e58-7ae9fb7fbb47");

  void _startScan() async {
    final FlutterReactiveBle _ble = FlutterReactiveBle();
    final statusStream = _ble.statusStream;

    statusStream.listen((status) async {
      switch (status) {
        case BleStatus.ready:
          try {
            _scanForDevices();
          } catch (e) {
            if (e is GenericFailure<ScanFailure>) {
              print('Failed to start scan: ${e.message}');
            } else {
              rethrow;
            }
          }
          break;
        case BleStatus.unauthorized:
        // TODO: show a dialog or a different UI to inform the user that the app is not authorized for BLE operation
          break;
        case BleStatus.poweredOff:
          _showBluetoothDialog(context);
          break;
        default:
          break;
      }
    });
  }

  void _scanForDevices() async {
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
      _scanStream = flutterReactiveBle.scanForDevices(withServices: [serviceUuid], scanMode: ScanMode.lowLatency).listen((device) {
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

  Future<void> _connectToDevice() async {
    // scanning is done, we can cancel it
    await _scanStream.cancel();

    // listen to our connection so we can make updates on a state change
    Stream<ConnectionStateUpdate> currentConnectionStream = flutterReactiveBle.connectToAdvertisingDevice(
        id: _peripheralDevice.id, prescanDuration: const Duration(seconds: 7), withServices: [serviceUuid, logDataCharacteristicUuid, debugDataCharacteristicUuid]);
    currentConnectionStream.listen((event) {
      switch (event.connectionState) {
        case DeviceConnectionState.connected:
          {
            _logDataCharacteristic = QualifiedCharacteristic(serviceId: serviceUuid, characteristicId: logDataCharacteristicUuid, deviceId: event.deviceId);
            _debugDataCharacteristic = QualifiedCharacteristic(serviceId: serviceUuid, characteristicId: debugDataCharacteristicUuid, deviceId: event.deviceId);
            _commandCharacteristic = QualifiedCharacteristic(serviceId: serviceUuid, characteristicId: commandCharacteristicUuid, deviceId: event.deviceId);
            //TODO: this method of state handling is very messy.
            // Reactive BLE returns nice streams that you should be subscribing to to handle state change,
            // but for the purpose of this we'll just be using the setState() call.
            setState(() {
              _foundDeviceWaitingToConnect = false;
              _connected = true;
            });
            // Subscribe to notifications from debugDataCharacteristic
            _subscribeToDebugData(context);
            break;
          }
        case DeviceConnectionState.connecting:
          // TODO: Handle this case.
          break;
        case DeviceConnectionState.disconnecting:
          // TODO: Handle this case.
          break;
        case DeviceConnectionState.disconnected:
          // TODO: Handle this case.
          break;
      }
    });
  }

  void _subscribeToDebugData(BuildContext context) {
    developer.log('subscribing to debug data', name: 'my.app.category');
    String buffer = "";

    flutterReactiveBle.subscribeToCharacteristic(_debugDataCharacteristic).listen((data) {
      buffer += String.fromCharCodes(data);
      developer.log('buffer: $buffer', name: 'my.app.category');

      // Check if the buffer contains a newline
      int newlineIndex = buffer.indexOf('\n');
      if (newlineIndex != -1) {
        // Try to parse the substring up to the newline as the length
        int? length = int.tryParse(buffer.substring(0, newlineIndex));
        if(length != null) {
          // We have a valid length, so we wait for that much data to accumulate before processing
          if(buffer.length >= length + newlineIndex + 1) {
            String message = buffer.substring(newlineIndex + 1, newlineIndex + length + 1);
            // Now process the 'message' which should contain the whole JSON string
            try {
              var parsed = json.decode(message); // Try to parse the JSON
              setState(() {
                this.debugData = parsed;
              });
              developer.log('received debug data: $debugData', name: 'my.app.category');

              // Remove the processed message and length from the buffer
              buffer = buffer.substring(newlineIndex + length + 1);
            } catch (e) {
              // If parsing fails, log the error.
              developer.log('Failed parsing message: $message', name: 'my.app.category');
              developer.log('Error parsing debug data: $e', name: 'my.app.category');
            }
          }
        } else {
          // We didn't get a valid length, this shouldn't happen if the Arduino is sending the length correctly.
          developer.log('Failed parsing length: ${buffer.substring(0, newlineIndex)}', name: 'my.app.category');
          // Clear the buffer here to prevent it from growing indefinitely
          buffer = "";
        }
      }
    });
  }

  String stitchChunks(List<String> chunks) {
    // Create a new string to hold the stitched data.
    String stitchedString = "";

    // Iterate over the chunks and add each chunk to the new string.
    for (String chunk in chunks) {
      stitchedString += chunk;
    }

    // Return the new string.
    return stitchedString;
  }

  void _navigateToDebugScreen(BuildContext context) {
    // Navigate to the DebugScreen with the latest debug data
    developer.log('navigating to debug screen', name: 'my.app.category');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebugScreen(debugData: debugData),
      ),
    );
  }

  void _subscribeToLogData() {
    developer.log('subscribing to log data', name: 'my.app.category');

    flutterReactiveBle.subscribeToCharacteristic(_logDataCharacteristic).listen((data) {
      // Convert received data to string
      String receivedData = String.fromCharCodes(data);
      buffer += receivedData;

      if (buffer.contains('{') && _expectedLength == 0) {
        int endOfLength = buffer.indexOf('{');
        _expectedLength = int.tryParse(buffer.substring(0, endOfLength)) ?? 0;
        buffer = buffer.substring(endOfLength);
      }

      if (_expectedLength > 0 && buffer.length >= _expectedLength) {
        String jsonData = buffer.substring(0, _expectedLength);  // parse this data as json
        buffer = buffer.substring(_expectedLength);
        _expectedLength = 0;

        try {
          developer.log('Attempting to parse: $jsonData', name: 'my.app.category');
          Map<String, dynamic> logData = jsonDecode(jsonData);
          developer.log('received log data: ${jsonEncode(logData)}', name: 'my.app.category');
          setState(() {
            // Process logData as required
          });
        } catch (e) {
          developer.log('Failed parsing message: $jsonData', name: 'my.app.category');
          developer.log('Error parsing log data: $e', name: 'my.app.category');
        }
      }
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
                onPressed: () => _navigateToDebugScreen(context),
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
        // Your new button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isMeasurementActive ? Colors.red : Colors.green, // Change color based on state
            foregroundColor: Colors.white, // foreground
          ),
          onPressed: _toggleMeasurement,
          child: Icon(_isMeasurementActive ? Icons.stop : Icons.play_arrow), // Change icon based on state
        ),

      ],
    );
  }

  void _showBluetoothDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Bluetooth is turned off'),
          content: Text('Please enable Bluetooth to use this feature.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                // TODO: handle the user's response
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleMeasurement() async {
    String message;
    if (!_isMeasurementActive) {
      message = "start_measurement";
    } else {
      message = "stop_measurement";
    }

    List<int> bytes = utf8.encode(message);

    // Define the characteristic you are going to write
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse("e280122a-c45b-44dc-a340-d3ac899dc88b"), // replace with your service UUID
      characteristicId: Uuid.parse("b4720eaa-d15e-4252-8e58-7ae9fb7fbb47"), // replace with your characteristic UUID
      deviceId: _peripheralDevice.id,
    );

    await flutterReactiveBle.writeCharacteristicWithResponse(characteristic, value: bytes);

    // Now get the confirmation message
    List<int> value = await flutterReactiveBle.readCharacteristic(characteristic);

    // Convert bytes to string
    String receivedMessage = utf8.decode(value);

    // Compare received message to expected confirmation
    if (_isMeasurementActive && receivedMessage == "confirmed_stop_measurement") {
      // If we were stopping and got the stop confirmation, update state
      setState(() {
        _isMeasurementActive = false;
      });
    } else if (!_isMeasurementActive && receivedMessage == "confirmed_start_measurement") {
      // If we were starting and got the start confirmation, update state
      setState(() {
        _isMeasurementActive = true;
      });
    }
  }

}
