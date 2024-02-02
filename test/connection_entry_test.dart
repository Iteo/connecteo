import 'package:connecteo/src/connection_entry.dart';
import 'package:connecteo/src/connection_entry_type.dart';
import 'package:test/test.dart';

void main() {
  const invalidIpv4 = '1.2.3.320';
  const invalidIpv6 = '2001:0db8:85a3:0000:0000:8a2e:0370:7334:320';

  const validIpv4 = '1.1.1.1';
  const validIpv6 = '2001:0db8:85a3:0000:0000:8a2e:0370:7334';

  const invalidUrl = 'https://.com.pl';
  const validUrl = 'http://www.google.com';

  group('Check ConnectionEntry for ip', () {
    test('throws an exception when ip is invalid ipV4', () {
      expect(
        () => ConnectionEntry(invalidIpv4, ConnectionEntryType.ip),
        throwsException,
      );
    });

    test('does not throw an error when ip is valid ipV4', () {
      expect(
        () => ConnectionEntry(validIpv4, ConnectionEntryType.ip),
        returnsNormally,
      );
    });

    test('throws an exception when ip is invalid ipV6', () {
      expect(
        () => ConnectionEntry(invalidIpv6, ConnectionEntryType.ip),
        throwsException,
      );
    });

    test('does not throw an exception when ip is valid ipV6', () {
      expect(
        () => ConnectionEntry(validIpv6, ConnectionEntryType.ip),
        returnsNormally,
      );
    });
  });

  group('Check ConnectionEntry for url', () {
    test('throws an exception when url is invalid', () {
      expect(
        () => ConnectionEntry(invalidUrl, ConnectionEntryType.url),
        throwsException,
      );
    });

    test('does not throw an error when url is valid', () {
      expect(
        () => ConnectionEntry(validUrl, ConnectionEntryType.url),
        returnsNormally,
      );
    });
  });
}
