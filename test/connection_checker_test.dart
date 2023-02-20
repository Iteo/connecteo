// ignore_for_file: unawaited_futures

import 'dart:async';

import 'package:connecteo/connecteo.dart';
import 'package:connecteo/src/connection_type_mapper.dart';
import 'package:connecteo/src/host_reachability_checker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockConnectivity extends Mock implements Connectivity {}

class MockHostReachabilityChecker extends Mock
    implements HostReachabilityChecker {}

class MockConnectionTypeMapper extends Mock implements ConnectionTypeMapper {}

void main() {
  const baseUrl = 'baseUrl';
  const requestInterval = Duration(seconds: 3);
  const failureAttempts = 4;

  late Connectivity connectivity;
  late HostReachabilityChecker hostReachabilityChecker;
  late ConnectionTypeMapper connectionTypeMapper;
  late ConnectionChecker connectionChecker;

  setUp(() {
    registerFallbackValue(ConnectivityResult.wifi);

    connectivity = MockConnectivity();
    hostReachabilityChecker = MockHostReachabilityChecker();
    connectionTypeMapper = MockConnectionTypeMapper();
    connectionChecker = ConnectionChecker.test(
      connectivity: connectivity,
      hostReachabilityChecker: hostReachabilityChecker,
      connectionTypeMapper: connectionTypeMapper,
      baseUrlLookupAddress: baseUrl,
      requestInterval: requestInterval,
      failureAttempts: failureAttempts,
    );
  });

  group('init', () {
    test('should return always the same ConnectionChecker instance (singleton)',
        () {
      final instance1 = ConnectionChecker();
      final instance2 = ConnectionChecker();

      expect(instance1 == instance2, true);
      expect(instance1.hashCode == instance2.hashCode, true);
    });
  });

  group('isConnected', () {
    test(
        'returns false if hosts are not reachable although connection type is online',
        () async {
      when(() => hostReachabilityChecker.canReachAnyHost())
          .thenAnswer((_) => Future.value(false));
      when(
        () => hostReachabilityChecker.hostLookup(
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) => Future.value(true));
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) => Future.value(ConnectivityResult.wifi));
      when(() => connectionTypeMapper.call(any()))
          .thenAnswer((_) => ConnectionType.wifi);

      final result = await connectionChecker.isConnected;

      expect(result, false);
      verify(() => hostReachabilityChecker.canReachAnyHost()).called(1);
      verify(() => hostReachabilityChecker.hostLookup(baseUrl: baseUrl))
          .called(1);
    });

    test(
        'returns true if hosts with base url are reachable and connection type is online',
        () async {
      when(() => hostReachabilityChecker.canReachAnyHost())
          .thenAnswer((_) => Future.value(true));
      when(
        () => hostReachabilityChecker.hostLookup(
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) => Future.value(true));
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) => Future.value(ConnectivityResult.wifi));
      when(() => connectionTypeMapper.call(any()))
          .thenAnswer((_) => ConnectionType.wifi);

      final result = await connectionChecker.isConnected;

      expect(result, true);
      verify(() => hostReachabilityChecker.canReachAnyHost()).called(1);
      verify(() => hostReachabilityChecker.hostLookup(baseUrl: baseUrl))
          .called(1);
    });

    test(
        'returns false if hosts with base url are reachable but connection type is offline',
        () async {
      when(() => hostReachabilityChecker.canReachAnyHost())
          .thenAnswer((_) => Future.value(true));
      when(
        () => hostReachabilityChecker.hostLookup(
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) => Future.value(true));
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) => Future.value(ConnectivityResult.none));
      when(() => connectionTypeMapper.call(any()))
          .thenAnswer((_) => ConnectionType.none);

      final result = await connectionChecker.isConnected;

      expect(result, false);
      verify(() => hostReachabilityChecker.canReachAnyHost()).called(1);
      verify(() => hostReachabilityChecker.hostLookup(baseUrl: baseUrl))
          .called(1);
    });
  });

  group('isConnected', () {
    test(
        'returns true if connection type is online, hosts are reachable but baseUrl is not provided',
        () async {
      connectionChecker = ConnectionChecker.test(
        connectivity: connectivity,
        hostReachabilityChecker: hostReachabilityChecker,
        connectionTypeMapper: connectionTypeMapper,
      );
      when(() => hostReachabilityChecker.canReachAnyHost())
          .thenAnswer((_) => Future.value(true));
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) => Future.value(ConnectivityResult.wifi));
      when(() => connectionTypeMapper.call(any()))
          .thenAnswer((_) => ConnectionType.wifi);

      final result = await connectionChecker.isConnected;

      expect(result, true);
      verify(() => hostReachabilityChecker.canReachAnyHost()).called(1);
      verifyNever(
        () =>
            hostReachabilityChecker.hostLookup(baseUrl: any(named: 'baseUrl')),
      );
    });
  });

  group('connectionType', () {
    test('returns current connectionType', () async {
      const expected = ConnectionType.wifi;

      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) => Future.value(ConnectivityResult.wifi));
      when(() => connectionTypeMapper.call(any())).thenAnswer((_) => expected);

      final result = await connectionChecker.connectionType;

      expect(result, expected);
      verify(() => connectivity.checkConnectivity()).called(1);
      verify(() => connectionTypeMapper.call(ConnectivityResult.wifi))
          .called(1);
    });
  });

  group('untilConnects', () {
    test('returns the Future once, after the connection is renewed', () async {
      final completer = Completer<bool>();
      final controller = StreamController<ConnectivityResult>();
      when(() => hostReachabilityChecker.canReachAnyHost())
          .thenAnswer((_) => Future.value(true));
      when(
        () => hostReachabilityChecker.hostLookup(
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) => Future.value(true));
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => controller.stream);
      when(() => connectionTypeMapper.call(ConnectivityResult.wifi))
          .thenAnswer((_) => ConnectionType.wifi);
      when(() => connectionTypeMapper.call(ConnectivityResult.none))
          .thenAnswer((_) => ConnectionType.none);

      connectionChecker.untilConnects().whenComplete(() {
        completer.complete(true);
      });
      controller.add(ConnectivityResult.none);
      await Future<void>.delayed(requestInterval);
      controller.add(ConnectivityResult.wifi);

      expect(completer.future, completion(true));

      controller.close();
    });
  });

  group('connectionStream', () {
    test(
        'returns [true] from Stream while hosts are reachable, base url is reachable and connection type is online',
        () async {
      final controller = StreamController<ConnectivityResult>();
      when(() => hostReachabilityChecker.canReachAnyHost())
          .thenAnswer((_) => Future.value(true));
      when(
        () => hostReachabilityChecker.hostLookup(
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) => Future.value(true));
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => controller.stream);
      when(() => connectionTypeMapper.call(any()))
          .thenAnswer((_) => ConnectionType.wifi);

      expectLater(
        connectionChecker.connectionStream,
        emitsInOrder([true]),
      ).then(
        (_) {
          verify(() => hostReachabilityChecker.canReachAnyHost()).called(1);
          verify(() => hostReachabilityChecker.hostLookup(baseUrl: baseUrl))
              .called(1);
        },
      );
      controller.add(ConnectivityResult.wifi);

      controller.close();
    });

    test(
        'returns [true, false] from Stream while hosts are reachable, base url is reachable but connection dropped',
        () async {
      final controller = StreamController<ConnectivityResult>();
      when(() => hostReachabilityChecker.canReachAnyHost())
          .thenAnswer((_) => Future.value(true));
      when(
        () => hostReachabilityChecker.hostLookup(
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) => Future.value(true));
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => controller.stream);
      when(() => connectionTypeMapper.call(ConnectivityResult.wifi))
          .thenAnswer((_) => ConnectionType.wifi);
      when(() => connectionTypeMapper.call(ConnectivityResult.none))
          .thenAnswer((_) => ConnectionType.none);

      expectLater(
        connectionChecker.connectionStream,
        emitsInOrder([true, false]),
      ).then((_) {
        verify(() => hostReachabilityChecker.canReachAnyHost())
            .called(1 + failureAttempts);
        verify(() => hostReachabilityChecker.hostLookup(baseUrl: baseUrl))
            .called(1);
      });
      controller.add(ConnectivityResult.wifi);
      await Future<void>.delayed(requestInterval);
      controller.add(ConnectivityResult.none);

      controller.close();
    });

    test(
        'returns [false] from Stream while hosts are not reachable although connection type is online',
        () async {
      final controller = StreamController<ConnectivityResult>.broadcast();
      when(() => hostReachabilityChecker.canReachAnyHost())
          .thenAnswer((_) => Future.value(false));
      when(
        () => hostReachabilityChecker.hostLookup(
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) => Future.value(false));
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => controller.stream);
      when(() => connectionTypeMapper.call(ConnectivityResult.wifi))
          .thenAnswer((_) => ConnectionType.wifi);

      expectLater(
        connectionChecker.connectionStream,
        emitsInOrder([false]),
      ).then(
        (_) {
          verify(() => hostReachabilityChecker.canReachAnyHost())
              .called(failureAttempts);
          verifyNever(
            () => hostReachabilityChecker.hostLookup(baseUrl: baseUrl),
          );
        },
      );
      controller.add(ConnectivityResult.wifi);

      controller.close();
    });
  });
}
