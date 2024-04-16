import 'dart:async';
import 'dart:io';

import 'package:connecteo/src/connection_entry.dart';
import 'package:connecteo/src/connection_type.dart';
import 'package:connecteo/src/connection_type_mapper.dart';
import 'package:connecteo/src/host_reachability_checker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

const _defaultRequestInterval = Duration(seconds: 3);

const _defaultFailureAttempts = 4;

/// The class is responsbile for checking and monitoring the actual internet
/// connection by wrapping the [Connectivity] class and adding some extra checks.
class ConnectionChecker {
  /// Contructs an instance of the [ConnectionChecker] class.
  ///
  /// The class comes with the list of optional parameters which you can
  /// provide during init:
  ///
  /// - `checkHostReachabiltiy` - [bool] value, which determines if
  /// [ConnectionChecker] should open the socket connections on native platforms
  /// (or make an http call on the Web platform) against the list of addresses.
  /// Such a check provides reliability when it comes to the actual internet
  /// communication, no matter of internet access. Its default value is set
  /// to `true`.
  ///
  /// - `checkConnectionEntriesNative` - a list of custom [ConnectionEntry] which
  /// will be used to open the socket. This list should be used only on native platforms.
  /// The default list contains the following addresses: *CloudFlare (1.1.1.1)*
  /// , *Google (8.8.4.4)* and *OpenDNS (208.67.222.222)*
  ///
  /// - `checkConnectionEntriesWeb` - a list of custom [ConnectionEntry] URLs that
  /// will be used to make requests on the Web. This list should be used only
  /// on the Web platform. The default list contains three urls:
  /// 'https://one.one.one.one',
  /// 'https://jsonplaceholder.typicode.com/posts/1,
  /// 'http://worldtimeapi.org/api/timezone'
  ///
  /// - `hostReachabilityTimeout` - a [Duration] that is being used for the timeout
  /// for each [ConnectionEntry] and its socket's opening. The default value
  /// here are 3 seconds.
  ///
  /// - `baseUrlLookupAddress` - a [String] URL that indicates the address
  /// you want to lookup during connection checks. It may be helpful when you
  /// coming from offline to online state, got the reachability from
  /// [checkConnectionEntriesNative] (or [checkConnectionEntriesWeb], depending  on
  /// the platform), but calls to your server side end up with the [SocketException]
  /// for few seconds. Once you provide your URL, the [connectionStream] and
  /// [isConnected] will return true values only after a successful host lookup.
  /// Its default value is `null`.
  ///
  /// - `reguestInterval` - a [Duration] that is being used for the interval
  /// how often the internet connection status should be refreshed. By default
  /// its value is set to 3 seconds.
  ///
  /// - `failureAttempts` - the number of maximum trials between changing the
  /// online to offline state. If the internet connection is lost, the
  /// [ConnectionChecker] will try to reconnect by every [requestInterval].
  /// When the lost connection won't go back after a number of [failureAttempts],
  /// the [connectionStream] and [isConnected] will return false values until
  /// connection get back. The default value is set to 4 attempts.
  factory ConnectionChecker({
    bool checkHostReachability = true,
    List<ConnectionEntry>? checkConnectionEntriesNative,
    List<ConnectionEntry>? checkConnectionEntriesWeb,
    Duration? hostReachabilityTimeout,
    String? baseUrlLookupAddress,
    Duration? requestInterval,
    int? failureAttempts,
  }) {
    return ConnectionChecker._(
      checkConnectionEntriesNative: checkConnectionEntriesNative,
      checkConnectionEntriesWeb: checkConnectionEntriesWeb,
      hostReachabilityTimeout: hostReachabilityTimeout,
      baseUrlLookupAddress: baseUrlLookupAddress,
      checkHostReachability: checkHostReachability,
      failureAttempts: failureAttempts,
      requestInterval: requestInterval,
    );
  }

  /// Factory method an instance of the [ConnectionChecker] class.
  ///
  /// - `hostReachabilityChecker` - [HostReachabilityChecker] is custom
  /// implementation of network checking methods, which is used by
  /// [ConnectionChecker].
  ///
  /// - `reguestInterval` - a [Duration] that is being used for the interval
  /// how often the internet connection status should be refreshed. By default
  /// its value is set to 3 seconds.
  ///
  /// - `failureAttempts` - the number of maximum trials between changing the
  /// online to offline state. If the internet connection is lost, the
  /// [ConnectionChecker] will try to reconnect by every [requestInterval].
  /// When the lost connection won't go back after a number of [failureAttempts],
  /// the [connectionStream] and [isConnected] will return false values until
  /// connection get back. The default value is set to 4 attempts.
  factory ConnectionChecker.fromReachabilityChecker({
    required HostReachabilityChecker hostReachabilityChecker,
    Duration? requestInterval,
    int? failureAttempts,
  }) {
    return ConnectionChecker._(
      checkHostReachability: true,
      failureAttempts: failureAttempts,
      requestInterval: requestInterval,
      hostReachabilityChecker: hostReachabilityChecker,
    );
  }

