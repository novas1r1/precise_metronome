/// Configuration for the Android foreground-service notification that
/// keeps the metronome running when the app is backgrounded.
///
/// Android requires a visible foreground-service notification whenever an
/// app plays audio from the background — the user must always be able to
/// see and stop the service. iOS has no such requirement and ignores this.
class AndroidNotificationConfig {
  /// Title shown in the notification (e.g. "Metronome running").
  final String title;

  /// Optional body text beneath the title.
  final String? body;

  /// Notification-channel id. A channel with this id will be created on
  /// first use; on API 26+ the channel survives uninstall of your app.
  final String channelId;

  /// Human-readable channel name shown in system settings.
  final String channelName;

  /// Notification id used when posting. Any positive integer is fine, but
  /// keep it unique across your app.
  final int notificationId;

  const AndroidNotificationConfig({
    this.title = 'Metronome running',
    this.body,
    this.channelId = 'precise_metronome',
    this.channelName = 'Metronome',
    this.notificationId = 4201,
  });

  Map<String, Object?> toMap() => {
        'title': title,
        'body': body,
        'channelId': channelId,
        'channelName': channelName,
        'notificationId': notificationId,
      };
}
