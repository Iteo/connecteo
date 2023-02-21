import 'dart:io';
import 'dart:math';

import 'package:connecteo/src/host_reachability_checker.dart';
import 'package:test/test.dart';

final googleInternetAddress = InternetAddress(
  '8.8.4.4',
  type: InternetAddressType.IPv4,
);

final localhostAddress = InternetAddress(
  '127.0.0.1',
  type: InternetAddressType.IPv4,
);

const googleUrl = 'https://google.com/';

void main() {
  late HostReachabilityChecker hostReachabilityChecker;

  setUpAll(() {
    hostReachabilityChecker = DefaultHostReachabilityChecker();
  });

  group('hostLookup', () {
    test('should return true if host of the provided address can be lookup',
        () async {
      final result =
          await hostReachabilityChecker.hostLookup(baseUrl: googleUrl);

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
    test('should return true if at least one address is reachable', () async {
      final addresses = [googleInternetAddress, localhostAddress];

      final result = await hostReachabilityChecker.canReachAnyHost(
        internetAddresses: addresses,
      );

      expect(result, true);
    });

    test('should return false if all addresses are not reachable', () async {
      final result = await hostReachabilityChecker
          .canReachAnyHost(internetAddresses: [localhostAddress]);

      expect(result, false);
    });
  });
}
