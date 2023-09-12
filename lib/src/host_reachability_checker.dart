import 'dart:io';

import 'package:connecteo/src/connection_entry.dart';
import 'package:connecteo/src/connection_entry_type.dart';
import 'package:http/http.dart' as http;

const _dnsPort = 53;

const _defaultTimeout = Duration(seconds: 3);

final _defaultAddresses = List<ConnectionEntry>.unmodifiable([
  ConnectionEntry(
    '1.1.1.1',
    ConnectionEntryType.ip,
  ),
  ConnectionEntry(
    '8.8.4.4',
    ConnectionEntryType.ip,
  ),
  ConnectionEntry(
    '208.67.222.222',
    ConnectionEntryType.ip,
  ),
]);

final _defaultUrls = List<ConnectionEntry>.unmodifiable([
  ConnectionEntry(
    'https://1.1.1.1',
    ConnectionEntryType.apiUrl,
  ),
  // ConnectionEntry(
  //   'https://jsonplaceholder.typicode.com/posts/1',
  //   ConnectionEntryType.apiUrl,
  // ),
  // ConnectionEntry(
  //   'http://worldtimeapi.org/api/timezone',
  //   ConnectionEntryType.apiUrl,
  // ),
]);

abstract class HostReachabilityChecker {
  Future<bool> hostLookup({required String baseUrl});

  Future<bool> canReachAnyHost({
    List<ConnectionEntry>? internetAddresses,
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
    List<ConnectionEntry>? internetAddresses,
    Duration? timeout,
  }) async {
    final addresses = internetAddresses ?? _defaultAddresses;
    final connectionResults = await Future.wait(
      addresses.map(
        (host) => _canReachHost(
          address: host,
          timeout: timeout ?? _defaultTimeout,
        ),
      ),
    );

    return connectionResults.any((result) => result == true);
  }

  Future<bool> _canReachHost({
    required ConnectionEntry address,
    required Duration timeout,
  }) async {
    try {
      final socket = await Socket.connect(
        InternetAddress(address.host),
        _dnsPort,
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
      if (result.statusCode == 200) return true;
      return false;
    } on SocketException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canReachAnyHost({
    List<ConnectionEntry>? internetAddresses,
    Duration? timeout,
  }) async {
    final addresses = internetAddresses ?? _defaultUrls;
    final connectionResults = await Future.wait(
      addresses.map(
        (host) => _canReachHost(
          address: host,
          timeout: timeout ?? _defaultTimeout,
        ),
      ),
    );

    return connectionResults.any((result) => result == true);
  }

  Future<bool> _canReachHost({
    required ConnectionEntry address,
    required Duration timeout,
  }) async {
    try {
      final uri = Uri.parse(address.host);
      final result = await http.get(uri);
      if (result.statusCode == 200) return true;
      return false;
    } catch (_) {
      return false;
    }
  }
}
