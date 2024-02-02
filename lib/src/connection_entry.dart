import 'package:connecteo/src/connection_entry_type.dart';
import 'package:connecteo/src/regex_helper.dart';

/// A representation of connection entry, which type can be
/// either [ConnectionEntryType.ip] or [ConnectionEntryType.url].
///
/// Additionally, you can pass a port number which will be used during the socket
/// connection (only on the native platforms). If you don't pass such port number,
/// the default DNS port (53) will be used.
class ConnectionEntry {
  ConnectionEntry(
    this.host,
    this.type, {
    this.port,
  }) {
    if (type == ConnectionEntryType.ip) {
      validateIpAddress(host);
    } else {
      validateUrl(host);
    }
  }

  /// Create a new [ConnectionEntry] from an IP address.
  factory ConnectionEntry.fromIpAddress(String host, {int? port}) {
    validateIpAddress(host);

    return ConnectionEntry(
      host,
      ConnectionEntryType.ip,
      port: port,
    );
  }

  /// Create a new [ConnectionEntry] from a URL.
  factory ConnectionEntry.fromUrl(String host, {int? port}) {
    validateUrl(host);

    return ConnectionEntry(
      host,
      ConnectionEntryType.url,
      port: port,
    );
  }

  final String host;
  final ConnectionEntryType type;
  final int? port;

  @override
  String toString() {
    final portNumber = port != null ? ':$port' : '';

    return '$host$portNumber - $type';
  }
}
