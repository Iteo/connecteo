## 2.1.2
- Fix missing export `ConnectionEntry` class.

## 2.1.1

- Update package version

## 2.1.0

- Update Flutter version to 3.10.0
- Update Dart SDK constraints to `>=3.0.0 <4.0.0`
- Update http package to 1.1.0

## 2.0.0

- Add support for Web platform
- Breaking changes: Now the package is using `ConnectionEntry` instead of `InternetAddress` to determine the connection params. This is because `InternetAddress` is not supported on Web.
- Update Dart SDK constraints to `>=2.19.0 <4.0.0`

## 1.1.1

- Fix the problem where `connectionStream` wasn't emitting the initial event when being offline from the startup. Problem was faced on the Android platform.

## 1.1.0

- Update dependencies along with Flutter and Dart SDK constraints.

## 1.0.2

- Replace `ConnectionType.unknown` with `ConnectionType.other` which is marked as `true` when it comes to the Online Type.

## 1.0.1

- Update documentation links.

## 1.0.0

- Initial version.
