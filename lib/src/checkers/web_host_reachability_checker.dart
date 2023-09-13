import 'package:connecteo/connecteo.dart';
import 'package:connecteo/src/connection_entry.dart';
import 'package:connecteo/src/host_reachability_checker.dart';
import 'package:http/http.dart' as http;

final _defaultUrls = List<ConnectionEntry>.unmodifiable([
  ConnectionEntry(
    'https://one.one.one.one',
    ConnectionEntryType.apiUrl,
  ),
  ConnectionEntry(
    'https://jsonplaceholder.typicode.com/posts/1',
    ConnectionEntryType.apiUrl,
  ),
  ConnectionEntry(
    'http://worldtimeapi.org/api/timezone',
    ConnectionEntryType.apiUrl,
  ),
]);

/// Create a [WebHostReachabilityChecker].
///
/// Used from conditional imports, matches the definition in `host_reachability_checker_stub.dart`.
HostReachabilityChecker createChecker() => WebHostReachabilityChecker();

class WebHostReachabilityChecker implements HostReachabilityChecker {

  @override
  Future<bool> hostLookup({required String baseUrl}) async {
    try {
      final uri = Uri.parse(baseUrl);
      final result = await http.head(uri);
      if (result.statusCode == 200) return true;
      return false;
    } on http.ClientException catch (_) {
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
      final uri = Uri.parse(address.host);
      final result = await http.get(uri);
      if (result.statusCode == 200) return true;
      return false;
    } catch (_) {
      return false;
    }
  }
}
