import 'package:connecteo/src/connection_type.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionTypeMapper {
  ConnectionType call(ConnectivityResult connectivityResult) {
    switch (connectivityResult) {
      case ConnectivityResult.bluetooth:
        return ConnectionType.bluetooth;
      case ConnectivityResult.ethernet:
        return ConnectionType.ethernet;
      case ConnectivityResult.mobile:
        return ConnectionType.mobile;
      case ConnectivityResult.vpn:
        return ConnectionType.vpn;
      case ConnectivityResult.wifi:
        return ConnectionType.wifi;
      case ConnectivityResult.none:
        return ConnectionType.none;
      default:
        return ConnectionType.unknown;
    }
  }
}
