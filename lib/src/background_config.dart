/// Configuration for the Android foreground-service notification that
/// keeps the metronome running when the app is backgrounded.
///
/// Android requires a visible foreground-service notification whenever an
/// app plays audio from the background — the user must always be able to
/// see and stop the service. iOS has no such requirement and ignores this.
///
/// The notification is media-style: two lines of text, a play/pause toggle
/// and a stop button, mirrored on the lock screen. Pass the same object to
/// [Metronome.enableBackgroundPlayback] to show it and to
/// [Metronome.updateBackgroundNotification] whenever the text or [playing]
/// changes. Button presses arrive on [Metronome.notificationActions]; the
/// notification itself changes nothing until you update it.
class AndroidNotificationConfig {
  /// Title shown in the notification (e.g. "120 BPM · 4/4").
  final String title;

  /// Optional body text beneath the title (e.g. "Playing", "Silent").
  final String? body;

  /// Whether the toggle shows Pause (`true`) or Play (`false`). Also sets
  /// the media session's playback state, which the lock screen shows.
  final bool playing;

  /// Name of a drawable (or mipmap) in your app to use as the small status
  /// bar icon, e.g. `'ic_notification'`. Must be monochrome — Android
  /// paints it in one colour. `null` uses the plugin's metronome icon.
  final String? smallIcon;

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
    this.playing = true,
    this.smallIcon,
    this.channelId = 'precise_metronome',
    this.channelName = 'Metronome',
    this.notificationId = 4201,
  });

  AndroidNotificationConfig copyWith({
    String? title,
    String? body,
    bool? playing,
    String? smallIcon,
  }) => AndroidNotificationConfig(
    title: title ?? this.title,
    body: body ?? this.body,
    playing: playing ?? this.playing,
    smallIcon: smallIcon ?? this.smallIcon,
    channelId: channelId,
    channelName: channelName,
    notificationId: notificationId,
  );

  Map<String, Object?> toMap() => {
    'title': title,
    'body': body,
    'playing': playing,
    'smallIcon': smallIcon,
    'channelId': channelId,
    'channelName': channelName,
    'notificationId': notificationId,
  };

  @override
  bool operator ==(Object other) =>
      other is AndroidNotificationConfig &&
      other.title == title &&
      other.body == body &&
      other.playing == playing &&
      other.smallIcon == smallIcon &&
      other.channelId == channelId &&
      other.channelName == channelName &&
      other.notificationId == notificationId;

  @override
  int get hashCode => Object.hash(
    title,
    body,
    playing,
    smallIcon,
    channelId,
    channelName,
    notificationId,
  );
}

/// A button pressed on the Android background notification, on the lock
/// screen, or on a headset.
///
/// Nothing happens on its own: act on it (start or stop the metronome) and
/// then call [Metronome.updateBackgroundNotification] or
/// [Metronome.disableBackgroundPlayback] to match.
enum NotificationAction {
  /// The play button: the user wants the click back.
  play,

  /// The pause button: stop the click, but keep the notification so it can
  /// be resumed from there.
  pause,

  /// The stop button, or the notification swiped away: stop the click and
  /// release the service.
  stop,
}
