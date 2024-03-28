import 'dart:io';

import 'package:connecteo/src/connection_entry.dart';
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

abstract class HostReachabilityChecker {
  Future<bool> hostLookup({required String baseUrl});

  Future<bool> canReachAnyHost({
    List<ConnectionEntry>? connectionEntries,
    Duration? timeout,
  });
}

class DefaultHostReachabilityChecker implements HostReachabilityChecker {
  @override
  Future<bool> hostLookup({required String baseUrl}) async {
    try {
      final host = Uri.parse(baseUrl).host;
      await InternetAddress.lookup(host);

      return true;
    } on SocketException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canReachAnyHost({
    List<ConnectionEntry>? connectionEntries,
    Duration? timeout,
  }) async {
    final addresses = connectionEntries ?? _defaultIpAddresses;
    final connectionResults = await Future.wait(
      addresses.map(
        (host) => _canIoReachHost(
          entry: host,
          timeout: timeout ?? _defaultTimeout,
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

class WebHostReachabilityChecker implements HostReachabilityChecker {
  @override
  Future<bool> hostLookup({required String baseUrl}) async {
    try {
      final uri = Uri.parse(baseUrl);
      final result = await http.head(uri);

      return (result.statusCode == HttpStatus.ok);
    } on SocketException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canReachAnyHost({
    List<ConnectionEntry>? connectionEntries,
    Duration? timeout,
  }) async {
    final addresses = connectionEntries ?? _defaultUrls;
    final connectionResults = await Future.wait(
      addresses.map(
        (host) => _canWebReachHost(
          entry: host,
          timeout: timeout ?? _defaultTimeout,
        ),
      ),
    );

    return connectionResults.any((result) => result);
  }

  Future<bool> _canWebReachHost({
    required ConnectionEntry entry,
    required Duration timeout,
  }) async {
    try {
      final uri = Uri.parse(entry.host);
      final result = await http.get(uri);

      return (result.statusCode == HttpStatus.ok);
    } catch (_) {
      return false;
    }
  }
}
