# Audiobook Flutter MVP

This is a small Audiobook app demo (Material 3, Riverpod, just_audio) wired to an S3-hosted catalog.

Run notes

- Update dependencies in `pubspec.yaml` (see dependencies snippet in task). Then run `flutter pub get`.
- To change the S3 base URL, edit `lib/providers/catalog_providers.dart` and modify `baseUrlProvider`.
- Background playback is configured via `just_audio_background` init in `lib/main.dart`.

Android/iOS manifest changes are required (see task). After adding dependencies, build and run on device/emulator.
# audiobook

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
