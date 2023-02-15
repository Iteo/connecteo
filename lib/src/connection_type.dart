enum ConnectionType {
  bluetooth(true),
  wifi(true),
  ethernet(true),
  mobile(true),
  vpn(true),
  none(false),
  unknown(false);

  final bool onlineType;

  const ConnectionType(this.onlineType);
}
