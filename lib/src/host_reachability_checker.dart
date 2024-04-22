import 'dart:io';

import 'package:connecteo/src/connection_entry.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _dnsPort = 53;

const _defaultTimeout = Duration(seconds: 3);

final _defaultIpAddresses = List<ConnectionEntry>.unmodifiable([
  ConnectionEntry.fromIpAddress(
    '1.1.1.1',
  ),
  ConnectionEntry.fromIpAddress(
    '8.8.4.4',
  ),
  ConnectionEntry.fromIpAddress(
    '208.67.222.222',
  ),
]);

final _defaultUrls = List<ConnectionEntry>.unmodifiable([
  ConnectionEntry.fromUrl(
    'https://one.one.one.one',
  ),
  ConnectionEntry.fromUrl(
    'https://jsonplaceholder.typicode.com/posts/1',
  ),
  ConnectionEntry.fromUrl(
    'http://worldtimeapi.org/api/timezone',
  ),
]);

/// A class for custom implementation how the desired hosts are reached.
///
/// This abstract class provides a contract used by ConnectionChecker class.
/// The contract assumes own implementation of methods to perform
/// host lookup of desired url along with the reachabiltiy of provided hosts.
///
/// Example usage:
/// ```dart
/// class CustomReachabilityChecker extends HostReachabilityChecker { [...] }
///
/// final connecteo =  ConnectionChecker.fromReachabilityChecker(
///   hostReachabilityChecker: CustomReachabilityChecker(), [...]
/// );
/// ```
abstract class HostReachabilityChecker {
  /// Performs a host lookup to determine if the host is reachable.
  ///
  /// Returns a [Future] that completes with a boolean value indicating whether
  /// the host is reachable or not.
  Future<bool> hostLookup();

  /// Check if desired hosts are reachable (e.g. via opening a socket
  /// connection to each address)
  ///
  /// Returns a [Future] that completes with a boolean value indicating whether
  /// host can be reached or not.
  Future<bool> canReachAnyHost();
}

HostReachabilityChecker getPlatformHostReachabilityChecker({
  String? baseUrl,
  List<ConnectionEntry>? connectionEntries,
  Duration? timeout,
}) {
  if (kIsWeb) {
    return WebHostReachabilityChecker(
      baseUrl: baseUrl,
      connectionEntries: connectionEntries,
    );
  } else {
    return DefaultHostReachabilityChecker(
      baseUrl: baseUrl,
      connectionEntries: connectionEntries,
      timeout: timeout,
    );
  }
}

class DefaultHostReachabilityChecker extends HostReachabilityChecker {
  DefaultHostReachabilityChecker({
    String? baseUrl,
    List<ConnectionEntry>? connectionEntries,
    Duration? timeout,
  })  : _baseUrl = baseUrl ?? '',
        _connectionEntries = connectionEntries ?? _defaultIpAddresses,
        _timeout = timeout ?? _defaultTimeout;

  final String _baseUrl;
  final List<ConnectionEntry> _connectionEntries;
  final Duration _timeout;

  @override
  Future<bool> hostLookup() async {
    if (_baseUrl.isEmpty) return false;

    try {
      final host = Uri.parse(_baseUrl).host;
      await InternetAddress.lookup(host);

      return true;
    } on SocketException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canReachAnyHost() async {
    final connectionResults = await Future.wait(
      _connectionEntries.map(
        (host) => _canIoReachHost(
          entry: host,
          timeout: _timeout,
        ),
      ),
    );

    return connectionResults.any((result) => result);
  }

  Future<bool> _canIoReachHost({
    required ConnectionEntry entry,
    required Duration timeout,
  }) async {
    try {
      final socket = await Socket.connect(
        entry.host,
        entry.port ?? _dnsPort,
        timeout: timeout,
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class WebHostReachabilityChecker extends HostReachabilityChecker {
  WebHostReachabilityChecker({
    String? baseUrl,
    List<ConnectionEntry>? connectionEntries,
  })  : _baseUrl = baseUrl ?? '',
        _connectionEntries = connectionEntries ?? _defaultUrls;

  final String _baseUrl;
  final List<ConnectionEntry> _connectionEntries;

  @override
  Future<bool> hostLookup() async {
    if (_baseUrl.isEmpty) return false;

    try {
      final uri = Uri.parse(_baseUrl);
      final result = await http.head(uri);

      return (result.statusCode == HttpStatus.ok);
    } on SocketException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canReachAnyHost() async {
    final connectionResults = await Future.wait(
      _connectionEntries.map(
        (host) => _canWebReachHost(
          entry: host,
        ),
      ),
    );

    return connectionResults.any((result) => result);
  }

  Future<bool> _canWebReachHost({
    required ConnectionEntry entry,
  }) async {
    try {
      final uri = Uri.parse(entry.host);
      final result = await http.get(
        uri,
        headers: {'accept': 'application/dns-json'},
      );

      return (result.statusCode == HttpStatus.ok);
    } catch (_) {
      return false;
    }
  }
}
