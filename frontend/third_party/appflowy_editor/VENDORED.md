# Vendored: appflowy_editor 6.2.0 (patched)

Copy of [appflowy_editor 6.2.0](https://pub.dev/packages/appflowy_editor)
(`lib/`, `assets/`, `pubspec.yaml`, `LICENSE` only — docs/example/test
stripped), wired in through `dependency_overrides` in `frontend/pubspec.yaml`.

## Why

The published 6.2.0 does not compile against this project's Flutter SDK
(3.44): `DeltaTextInputService` misses the `TextInputClient.onFocusReceived`
member introduced by the newer SDK. No published release or upstream commit
fixes it as of 2026-06-12 (feature 003, research R3 risk).

## Local patch (the only delta from upstream)

`lib/src/editor/editor_component/service/ime/delta_input_service.dart`:

```dart
@override
bool onFocusReceived() => false;
```

## Removal condition

Delete this directory and the `dependency_overrides` entry when an
appflowy_editor release compiles against the project's Flutter SDK.
