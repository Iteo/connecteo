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

abstract class HostReachabilityChecker {
  HostReachabilityChecker({
    required this.baseUrl,
    required this.connectionEntries,
    required this.timeout,
  });

  factory HostReachabilityChecker.create({
    required String? baseUrl,
    required List<ConnectionEntry>? connectionEntries,
    required Duration? timeout,
  }) =>
      kIsWeb
          ? WebHostReachabilityChecker(
              baseUrl: baseUrl,
              connectionEntries: connectionEntries,
              timeout: timeout,
            )
          : DefaultHostReachabilityChecker(
              baseUrl: baseUrl,
              connectionEntries: connectionEntries,
              timeout: timeout,
            );

  final String? baseUrl;
  final List<ConnectionEntry>? connectionEntries;
  final Duration? timeout;

  bool get hasBaseUrl => _baseUrl.isNotEmpty;

  String get _baseUrl => baseUrl ?? '';

  Future<bool> hostLookup();

  Future<bool> canReachAnyHost();
}

class DefaultHostReachabilityChecker extends HostReachabilityChecker {
  DefaultHostReachabilityChecker({
    super.baseUrl,
    super.connectionEntries,
    super.timeout,
  });

  @override
  Future<bool> hostLookup() async {
    if (!hasBaseUrl) return false;

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

class WebHostReachabilityChecker extends HostReachabilityChecker {
  WebHostReachabilityChecker({
    super.baseUrl,
    super.connectionEntries,
    super.timeout,
  });

  @override
  Future<bool> hostLookup() async {
    if (!hasBaseUrl) return false;

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
