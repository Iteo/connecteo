import 'package:connecteo/src/connection_entry_type.dart';
import 'package:connecteo/src/regex_helper.dart';

/// A representation of connection entry, which type can be either `ip` or `apiUrl`.
class ConnectionEntry {
  ConnectionEntry(
    this.host,
    this.type,
  ) {
    if (type == ConnectionEntryType.ip) {
      validateIpAddress(host);
    } else {
      validateApiUrl(host);
    }
  }

  final String host;
  final ConnectionEntryType type;

  @override
  String toString() {
    return '$host - $type';
  }
}
