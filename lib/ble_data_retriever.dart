// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
//
// class BleDataRetriever extends StatefulWidget {
//   @override
//   _BleDataRetrieverState createState() => _BleDataRetrieverState();
//   // This widget is the home page of your application. It is stateful, meaning
//   // that it has a State object (defined below) that contains fields that affect
//   // how it looks.
// }
//
// class _BleDataRetrieverState extends State<BleDataRetriever> {
//   final _ble = FlutterReactiveBle();
//   String _deviceId;
//   StreamSubscription _scanSubscription;
//   StreamSubscription _connectionSubscription;
//   StreamSubscription _readSubscription;
//   List<String> _data = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _scanForDevices();
//   }
//
//   @override
//   void dispose() {
//     _scanSubscription?.cancel();
//     _connectionSubscription?.cancel();
//     _readSubscription?.cancel();
//     super.dispose();
//   }
//
//   void _scanForDevices() {
//     _scanSubscription = _ble.scanForDevices(withServices: []).listen((device) {
//       print('Found device: ${device.name}');
//       if (device.name == 'MeasuringWheel') {
//         setState(() {
//           _deviceId = device.id;
//         });
//         _scanSubscription.cancel();
//         _connectToDevice(device.id);
//       }
//     });
//   }
//
//   void _connectToDevice(String deviceId) {
//     _connectionSubscription = _ble
//         .connectToDevice(
//       id: deviceId,
//       connectionTimeout: const Duration(seconds: 5),
//     )
//         .listen((connectionState) {
//       print('Connection state: $connectionState');
//       if (connectionState.connectionState == DeviceConnectionState.connected) {
//         _requestReadings(deviceId);
//       }
//     });
//   }
//
//   void _requestReadings(String deviceId) {
//     final serviceUuid = "12345678-1234-5678-9ABC-DEF123456789";
//     final readRequestCharacteristicUuid = "DEF12345-6789-0123-4567-890123456789";
//     final measurementCharacteristicUuid = "ABCDEF12-3456-7890-ABCD-EF1234567890";
//
//     _ble
//         .writeCharacteristicWithoutResponse(
//       QualifiedCharacteristic(
//           serviceId: Uuid.parse(serviceUuid),
//           characteristicId: Uuid.parse(readRequestCharacteristicUuid),
//           deviceId: deviceId),
//       value: [1],
//     )
//         .then((_) {
//       _readSubscription = _ble
//           .subscribeToCharacteristic(QualifiedCharacteristic(
//           serviceId: Uuid.parse(serviceUuid),
//           characteristicId: Uuid.parse(measurementCharacteristicUuid),
//           deviceId: deviceId))
//           .listen((data) {
//         final readings = String.fromCharCodes(data);
//         print('Readings: $readings');
//         setState(() {
//           _data.add(readings);
//         });
//       });
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('BLE Data Retriever'),
//       ),
//       body: ListView.builder(
//         itemCount: _data.length,
//         itemBuilder: (context, index) {
//           return ListTile(
//             title: Text(_data[index]),
//           );
//         },
//       ),
//     );
//   }
