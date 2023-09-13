import 'dart:io';

import 'package:connecteo/connecteo.dart';
import 'package:connecteo/src/connection_entry.dart';
import 'package:connecteo/src/host_reachability_checker.dart';

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

HostReachabilityChecker createChecker() => NativeHostReachabilityChecker();

class NativeHostReachabilityChecker implements HostReachabilityChecker {
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
          timeout: timeout ?? defaultTimeout,
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
        dnsPort,
        timeout: timeout,
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
