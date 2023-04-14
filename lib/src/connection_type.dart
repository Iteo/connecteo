/// A representation of data connection type with simple `onlineType`
/// information which help us to asses how we should treat the connection type.
enum ConnectionType {
  bluetooth(true),
  wifi(true),
  ethernet(true),
  mobile(true),
  vpn(true),
  other(true),
  none(false);

  // ignore: avoid_positional_boolean_parameters
  const ConnectionType(this.onlineType);

  final bool onlineType;
}
