import 'package:connecteo/src/connection_entry.dart';

const dnsPort = 53;

const defaultTimeout = Duration(seconds: 3);

abstract class HostReachabilityChecker {
  Future<bool> hostLookup({required String baseUrl});

  Future<bool> canReachAnyHost({
    List<ConnectionEntry>? internetAddresses,
    Duration? timeout,
  });
}
