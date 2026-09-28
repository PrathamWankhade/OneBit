import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccentColor {
  cyan(Color(0xFF00D4AA), 'Cyan'),
  green(Color(0xFF4CAF50), 'Green'),
  blue(Color(0xFF2196F3), 'Blue'),
  purple(Color(0xFF9C27B0), 'Purple'),
  red(Color(0xFFF44336), 'Red'),
  amber(Color(0xFFFFC107), 'Amber');

  const AccentColor(this.color, this.label);
  final Color color;
  final String label;
}

enum FontSize { small, medium, large }

class SettingsRepository {
  const SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  // ── Appearance ──

  int get themeModeIndex => _prefs.getInt(_kThemeMode) ?? 0;
  int get accentColorIndex => _prefs.getInt(_kAccentColor) ?? 0;
  int get fontSizeIndex => _prefs.getInt(_kFontSize) ?? 1;
  bool get showTimestamps => _prefs.getBool(_kShowTimestamps) ?? true;
  bool get compactMode => _prefs.getBool(_kCompactMode) ?? false;
  bool get reducedMotion => _prefs.getBool(_kReducedMotion) ?? false;

  // ── Notifications ──

  bool get notificationsEnabled =>
      _prefs.getBool(_kNotificationsEnabled) ?? true;
  bool get notificationSound => _prefs.getBool(_kNotificationSound) ?? true;
  bool get notificationVibration =>
      _prefs.getBool(_kNotificationVibration) ?? true;

  // ── Mesh ──

  bool get discoveryEnabled => _prefs.getBool(_kDiscoveryEnabled) ?? true;
  bool get relayEnabled => _prefs.getBool(_kRelayEnabled) ?? true;

  // ── App update ──

  /// Whether OneBit looks for new builds on its own and tells the user
  /// when one is available.
  bool get autoUpdateEnabled => _prefs.getBool(_kAutoUpdateEnabled) ?? true;

  /// The newest upstream build known to be newer than this one, or `null`
  /// when nothing is outstanding.
  ///
  /// Persisted rather than held in memory so a restart inside the
  /// rate-limit window still shows the tile as offering an update, instead
  /// of going quiet until the next check falls due.
  String? get pendingUpdateVersion =>
      _prefs.getString(_kPendingUpdateVersion);

  /// Where [pendingUpdateVersion] can be picked up.
  String? get pendingUpdateUrl => _prefs.getString(_kPendingUpdateUrl);

  /// Milliseconds since epoch of the last automatic check that reached the
  /// network, or `0` when there has never been one.
  int get lastUpdateCheckAt =>
      _prefs.getInt(_kLastUpdateCheckAt) ?? 0;

  // ── Setters ──

  Future<bool> setThemeMode(int index) => _prefs.setInt(_kThemeMode, index);
  Future<bool> setAccentColor(int index) =>
      _prefs.setInt(_kAccentColor, index);
  Future<bool> setFontSize(int index) => _prefs.setInt(_kFontSize, index);
  Future<bool> setShowTimestamps(bool value) =>
      _prefs.setBool(_kShowTimestamps, value);
  Future<bool> setCompactMode(bool value) =>
      _prefs.setBool(_kCompactMode, value);
  Future<bool> setReducedMotion(bool value) =>
      _prefs.setBool(_kReducedMotion, value);
  Future<bool> setNotificationsEnabled(bool value) =>
      _prefs.setBool(_kNotificationsEnabled, value);
  Future<bool> setNotificationSound(bool value) =>
      _prefs.setBool(_kNotificationSound, value);
  Future<bool> setNotificationVibration(bool value) =>
      _prefs.setBool(_kNotificationVibration, value);
  Future<bool> setDiscoveryEnabled(bool value) =>
      _prefs.setBool(_kDiscoveryEnabled, value);
  Future<bool> setRelayEnabled(bool value) =>
      _prefs.setBool(_kRelayEnabled, value);
  Future<bool> setAutoUpdateEnabled(bool value) =>
      _prefs.setBool(_kAutoUpdateEnabled, value);

  /// Records what an automatic check found.
  ///
  /// Both fields move together: a version with no URL (or the reverse)
  /// would show a badge that leads nowhere.
  Future<bool> setPendingUpdate({
    required String? version,
    required String? url,
  }) async {
    final savedVersion = await _setOrClear(_kPendingUpdateVersion, version);
    final savedUrl = await _setOrClear(_kPendingUpdateUrl, url);
    return savedVersion && savedUrl;
  }

  /// Records that a check reached the network, so the next one is not
  /// due for another six hours.
  Future<bool> setLastUpdateCheckAt(int millisecondsSinceEpoch) =>
      _prefs.setInt(_kLastUpdateCheckAt, millisecondsSinceEpoch);

  Future<bool> _setOrClear(String key, String? value) =>
      value == null || value.isEmpty
          ? _prefs.remove(key)
          : _prefs.setString(key, value);

  // ── Per-peer settings ──

  bool peerDisappearingMessages(String peerId) =>
      _prefs.getBool('peer_${peerId}_disappearing') ?? false;
  bool peerChatLock(String peerId) =>
      _prefs.getBool('peer_${peerId}_chatlock') ?? false;
  bool peerAdvancedPrivacy(String peerId) =>
      _prefs.getBool('peer_${peerId}_advanced_privacy') ?? false;

  Future<bool> setPeerDisappearingMessages(String peerId, bool value) =>
      _prefs.setBool('peer_${peerId}_disappearing', value);
  Future<bool> setPeerChatLock(String peerId, bool value) =>
      _prefs.setBool('peer_${peerId}_chatlock', value);
  Future<bool> setPeerAdvancedPrivacy(String peerId, bool value) =>
      _prefs.setBool('peer_${peerId}_advanced_privacy', value);
}

const _kThemeMode = 'settings_theme_mode';
const _kAccentColor = 'settings_accent_color';
const _kFontSize = 'settings_font_size';
const _kShowTimestamps = 'settings_show_timestamps';
const _kCompactMode = 'settings_compact_mode';
const _kReducedMotion = 'settings_reduced_motion';
const _kNotificationsEnabled = 'settings_notifications_enabled';
const _kNotificationSound = 'settings_notification_sound';
const _kNotificationVibration = 'settings_notification_vibration';
const _kDiscoveryEnabled = 'settings_discovery_enabled';
const _kRelayEnabled = 'settings_relay_enabled';
const _kAutoUpdateEnabled = 'settings_auto_update_enabled';
const _kPendingUpdateVersion = 'settings_pending_update_version';
const _kPendingUpdateUrl = 'settings_pending_update_url';
const _kLastUpdateCheckAt = 'settings_last_update_check_at';
