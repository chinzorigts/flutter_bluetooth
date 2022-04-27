import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth/scan_result_tile.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Blue Plus',
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBluePlus.instance.state,
          initialData: BluetoothState.unknown,
          builder: (context, snapshot) {
            final state = snapshot.data;
            if(state == BluetoothState.on){
              return const FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }
      ),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget{

  final BluetoothState? state;

  const BluetoothOffScreen({Key? key, this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subtitle2
                  ?.copyWith(color: Colors.white),
            ),
            ElevatedButton(
              child: const Text('TURN ON'),
              onPressed: Platform.isAndroid
                  ? () => FlutterBluePlus.instance.turnOn()
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget{

  const FindDevicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Devices'),
        actions: [
          ElevatedButton(
            child: const Text('TURN OFF'),
            style: ElevatedButton.styleFrom(
              primary: Colors.black,
              onPrimary: Colors.white,
            ),
            onPressed: Platform.isAndroid ? () => FlutterBluePlus.instance.turnOff() : null,
          ),
        ],
      ),
      body: RefreshIndicator(
          onRefresh: () => FlutterBluePlus.instance.startScan(timeout: const Duration(seconds: 4)),
          child: SingleChildScrollView(
          child: Column(
          children: <Widget>[
            const Text('Connectable Device List'),
            StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => FlutterBluePlus.instance.connectedDevices),
                initialData: const [],
                builder: (context, snapshot) => Column(
                  children: snapshot.data!.where((element) => element.type == BluetoothDeviceType.le).map((d) => ListTile(
                    title: Text(d.name),
                    subtitle: Text(d.id.toString()),
                    trailing: StreamBuilder<BluetoothDeviceState>(
                      stream: d.state,
                      initialData: BluetoothDeviceState.disconnected,
                      builder: (c, snapshot) {
                        if (snapshot.data ==
                            BluetoothDeviceState.connected) {
                          return ElevatedButton(
                            child: const Text('OPEN'),
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => DeviceScreen(device: d))),
                          );
                        }
                        return Text(snapshot.data.toString());
                      },
                    ),
                  )).toList(),
                  /*children: snapshot.data!.map((d) => ListTile(
                    title: Text(d.name),
                    subtitle: Text(d.id.toString()),
                    trailing: StreamBuilder<BluetoothDeviceState>(
                      stream: d.state,
                      initialData: BluetoothDeviceState.disconnected,
                      builder: (c, snapshot) {
                        if (snapshot.data ==
                            BluetoothDeviceState.connected) {
                          return ElevatedButton(
                            child: const Text('OPEN'),
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => DeviceScreen(device: d))),
                          );
                        }
                        return Text(snapshot.data.toString());
                      },
                    ),
                  )).toList(),*/
                )
            ),
            StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.instance.scanResults,
                initialData: const [],
                builder: (context, snapshot) => Column(
                  children: snapshot.data!.map((e) => ScanResultTile(
                      result: e,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                        e.device.connect();
                        return DeviceScreen(device: e.device);
                      },)),
                  )).toList(),
                )
            ),
          ],
        ),
      ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBluePlus.instance.isScanning,
        initialData: false,
        builder: (context, snapshot){
          if(snapshot.data!){
            return FloatingActionButton(
                child: const Icon(Icons.stop),
                onPressed: () => FlutterBluePlus.instance.stopScan(),
                backgroundColor: Colors.red,
            );
          }
          else{
            return FloatingActionButton(
              child: const Icon(Icons.search),
              onPressed: () => FlutterBluePlus.instance.startScan(timeout: const Duration(seconds: 4)),
            );
          }
        },
      )
    );
  }
}

class DeviceScreen extends StatelessWidget{

  final BluetoothDevice device;

  List<int> _getRandomBytes() {
    final math = Random();
    return [
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255)
    ];
  }

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  List<Widget> _buildServiceTiles(List<BluetoothService> services){
    return services.map((s) => ServiceTile(
      service: s,
      characteristicTiles: s.characteristics.map((c) => CharacteristicTile(
          characteristic: c,
          onReadPressed: () async => await c.read(),
          onWritePressed: () async{
            await c.write('[SP,2,]'.codeUnits, withoutResponse: false);
            c.setNotifyValue(true);
            await c.read();
          },
          descriptorTiles: c.descriptors.map((d) => DescriptorTile(
              descriptor: d,
              onReadPressed: () => d.read(),
              onWritePressed: () => d.write('[SP,2,]'.codeUnits),
            ),
          ).toList(),
        )).toList(),
      )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return TextButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context).primaryTextTheme.button?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
                stream: device.state,
                initialData: BluetoothDeviceState.connecting,
                builder: (context, snapshot) => ListTile(
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      snapshot.data == BluetoothDeviceState.connected ? const Icon(Icons.bluetooth_connected, color: Colors.blueAccent,) : const Icon(Icons.bluetooth_disabled),
                      snapshot.data == BluetoothDeviceState.connected ? StreamBuilder<int>(
                          stream: rssiStream(),
                          builder: (context, snapshot) {
                            return Text(snapshot.hasData ? '${snapshot.data}dBm' : '', style: const TextStyle(fontSize: 12,color: Colors.blueAccent, fontWeight: FontWeight.w500),);
                          })
                          :
                          Text('', style: Theme.of(context).textTheme.caption,),
                    ],
                  ),
                  title: Text('Device is ${snapshot.data.toString().split('.')[1]}.'),
                  subtitle: Text('${device.id}'),
                  trailing: StreamBuilder<bool>(
                    stream: device.isDiscoveringServices,
                    initialData: false,
                    builder: (context, snapshot) => IndexedStack(
                      index: snapshot.data! ? 1 : 0,
                      children: <Widget>[
                        IconButton(
                            onPressed: () => device.discoverServices(),
                            icon: const Icon(Icons.refresh)
                        ),
                        const IconButton(
                            onPressed: null,
                            icon: SizedBox(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Colors.grey),
                              ),
                              width: 18.0,
                              height: 18.0,
                            )
                        ),
                      ],
                    ),
                  ),
                )
            ),
            StreamBuilder<int>(
                stream: device.mtu,
                initialData: 0,
                builder: (context, snapshot) => ListTile(
                  title: const Text('MTU Size'),
                  subtitle: Text('${snapshot.data} bytes'),
                  trailing: IconButton(
                      onPressed: () => device.requestMtu(223),
                      icon: const Icon(Icons.edit)
                  ),
                )
            ),
            StreamBuilder<List<BluetoothService>>(
                stream: device.services,
                initialData: const [],
                builder: (context, snapshot){
                  return Column(
                    children: _buildServiceTiles(snapshot.data!),
                  );
                }
            ),
          ],
        ),
      ),
    );
  }

  Stream<int> rssiStream() async* {
    var isConnected = true;
    final subscription = device.state.listen((state) {
      isConnected = state == BluetoothDeviceState.connected;
    });
    while (isConnected) {
      yield await device.readRssi();
      await Future.delayed(const Duration(seconds: 1));
    }
    subscription.cancel();
    // Device disconnected, stopping RSSI stream
  }
}
