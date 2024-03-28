# connecteo

A plugin that wraps [connectivity_plus](https://pub.dev/packages/connectivity_plus) and adds some checks that guarantee connection to the internet.

## Contents

- [Motivation](#motivation)
- [Setup](#setup)
- [How it works](#how-it-works)
- [Usage](#usage)
    - [ConnectionChecker init](#connectionchecker-init)
    - [connectionStream](#get-connectionstream)
    - [isConnected](#get-isconnected)
    - [connectionType](#get-connectiontype)
    - [untilConnects](#untilconnects)

## Motivation

[connectivity_plus](https://pub.dev/packages/connectivity_plus) is a great package for checking internet status but comes with a single flaw - it checks only the connection type, not the internet connection data. It means that it can not guarantee you connection data, for example, when being under a Wifi access which does not have the internet connection. In such a scenario, the network requests will fail when theoretically they shouldn't due to being online.

A purpose of the plugin was to add some extra checks, on top on existing [connectivity_plus's API](https://pub.dev/documentation/connectivity_plus/latest/connectivity_plus/connectivity_plus-library.html), that make sure our connection to the internet is reliable when we are online.

## Setup

You can install the package from your project's terminal:

```shell
flutter pub add connecteo
```

or add the dependency manually inside your `pubspec.yaml`:

```yaml
dependencies:
  connecteo: # desired version
```

Then you can use connecteo's `ConnectionChecker` class wherever you want:

```dart
import 'package:connecteo/connecteo.dart';

final connecteo = ConnectionChecker();
// Sample checking the internet connection
final hasInternetConnection = await connecteo.isConnected;
```

## How it works

The statement about a reliable internet connection is true when all these conditions are met:

- A new (or previous) connection type is the online one - it is kind of self-explanatory. The connection type cannot be `.none`. Every other type is classified as online.
- (On native platforms) A socket connection has to be opened and successfully established against at least one address - `ConnectionChecker` defines a default list of IP addresses that are globally available DNS resolvers. When at least one socket connection succeeds with its address, the information about the successful connection is returned, signaling the data connection. On the other hand, when all the socket connection trials fail, the `ConnectionChecker` informs about a lack of internet connection.
- (on the Web platform) - situation here is similar to the native platform, but instead of the socket connection, the http call is being made. If we receive a response with 200 status code from one URL at least, the information about a successful connection is returned.
- (optional) a response from the provided Base Url address has to be successful - if host address for the Base Url was provided in `ConnectionChecker` constructor, the host lookup is being made against the Base Url. If the lookup process will finish successfully without any `SocketException` then the condition is being met. This check was dictated by cases where an internet connection got back from an offline state, but the requests to the Base Url were failing for the first few seconds. It was causing some confusion because, in the majority of cases, we expect successful requests once the connection gets back online.

## Usage

### ConnectionChecker init

There are a couple of parameters (with its default values) that the `ConnectionChecker`'s constructor takes - you can modify them to suit your needs:

- checkHostReachability - let's you specify if you want to open the socket connections on native platforms (or make an http call on a web platform) against the list of addresses. Its default value is set to `true`.
- checkConnectionEntriesNative - a list of custom `ConnectionEntry` which will be used to open the socket connections. The default list contains three ip addresses: *CloudFlare (1.1.1.1)*, *Google (8.8.4.4)* and *OpenDNS (208.67.222.222)*. This argument should be used only on native platforms.
- checkConnectionEntriesWeb - a list of custom `ConnectionEntry` which will be used to check the responses from urls. At least one of the provided urls here has to return a response with an http status 200. The default list contains the following addresses: *https://one.one.one.one/*, *https://jsonplaceholder.typicode.com/posts/1* and *http://worldtimeapi.org/api/timezone*. This argument should be used only on Web platforms.
- hostReachabilityTimeout - let's you specify the `Duration` which is being used for the timeout for each `ConnectionEntry` and its socket's opening. The default value is 3 seconds.
- baseUrlLookupAddress - a `String` URL which indicates the address you want to lookup during connection checks. Once you provide your URL, the `connectionStream` and `isConnected` will return true values only after a successful host lookup. Its default value is `null`.
- requestInterval - it is a `Duration` which is being used for the interval how often the internet connection status should be refreshed. By default, its value is set to 3 seconds.
- failureAttempts - the number of maximum trials between changing the online to offline state.When the lost connection won't go back after number of `failureAttempts`, the `connectionStream` and `isConnected` will return false values until the connection gets back. The default value is set to 4 attempts.

Example:

```dart
final connecteo = ConnectionChecker(
    checkHostReachability: true,
    checkConnectionEntriesNative: [
        ConnectionEntry.fromIpAddress(
            '1.0.0.1', // CloudFlare
        ),
        ConnectionEntry(
            '208.67.220.220', // OpenDNS
            ConnectionEntryType.ip,
        ),
    ],
    checkConnectionEntriesWeb: [
        ConnectionEntry.fromUrl(
            'https://one.one.one.one/', // CloudFlare
        ),
    ],
    hostReachabilityTimeout: Duration(seconds: 5),
    baseUrlLookupAddress: 'https://pub.dev/',
    failureAttempts: 7,
    requestInterval: Duration(seconds: 5),
);
```

### get connectionStream

Returns the reliable internet connection status with the help of `Stream<bool>`. It yields its value every time when connection type will change or desired interval (`ConnectionChecker`'s constructor argument) will pass.

Example:

```dart
final connecteo = ConnectionChecker();

final subscription = connecteo.connectionStream.listen((isConnected) {
    if (isConnected) {
        // Handle the logic when the app is online
    } else {
        // Handle the logic when the app is offline
    }
});
```

### get isConnected

Returns the actual, reliable internet connection status for the present moment. Similar to above, but its return type is `Future<bool>`.

Example:

```dart
final connecteo = ConnectionChecker();

final hasInternetConnection = await connecteo.isConnected;
if (hasInternetConnection) {
    // Handle the one-time check when the app is online
}
```

### get connectionType

Returns the current connection type.

Example:

```dart
final connecteo = ConnectionChecker();

final type = await connecteo.connectionType;
if (type == ConnectionType.mobile) {
    // Handle the logic when the application uses cellular data
}
```

### untilConnects()

A method which resolves as soon as internet connection status get back from offline state. Handy when you want to trigger some kind of action once, after internet data connection get back but you do not want to use the `connectionStream`.

Example:

```dart
final connecteo = ConnectionChecker();

connecteo.untilConnects().then((_) {
    // Handle the logic when the internet connection data get back
});
```

---

For more detailed information about the package possibilities, visit the [API documentation](https://pub.dev/documentation/connecteo/latest/connecteo/connecteo-library.html).

