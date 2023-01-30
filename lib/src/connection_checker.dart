import 'dart:async';
import 'dart:io';

import 'package:connecteo/src/connection_type.dart';
import 'package:connecteo/src/connection_type_mapper.dart';
import 'package:connecteo/src/host_reachability_checker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';

const _connectionRequestInterval = Duration(seconds: 3);

const _connectionFailureAttempts = 4;

class ConnectionChecker {
  ConnectionChecker._({
    List<InternetAddress>? checkAddresses,
    Duration? checkOverDnsTimeout,
    String? baseUrlLookupAddress,
  })  : _checkAddresses = checkAddresses,
        _checkOverDnsTimeout = checkOverDnsTimeout,
        _baseUrlLookupAddress = baseUrlLookupAddress,
        _connectivity = Connectivity(),
        _connectionTypeMapper = ConnectionTypeMapper(),
        _hostReachabilityChecker = HostReachabilityChecker(),
        _initialConnectedValue = Completer(),
        _connectionTypeStreamController =
            BehaviorSubject.seeded(ConnectionType.unknown) {
    _setupInitialConnection().then((_) => _setupConnectivityListener());
  }

  factory ConnectionChecker({
    List<InternetAddress>? customCheckAddresses,
    Duration? customCheckTimeout,
    String? baseUrlLookupAddress,
  }) {
    return _singleton ??= ConnectionChecker._(
      checkAddresses: customCheckAddresses,
      checkOverDnsTimeout: customCheckTimeout,
      baseUrlLookupAddress: baseUrlLookupAddress,
    );
  }

  static ConnectionChecker? _singleton;

  final Connectivity _connectivity;
  final ConnectionTypeMapper _connectionTypeMapper;

  final BehaviorSubject<ConnectionType> _connectionTypeStreamController;
  late final StreamSubscription<ConnectionType> _connectionTypeSubscription;

  final List<InternetAddress>? _checkAddresses;
  final Duration? _checkOverDnsTimeout;
  final String? _baseUrlLookupAddress;
  final HostReachabilityChecker _hostReachabilityChecker;

  final Completer<bool> _initialConnectedValue;

  Future<void> dispose() async {
    await _connectionTypeSubscription.cancel();
    await _connectionTypeStreamController.close();
  }

  Future<bool> get isConnected async {
    if (!_initialConnectedValue.isCompleted) {
      return _initialConnectedValue.future;
    } else {
      return _isConnected;
    }
  }

  Stream<bool> get connectionStream => CombineLatestStream([
        _connectionTypeStreamController.stream,
        Stream.periodic(_connectionRequestInterval),
      ], (events) => events.first)
          .flatMap((connectionType) async* {
            final isHostReachable = await _hostReachable;
            if (!isHostReachable) {
              yield false;
            } else {
              if (connectionType is ConnectionType &&
                  connectionType.onlineType) {
                yield true;
              } else {
                yield false;
              }
            }
          })
          .scan<int>(
            (attempts, hostReachable, _) {
              if (!hostReachable) {
                return attempts + 1;
              } else {
                return 0;
              }
            },
            0,
          )
          .where((attemps) =>
              attemps >= _connectionFailureAttempts || attemps == 0)
          .switchMap((attemps) async* {
            final hostReachable =
                attemps >= _connectionFailureAttempts ? false : true;

            if (hostReachable) {
              final baseUrlReachable = await _baseUrlReachable;
              yield baseUrlReachable;
            } else {
              yield false;
            }
          })
          .distinct();

  ConnectionType get connectionType {
    return _connectionTypeStreamController.stream.value;
  }

  Future<void> untilConnects() async {
    await connectionStream.where((event) => event == true).first;
  }

  Future<bool> get _isConnected async {
    final reachability = await Future.wait([_hostReachable, _baseUrlReachable]);
    final isHostReachable =
        reachability.every((reachable) => reachable == true);

    return isHostReachable;
  }

  Future<bool> get _hostReachable async {
    final hostReachable = await _hostReachabilityChecker.canReachAnyHost(
      internetAddresses: _checkAddresses,
      timeout: _checkOverDnsTimeout,
    );
    return hostReachable;
  }

  Future<bool> get _baseUrlReachable async {
    if (_baseUrlLookupAddress != null && _baseUrlLookupAddress!.isNotEmpty) {
      final result = await _hostReachabilityChecker.hostLookup(
        baseUrl: _baseUrlLookupAddress!,
      );
      return result;
    } else {
      return true;
    }
  }

  Future<void> _setupInitialConnection() async {
    final isConnectedResult = await _isConnected;
    _initialConnectedValue.complete(isConnectedResult);

    final connectivityResult = await _connectivity.checkConnectivity();
    final type = _connectionTypeMapper.call(connectivityResult);
    _connectionTypeStreamController.add(type);
  }

  void _setupConnectivityListener() {
    _connectionTypeSubscription = _connectivity.onConnectivityChanged
        .map(_connectionTypeMapper.call)
        .listen((type) {
      _connectionTypeStreamController.add(type);
    });
  }
}
