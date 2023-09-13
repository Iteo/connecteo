import 'dart:math';

import 'package:connecteo/src/connection_entry.dart';
import 'package:connecteo/src/connection_entry_type.dart';
import 'package:connecteo/src/host_reachability_checker.dart';
import 'package:connecteo/src/host_reachability_checker_stub.dart'
  if (dart.library.html) 'package:connecteo/src/checkers/web_host_reachability_checker.dart'
  if (dart.library.io) 'package:connecteo/src/checkers/native_host_reachability_checker.dart';
import 'package:test/test.dart';

final googleInternetAddress = ConnectionEntry(
  '8.8.4.4',
  ConnectionEntryType.ip,
);

final localhostAddress = ConnectionEntry(
  '127.0.0.1',
  ConnectionEntryType.ip,
);

const googleUrl = 'https://google.com/';

void main() {
  late HostReachabilityChecker hostReachabilityChecker;

  setUpAll(() {
    hostReachabilityChecker = createChecker();
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
