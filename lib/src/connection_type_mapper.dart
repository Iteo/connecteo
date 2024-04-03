import 'package:connecteo/src/connection_type.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

abstract class Mapper<I, O> {
  O call(I input);
}

class ConnectionTypeMapper
    implements Mapper<List<ConnectivityResult>, List<ConnectionType>> {
  @override
  List<ConnectionType> call(List<ConnectivityResult> input) {
    return input.map(_map).toList();
  }

  ConnectionType _map(ConnectivityResult connectivityResult) {
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
      case ConnectivityResult.other:
        return ConnectionType.other;
      case ConnectivityResult.none:
        return ConnectionType.none;
    }
  }
}

extension ListConnectionTypeExt on List<ConnectionType> {
  bool get containsOnline => isNotEmpty && any((value) => value.onlineType);
}