  ConnectionChecker._({
    required bool checkHostReachability,
    List<ConnectionEntry>? checkConnectionEntriesNative,
    List<ConnectionEntry>? checkConnectionEntriesWeb,
    Duration? hostReachabilityTimeout,
    String? baseUrlLookupAddress,
    Duration? requestInterval,
    int? failureAttempts,
    Connectivity? connectivity,
    HostReachabilityChecker? hostReachabilityChecker,
    Mapper<List<ConnectivityResult>, List<ConnectionType>>?
        connectionTypeMapper,
  })  : _checkHostReachability = checkHostReachability,
        _failureAttempts = failureAttempts ?? _defaultFailureAttempts,
        _requestInterval = requestInterval ?? _defaultRequestInterval,
        _connectivity = connectivity ?? Connectivity(),
        _connectionTypeMapper = connectionTypeMapper ?? ConnectionTypeMapper(),
        _hostReachabilityChecker = hostReachabilityChecker ??
            HostReachabilityChecker.create(
              baseUrl: baseUrlLookupAddress,
              connectionEntries: kIsWeb
                  ? checkConnectionEntriesWeb
                  : checkConnectionEntriesNative,
              timeout: hostReachabilityTimeout,
            );

  /// Constructs a special [ConnectionChecker] instance, for the sake of
  /// unit testing.
  @visibleForTesting
  factory ConnectionChecker.test({
    required Connectivity connectivity,
    required HostReachabilityChecker hostReachabilityChecker,
    required Mapper<List<ConnectivityResult>, List<ConnectionType>>
        connectionTypeMapper,
    bool checkHostReachability = true,
    List<ConnectionEntry>? checkConnectionEntriesNative,
    List<ConnectionEntry>? checkConnectionEntriesWeb,
    Duration? hostReachabilityTimeout,
    String? baseUrlLookupAddress,
    Duration? requestInterval,
    int? failureAttempts,
  }) {
    return ConnectionChecker._(
      checkHostReachability: checkHostReachability,
      hostReachabilityChecker: hostReachabilityChecker,
      connectionTypeMapper: connectionTypeMapper,
      connectivity: connectivity,
      checkConnectionEntriesNative: checkConnectionEntriesNative,
      checkConnectionEntriesWeb: checkConnectionEntriesWeb,
      hostReachabilityTimeout: hostReachabilityTimeout,
      baseUrlLookupAddress: baseUrlLookupAddress,
      failureAttempts: failureAttempts,
      requestInterval: requestInterval,
    );
  }

  final Connectivity _connectivity;
  final Mapper<List<ConnectivityResult>, List<ConnectionType>>
      _connectionTypeMapper;

  final bool _checkHostReachability;
  final Duration _requestInterval;
  final int _failureAttempts;

  final HostReachabilityChecker _hostReachabilityChecker;

  /// Returns the reliable internet connection status every time when either
  /// [Connectivity.onConnectivityChanged] fires or provided in constructor's
  /// `requestInterval` goes by.
  ///
  /// The detected event has to go through several checks, which help assess
  /// if online connection is actually online:
  /// - A new (or previous) connection type has to be online;
  /// - (On native platforms) A socket connection has to be opened and successfully
  /// established against at least one address (from `checkConnectionEntriesNative`
  /// or default [HostReachabilityChecker] addresses);
  /// - (On the Web platform) A response from an http call has to return 200 status code
  /// for at least one URL (from `checkConnectionEntriesWeb` or default
  /// [HostReachabilityChecker] URLs);
  /// - A response from the optional `baseUrlLookupAddress` has to be successful if
  /// address was provided.
  Stream<bool> get connectionStream => CombineLatestStream(
        [
          ConcatStream([
            _connectivity
                .checkConnectivity()
                .asStream()
                .map(_connectionTypeMapper.call),
            _connectivity.onConnectivityChanged.map(_connectionTypeMapper.call),
          ]),
          Stream<void>.periodic(_requestInterval),
        ],
        // ignore: cast_nullable_to_non_nullable
        (events) => events.first as List<ConnectionType>,
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
    final isConnectionTypesContainsOnline =
        _connectionTypeMapper.call(result).containsOnline;

    final reachability = await Future.wait([_hostReachable, _baseUrlReachable]);
    final isHostReachable = [isConnectionTypesContainsOnline, ...reachability]
        .every((reachable) => reachable);

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
  Future<List<ConnectionType>> get connectionTypes async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return _connectionTypeMapper.call(connectivityResult);
  }

  /// Resolves as soon as internet connection status get back from offline state.
  Future<void> untilConnects() async {
    await connectionStream.where((event) => event).first;
  }

  Stream<bool> _isConnectionTypeReachableStream(
    List<ConnectionType> connectionTypeList,
  ) async* {
    final isHostReachable = await _hostReachable;
    if (!isHostReachable) {
      yield false;
    } else {
      if (connectionTypeList.containsOnline) {
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
    return _checkHostReachability
        ? await _hostReachabilityChecker.canReachAnyHost()
        : true;
  }

  Future<bool> get _baseUrlReachable async {
    return _hostReachabilityChecker.hasBaseUrl
        ? await _hostReachabilityChecker.hostLookup()
        : true;
  }
}
