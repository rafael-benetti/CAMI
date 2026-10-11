# Vendored Media Kit Android video libraries

This is a local copy of `media_kit_libs_android_video` 1.3.8. Its four Android
ABI JARs are stored under `android/libs/`, rather than downloaded by Gradle.

They originate from Media Kit release `libmpv-android-video-build` `v1.1.7`.
Their MD5 digests, verified before vendoring, are:

- `default-arm64-v8a.jar`: `83df25b61193af8fa815e373143ac9af`
- `default-armeabi-v7a.jar`: `22e21526fefc0a2b8f17adbec9f57590`
- `default-x86_64.jar`: `6fa26bf0459b11f1c0b0dbc29e5b940d`
- `default-x86.jar`: `0d742b756dc9d1fcd84ea271d8b68f32`

Do not replace these binaries without updating the package version, provenance,
and checksums in this file.
