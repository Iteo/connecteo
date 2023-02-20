import 'dart:async';

import 'package:connecteo/connecteo.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connecteo Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ConnecteoExamplePage(),
    );
  }
}

class ConnecteoExamplePage extends StatefulWidget {
  const ConnecteoExamplePage({super.key});

  @override
  State<StatefulWidget> createState() => _ConnecteoExamplePageState();
}

class _ConnecteoExamplePageState extends State<ConnecteoExamplePage> {
  late ConnectionChecker _connecteo;
  late StreamSubscription<bool> _streamSubscription;

  Color? _backgroundColor;
  ConnectionType? _connectionType;

  @override
  void initState() {
    _connecteo = ConnectionChecker();

    _setupInitialColor();
    _setupConnectionListener();
    _registerConnectionBackCallback();

    super.initState();
  }

  @override
  void dispose() {
    _streamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Connecteo Demo'),
      ),
      body: _backgroundColor != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final type = await _connecteo.connectionType;
                      setState(() {
                        _connectionType = type;
                      });
                    },
                    child: const Text('Check connection type'),
                  ),
                  Text('Connection type value: $_connectionType'),
                ],
              ),
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  void _setupConnectionListener() {
    _streamSubscription =
        _connecteo.connectionStream.listen(_updateBackgroundColor);
  }

  void _setupInitialColor() {
    _connecteo.isConnected.then(_updateBackgroundColor);
  }

  void _updateBackgroundColor(bool isConnected) {
    setState(() {
      _backgroundColor = isConnected ? Colors.green[100]! : Colors.red[100]!;
    });
  }

  void _registerConnectionBackCallback() {
    Future<void>.delayed(const Duration(seconds: 5)).then((_) async {
      final isConnected = await _connecteo.isConnected;

      if (!isConnected) {
        // Register callback to be triggered once connection back
        await _connecteo
            .untilConnects()
            // ignore: avoid_print
            .then((_) => print('Connection is back!'));
      }
    });
  }
}
