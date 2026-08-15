import 'package:flutter/material.dart';

/// Product iconography.
///
/// All icons used by the shell, components and features are declared here so
/// the visual language changes in one place. The set is Material outlined
/// icons (≈2px visual stroke) until custom vector assets land.
abstract final class OneBitIcons {
  // Shell destinations
  static const IconData shellHome = Icons.home_outlined;
  static const IconData shellHomeFilled = Icons.home_rounded;
  static const IconData shellMesh = Icons.account_tree_outlined;
  static const IconData shellMeshFilled = Icons.account_tree_rounded;
  static const IconData shellChannels = Icons.forum_outlined;
  static const IconData shellChannelsFilled = Icons.forum_rounded;
  static const IconData shellNodes = Icons.dns_outlined;
  static const IconData shellNodesFilled = Icons.dns_rounded;
  static const IconData shellNearby = Icons.near_me_outlined;
  static const IconData shellNearbyFilled = Icons.near_me_rounded;
  static const IconData shellSettings = Icons.settings_outlined;
  static const IconData shellSettingsFilled = Icons.settings_rounded;
  static const IconData shellDeveloper = Icons.terminal_outlined;
  static const IconData shellDeveloperFilled = Icons.terminal_rounded;
  static const IconData shellAbout = Icons.info_outline_rounded;
  static const IconData shellAboutFilled = Icons.info_rounded;

  // Settings vocabulary
  static const IconData palette = Icons.palette_outlined;
  static const IconData privacy = Icons.lock_outline_rounded;
  static const IconData storage = Icons.folder_outlined;
  static const IconData notifications = Icons.notifications_outlined;
  static const IconData bluetooth = Icons.bluetooth_rounded;
  static const IconData licenses = Icons.description_outlined;

  // Identity / QR vocabulary
  static const IconData qrIdentity = Icons.qr_code_rounded;
  static const IconData qrScanner = Icons.qr_code_scanner_rounded;

  // Mesh / node vocabulary
  static const IconData node = Icons.circle_outlined;
  static const IconData nodeActive = Icons.circle;
  static const IconData radar = Icons.radar_rounded;
  static const IconData signal = Icons.signal_cellular_alt_rounded;

  // Common actions
  static const IconData retry = Icons.refresh_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData security = Icons.lock_outline_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData copy = Icons.copy_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData info = Icons.info_outline_rounded;

  // Transfer / media vocabulary
  static const IconData upload = Icons.upload_rounded;
  static const IconData download = Icons.download_rounded;
  static const IconData attachFile = Icons.attach_file_rounded;

  // Inputs and selection
  static const IconData send = Icons.send_rounded;
  static const IconData filter = Icons.filter_alt_outlined;
  static const IconData moreVert = Icons.more_vert_rounded;
  static const IconData pin = Icons.push_pin_outlined;
  static const IconData mute = Icons.volume_off_outlined;
  static const IconData archive = Icons.archive_outlined;
  static const IconData unarchive = Icons.unarchive_outlined;
  static const IconData markRead = Icons.done_all_rounded;
  static const IconData chat = Icons.chat_outlined;
  static const IconData verified = Icons.verified_outlined;
  static const IconData block = Icons.block_rounded;

  // Connectivity / availability
  static const IconData cloudOff = Icons.cloud_off_rounded;
  static const IconData bluetoothDisabled = Icons.bluetooth_disabled_rounded;
  static const IconData schedule = Icons.schedule_rounded;

  // Message actions / composer vocabulary
  static const IconData reply = Icons.reply_rounded;
  static const IconData forward = Icons.forward_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData emoji = Icons.emoji_emotions_outlined;
  static const IconData mic = Icons.mic_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData selectAll = Icons.select_all_rounded;
  static const IconData stop = Icons.stop_rounded;

  // Media category vocabulary
  static const IconData image = Icons.image_outlined;
  static const IconData video = Icons.videocam_outlined;
  static const IconData audio = Icons.audiotrack_rounded;
  static const IconData voiceNote = Icons.mic_rounded;
  static const IconData document = Icons.description_outlined;
  static const IconData archiveFile = Icons.folder_zip_outlined;
  static const IconData binaryFile = Icons.insert_drive_file_outlined;
  static const IconData file = Icons.insert_drive_file_outlined;

  // Identity vocabulary
  static const IconData fingerprint = Icons.fingerprint_rounded;
  static const IconData camera = Icons.camera_alt_outlined;

  const OneBitIcons._();
}
