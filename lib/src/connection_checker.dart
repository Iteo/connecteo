import 'dart:async';
import 'dart:io';

import 'package:connecteo/src/connection_type.dart';
import 'package:connecteo/src/connection_type_mapper.dart';
import 'package:connecteo/src/host_reachability_checker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';

const _defaultRequestInterval = Duration(seconds: 3);

const _defaultFailureAttempts = 4;

class ConnectionChecker {
  ConnectionChecker._({
    required bool checkHostReachability,
    List<InternetAddress>? checkAddresses,
    Duration? checkOverDnsTimeout,
    String? baseUrlLookupAddress,
    Duration? requestInterval,
    int? failureAttempts,
  })  : _checkHostReachability = checkHostReachability,
        _checkAddresses = checkAddresses,
        _checkOverDnsTimeout = checkOverDnsTimeout,
        _baseUrlLookupAddress = baseUrlLookupAddress,
        _failureAttempts = failureAttempts ?? _defaultFailureAttempts,
        _requestInterval = requestInterval ?? _defaultRequestInterval,
        _connectivity = Connectivity(),
        _connectionTypeMapper = ConnectionTypeMapper(),
        _hostReachabilityChecker = HostReachabilityChecker(),
        _initialConnectedValue = Completer() {
    _setupInitialConnection();
  }

  factory ConnectionChecker({
    bool checkHostReachability = true,
    List<InternetAddress>? checkAddresses,
    Duration? checkOverDnsTimeout,
    String? baseUrlLookupAddress,
    Duration? requestInterval,
    int? failureAttempts,
  }) {
    return _singleton ??= ConnectionChecker._(
      checkAddresses: checkAddresses,
      checkOverDnsTimeout: checkOverDnsTimeout,
      baseUrlLookupAddress: baseUrlLookupAddress,
      checkHostReachability: checkHostReachability,
    );
  }

  static ConnectionChecker? _singleton;

  final Connectivity _connectivity;
  final ConnectionTypeMapper _connectionTypeMapper;

  final List<InternetAddress>? _checkAddresses;
  final Duration? _checkOverDnsTimeout;
  final String? _baseUrlLookupAddress;
  final bool _checkHostReachability;
  final Duration _requestInterval;
  final int _failureAttempts;

  final HostReachabilityChecker _hostReachabilityChecker;

  final Completer<bool> _initialConnectedValue;

  Future<bool> get isConnected async {
    if (!_initialConnectedValue.isCompleted) {
      return _initialConnectedValue.future;
    } else {
      return _isConnected;
    }
  }

  Stream<bool> get connectionStream => CombineLatestStream([
        _connectivity.onConnectivityChanged.map(_connectionTypeMapper.call),
        Stream.periodic(_requestInterval),
      ], (events) => events.first as ConnectionType)
          .flatMap(_isConnectionTypeReachableStream)
          .scan<int>(_accumulateFailures, 0)
          .where(_isNotTryingToReconnect)
          .switchMap(_isBaseUrlReachableStream)
          .distinct();

  Future<ConnectionType> get connectionType async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return _connectionTypeMapper.call(connectivityResult);
  }

  Future<void> untilConnects() async {
    await connectionStream.where((event) => event == true).first;
  }

  Stream<bool> _isConnectionTypeReachableStream(
      ConnectionType connectionType) async* {
    final isHostReachable = await _hostReachable;
    if (!isHostReachable) {
      yield false;
    } else {
      if (connectionType.onlineType) {
        yield true;
      } else {
        yield false;
      }
    }
  }

  int _accumulateFailures(int attempts, bool hostReachable, int index) {
    if (!hostReachable) {
      return attempts + 1;
    } else {
      return 0;
    }
  }

  bool _isNotTryingToReconnect(int attempts) {
    return attempts >= _failureAttempts || attempts == 0;
  }

  Stream<bool> _isBaseUrlReachableStream(int attempts) async* {
    final hostReachable = attempts >= _failureAttempts ? false : true;

    if (hostReachable) {
      final baseUrlReachable = await _baseUrlReachable;
      yield baseUrlReachable;
    } else {
      yield false;
    }
  }

  Future<bool> get _isConnected async {
    final reachability = await Future.wait([_hostReachable, _baseUrlReachable]);
    final isHostReachable =
        reachability.every((reachable) => reachable == true);

    return isHostReachable;
  }

  Future<bool> get _hostReachable async {
    final hostReachable = _checkHostReachability
        ? await _hostReachabilityChecker.canReachAnyHost(
            internetAddresses: _checkAddresses,
            timeout: _checkOverDnsTimeout,
          )
        : true;
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
  }
}
