import 'dart:math';

import 'package:connecteo/src/connection_entry.dart';
import 'package:connecteo/src/host_reachability_checker.dart';
import 'package:test/test.dart';

final googleIpAddress = ConnectionEntry.fromIpAddress(
  '8.8.4.4',
);
final localhostIpAddress = ConnectionEntry.fromIpAddress(
  '127.0.0.1',
);
final googleUrlWithPort = ConnectionEntry.fromUrl(
  'google.com',
  port: 443,
);
final googleUrl = ConnectionEntry.fromUrl(
  'https://google.com',
);

void main() {
  late HostReachabilityChecker hostReachabilityChecker;

  setUpAll(() {
    hostReachabilityChecker = DefaultHostReachabilityChecker();
  });

  group('hostLookup', () {
    test('should return true if host of the provided address can be lookup',
        () async {
      final result =
          await hostReachabilityChecker.hostLookup(baseUrl: googleUrl.host);

      expect(result, true);
    });

    test(
        'should return false if host of the provided address can not be lookup',
        () async {
      const chars =
          'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
      final randomChars =
          List.generate(30, (index) => chars[Random().nextInt(chars.length)])
              .join();
      final baseUrl = 'https://$randomChars';

      final result = await hostReachabilityChecker.hostLookup(baseUrl: baseUrl);

      expect(result, false);
    });
  });

  group('canReachAnyHost', () {
    test('should return true if at least one host is reachable', () async {
      final addresses = [googleIpAddress, localhostIpAddress, googleUrl];

      final result = await hostReachabilityChecker.canReachAnyHost(
        connectionEntries: addresses,
      );

      expect(result, true);
    });

    test('should return false if all hosts are not reachable', () async {
      final result = await hostReachabilityChecker
          .canReachAnyHost(connectionEntries: [localhostIpAddress]);

      expect(result, false);
    });

    test(
        'should return true if socket connection (to all hosts) opens due to a correct port on connection setup',
        () async {
      final addresses = [googleUrlWithPort];

      final result = await hostReachabilityChecker.canReachAnyHost(
        connectionEntries: addresses,
      );

      expect(result, true);
    });

    test(
        'should return false if socket connection (to all hosts) fails due to a wrong port on connection setup',
        () async {
      final result = await hostReachabilityChecker
          .canReachAnyHost(connectionEntries: [googleUrl]);

      expect(result, false);
    });
  });
}
