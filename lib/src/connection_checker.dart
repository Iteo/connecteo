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

/// The class responsbile for checking and monitoring the actual internet
/// connection by wrapping the [Connectivity] class and adding some extra checks.
class ConnectionChecker {
  /// Contructs a singleton of [ConnectionChecker] class.
  ///
  /// The class comes with the list of optional parameters which you can
  /// provide during singleton's init:
  ///
  /// - `checkHostReachabiltiy` - [bool] value which determines if
  /// [ConnectionChecker] should open a socket to a list of addresses.
  /// Such a check provides a reliability when it comes to actual internet
  /// communication, no matter of internet access. Its default value is set
  /// to `true`.
  ///
  /// - `checkAddresses` - a list of custom [InternetAddress] which will be
  /// used to open the socket. The default list contains from three addresses:
  /// to *CloudFlare (1.1.1.1)*, to *Google (8.8.4.4)* and
  /// to *OpenDNS (208.67.222.222)*
  ///
  /// - `checkOverDnsTimeout` - a [Duration] which is being used for the timeout
  ///  for each [InternetAddress] and its socket's opening. The default value
  /// here are 3 seconds.
  ///
  /// - `baseUrlLookupAddress` - a [String] URL which indicates the address
  /// you want to lookup during connection checks. It may be helpful when you
  /// coming from offline to online state, got the reachability from
  /// `checkAddresses` but calls to your server side end up with the
  /// [SocketException] for few seconds. Once you provide your URL,
  /// the [connectionStream] and [isConnected] will return true values only
  /// after successful host lookup. Its default value is `null`.
  ///
  /// - `reguestInterval` - a [Duration] which is being used for the interval
  /// how often the internet connection status should be refreshed. By default
  /// its value is set to 3 seconds.
  ///
  /// - `failureAttempts` - the number of maximum trials between changing the
  /// online to offline state. If the internet connection will be lost, the
  /// [ConnectionChecker] will try to reconnect by every `requestInterval`.
  /// When the lost connection won't go back after number of `failureAttempts`,
  /// the [connectionStream] and [isConnected] will return false values until
  /// connection get back. The default value is set to 4 attempts.
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

  /// Constructs a special [ConnectionChecker] instance, for the sake of
  /// unit testing.
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

  /// Returns the reliable internet connection status every time when either
  /// [Connectivity.onConnectivityChanged] fires or provided in constructor's
  /// `requestInterval` goes by.
  ///
  /// The detected event has to go through several checks which help assess
  /// if online connection is actually online:
  /// - A new (or previous) connection type has to be online;
  /// - A socket has to be opened and successfully checked over DNS port against
  /// at least one IP address (from `checkAddresses`);
  /// - A response from optional `baseUrlLookupAddress` has to be successful if
  /// address was provided.
  Stream<bool> get connectionStream => CombineLatestStream(
        [
          _connectivity.onConnectivityChanged.map(_connectionTypeMapper.call),
          Stream<void>.periodic(_requestInterval),
        ],
        // ignore: cast_nullable_to_non_nullable
        (events) => events.first as ConnectionType,
      )
          .flatMap(_isConnectionTypeReachableStream)
          .scan<int>(_accumulateFailures, 0)
          .where(_isNotTryingToReconnect)
          .switchMap(_isBaseUrlReachableStream)
          .distinct();

  /// Returns the actual, reliable internet connection status for
  /// the present moment.
  ///
  /// In order to determine internet connection status,
  /// it uses the same list of checks which [connectionStream] does.
  ///
  /// Keep in mind the connection status may change over time - in that case,
  /// it is more secure to listen for [connectionStream].
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    final isConnectionTypeOnline =
        _connectionTypeMapper.call(result).onlineType;

    final reachability = await Future.wait([_hostReachable, _baseUrlReachable]);
    final isHostReachable = [isConnectionTypeOnline, ...reachability]
        .every((reachable) => reachable == true);

    return isHostReachable;
  }

  /// Returns the current [ConnectionType] of your device.
  ///
  /// Do not use it for determination of your current connection status - this
  /// getter only provides the information about current connection type,
  /// nothing more. It means that being under [ConnectionType.wifi] or
  /// [ConnectionType.vpn] does not guarantee you have got internet connection.
  /// However, it may be helpful when you want to implement specific logic for
  /// cellular data connection for example.
  Future<ConnectionType> get connectionType async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return _connectionTypeMapper.call(connectivityResult);
  }

  /// Resolves as soon as internet connection status get back from offline state.
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
