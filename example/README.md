# precise_metronome example

Minimal reference UI demonstrating the public API.

## First-time setup

The `ios/` and `android/` Flutter project scaffolding is not checked in
here. To generate it and run the example:

```sh
cd example
flutter create --org com.example --project-name precise_metronome_example .
flutter pub get
```

That command adds the standard `ios/` and `android/` folders without
overwriting `lib/main.dart` or `pubspec.yaml`.

### iOS post-create steps

Open `ios/Runner/Info.plist` and add background audio mode if you want
to test background playback:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

Also set the minimum iOS version to 15 in `ios/Podfile`:

```ruby
platform :ios, '15.0'
```

### Android post-create steps

Open `android/app/build.gradle` and:

1. Set `minSdkVersion` to **28**:
   ```groovy
   defaultConfig {
       minSdkVersion 28
       targetSdkVersion 34
   }
   ```
2. Set the Kotlin JVM target to 17:
   ```groovy
   kotlinOptions {
       jvmTarget = '17'
   }
   ```
3. Enable Java 17:
   ```groovy
   compileOptions {
       sourceCompatibility JavaVersion.VERSION_17
       targetCompatibility JavaVersion.VERSION_17
   }
   ```

The foreground-service permissions and component are contributed by the
plugin's own manifest via manifest merging — you don't need to add them
to the example app manually.

## Running

```sh
flutter run
```

Requires a real device for best results — audio latency on the Android
emulator is typically much worse than hardware.
