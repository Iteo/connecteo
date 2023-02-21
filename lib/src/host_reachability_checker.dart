import 'dart:io';

const _dnsPort = 53;

const _defaultTimeout = Duration(seconds: 3);

final _defaultAddresses = List<InternetAddress>.unmodifiable([
  InternetAddress(
    '1.1.1.1', // CloudFlare
    type: InternetAddressType.IPv4,
  ),
  InternetAddress(
    '8.8.4.4', // Google
    type: InternetAddressType.IPv4,
  ),
  InternetAddress(
    '208.67.222.222', // OpenDNS
    type: InternetAddressType.IPv4,
  ),
]);

abstract class HostReachabilityChecker {
  Future<bool> hostLookup({required String baseUrl});

  Future<bool> canReachAnyHost({
    List<InternetAddress>? internetAddresses,
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
    List<InternetAddress>? internetAddresses,
    Duration? timeout,
  }) async {
    final addresses = internetAddresses ?? _defaultAddresses;
    final connectionResults = await Future.wait(
      addresses.map(
        (host) => _canReachHost(
          address: host.address,
          timeout: timeout ?? _defaultTimeout,
        ),
      ),
    );

    return connectionResults.any((result) => result == true);
  }

  Future<bool> _canReachHost({
    required String address,
    required Duration timeout,
  }) async {
    try {
      final socket = await Socket.connect(
        address,
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
