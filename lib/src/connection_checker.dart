import 'dart:async';
import 'dart:io';

import 'package:connecteo/src/connection_type.dart';
import 'package:connecteo/src/connection_type_mapper.dart';
import 'package:connecteo/src/host_reachability_checker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
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
    Connectivity? connectivity,
    HostReachabilityChecker? hostReachabilityChecker,
    Mapper<ConnectivityResult, ConnectionType>? connectionTypeMapper,
  })  : _checkHostReachability = checkHostReachability,
        _checkAddresses = checkAddresses,
        _checkOverDnsTimeout = checkOverDnsTimeout,
        _baseUrlLookupAddress = baseUrlLookupAddress,
        _failureAttempts = failureAttempts ?? _defaultFailureAttempts,
        _requestInterval = requestInterval ?? _defaultRequestInterval,
        _connectivity = connectivity ?? Connectivity(),
        _connectionTypeMapper = connectionTypeMapper ?? ConnectionTypeMapper(),
        _hostReachabilityChecker =
            hostReachabilityChecker ?? DefaultHostReachabilityChecker();

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
      failureAttempts: failureAttempts,
      requestInterval: requestInterval,
    );
  }

  @visibleForTesting
  factory ConnectionChecker.test({
    required Connectivity connectivity,
    required HostReachabilityChecker hostReachabilityChecker,
    required Mapper<ConnectivityResult, ConnectionType> connectionTypeMapper,
    bool checkHostReachability = true,
    List<InternetAddress>? checkAddresses,
    Duration? checkOverDnsTimeout,
    String? baseUrlLookupAddress,
    Duration? requestInterval,
    int? failureAttempts,
  }) {
    return ConnectionChecker._(
      checkHostReachability: checkHostReachability,
      hostReachabilityChecker: hostReachabilityChecker,
      connectionTypeMapper: connectionTypeMapper,
      connectivity: connectivity,
      checkAddresses: checkAddresses,
      checkOverDnsTimeout: checkOverDnsTimeout,
      baseUrlLookupAddress: baseUrlLookupAddress,
      failureAttempts: failureAttempts,
      requestInterval: requestInterval,
    );
  }

  static ConnectionChecker? _singleton;

  final Connectivity _connectivity;
  final Mapper<ConnectivityResult, ConnectionType> _connectionTypeMapper;

  final List<InternetAddress>? _checkAddresses;
  final Duration? _checkOverDnsTimeout;
  final String? _baseUrlLookupAddress;
  final bool _checkHostReachability;
  final Duration _requestInterval;
  final int _failureAttempts;

  final HostReachabilityChecker _hostReachabilityChecker;

  Stream<bool> get connectionStream => CombineLatestStream([
        _connectivity.onConnectivityChanged.map(_connectionTypeMapper.call),
        Stream.periodic(_requestInterval),
      ], (events) => events.first as ConnectionType)
          .flatMap(_isConnectionTypeReachableStream)
          .scan<int>(_accumulateFailures, 0)
          .where(_isNotTryingToReconnect)
          .switchMap(_isBaseUrlReachableStream)
          .distinct();

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    final isConnectionTypeOnline =
        _connectionTypeMapper.call(result).onlineType;

    final reachability = await Future.wait([_hostReachable, _baseUrlReachable]);
    final isHostReachable = [isConnectionTypeOnline, ...reachability]
        .every((reachable) => reachable == true);

    return isHostReachable;
  }

  Future<ConnectionType> get connectionType async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return _connectionTypeMapper.call(connectivityResult);
  }

  Future<void> untilConnects() async {
    await connectionStream.where((event) => event).first;
  }

  Stream<bool> _isConnectionTypeReachableStream(
    ConnectionType connectionType,
  ) async* {
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
}
