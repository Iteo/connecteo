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

  group('hostLookup', () {
    test('should return true if host of the provided address can be lookup',
        () async {
      hostReachabilityChecker =
          DefaultHostReachabilityChecker(baseUrl: googleUrl.host);
      final result = await hostReachabilityChecker.hostLookup();

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
      hostReachabilityChecker =
          DefaultHostReachabilityChecker(baseUrl: baseUrl);
      final result = await hostReachabilityChecker.hostLookup();

      expect(result, false);
    });
  });

  group('canReachAnyHost', () {
    test('should return true if at least one host is reachable', () async {
      final addresses = [googleIpAddress, localhostIpAddress, googleUrl];

      hostReachabilityChecker =
          DefaultHostReachabilityChecker(connectionEntries: addresses);
      final result = await hostReachabilityChecker.canReachAnyHost();

      expect(result, true);
    });

    test('should return false if all hosts are not reachable', () async {
      hostReachabilityChecker = DefaultHostReachabilityChecker(
        connectionEntries: [localhostIpAddress],
        checkHostReachability: false,
      );
      final result = await hostReachabilityChecker.canReachAnyHost();

      expect(result, false);
    });

    test(
        'should return true if socket connection (to all hosts) opens due to a correct port on connection setup',
        () async {
      final addresses = [googleUrlWithPort];

      hostReachabilityChecker =
          DefaultHostReachabilityChecker(connectionEntries: addresses);
      final result = await hostReachabilityChecker.canReachAnyHost();

      expect(result, true);
    });

    test(
        'should return false if socket connection (to all hosts) fails due to a wrong port on connection setup',
        () async {
      hostReachabilityChecker =
          DefaultHostReachabilityChecker(connectionEntries: [googleUrl]);
      final result = await hostReachabilityChecker.canReachAnyHost();

      expect(result, false);
    });
  });
}
