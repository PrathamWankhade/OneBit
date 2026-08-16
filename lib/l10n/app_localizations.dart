import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OneBit'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Mesh communication without the internet'**
  String get appTagline;

  /// No description provided for @appShellHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get appShellHome;

  /// No description provided for @appShellMesh.
  ///
  /// In en, this message translates to:
  /// **'Mesh'**
  String get appShellMesh;

  /// No description provided for @appShellChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get appShellChannels;

  /// No description provided for @appShellNodes.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get appShellNodes;

  /// No description provided for @appShellNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get appShellNearby;

  /// No description provided for @appShellSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get appShellSettings;

  /// No description provided for @appShellDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get appShellDeveloper;

  /// No description provided for @appShellAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get appShellAbout;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Mesh communication without the internet'**
  String get splashTagline;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your node'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your identity to join the mesh. No internet, no account.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get onboardingDisplayNameLabel;

  /// No description provided for @onboardingDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'How other nodes see you'**
  String get onboardingDisplayNameHint;

  /// No description provided for @onboardingCreateIdentity.
  ///
  /// In en, this message translates to:
  /// **'Create identity'**
  String get onboardingCreateIdentity;

  /// No description provided for @onboardingError.
  ///
  /// In en, this message translates to:
  /// **'Could not create your identity. Please try again.'**
  String get onboardingError;

  /// No description provided for @routeComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This feature is not yet available.'**
  String get routeComingSoon;

  /// No description provided for @routeDeepLinkParameters.
  ///
  /// In en, this message translates to:
  /// **'Deep-link parameters'**
  String get routeDeepLinkParameters;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonUnknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get commonUnknownError;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get commonGoBack;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get commonEmpty;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Unexpected failure'**
  String get errorUnexpected;

  /// No description provided for @errorStorage.
  ///
  /// In en, this message translates to:
  /// **'Local storage failure'**
  String get errorStorage;

  /// No description provided for @errorPlatform.
  ///
  /// In en, this message translates to:
  /// **'Device platform failure'**
  String get errorPlatform;

  /// No description provided for @errorConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Invalid configuration'**
  String get errorConfiguration;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'OneBit'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Offline-first mesh node'**
  String get homeSubtitle;

  /// No description provided for @homeFlavor.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get homeFlavor;

  /// No description provided for @homeEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get homeEnvironment;

  /// No description provided for @homeVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get homeVersion;

  /// No description provided for @homeNodeStatus.
  ///
  /// In en, this message translates to:
  /// **'Node status'**
  String get homeNodeStatus;

  /// No description provided for @homeNodeIdle.
  ///
  /// In en, this message translates to:
  /// **'Node initialized'**
  String get homeNodeIdle;

  /// No description provided for @homeNodesNearby.
  ///
  /// In en, this message translates to:
  /// **'Nodes nearby'**
  String get homeNodesNearby;

  /// No description provided for @homeNoneNearby.
  ///
  /// In en, this message translates to:
  /// **'No nodes in range'**
  String get homeNoneNearby;

  /// No description provided for @homeNoData.
  ///
  /// In en, this message translates to:
  /// **'Your node has no data yet'**
  String get homeNoData;

  /// No description provided for @developerLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'System logs'**
  String get developerLogsTitle;

  /// No description provided for @developerLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log records'**
  String get developerLogsEmpty;

  /// No description provided for @developerCapabilitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform capabilities'**
  String get developerCapabilitiesTitle;

  /// No description provided for @developerCapabilityNativeCore.
  ///
  /// In en, this message translates to:
  /// **'Native core (C++)'**
  String get developerCapabilityNativeCore;

  /// No description provided for @developerCapabilityChannelBridge.
  ///
  /// In en, this message translates to:
  /// **'Platform channel bridge'**
  String get developerCapabilityChannelBridge;

  /// No description provided for @developerCapabilityAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get developerCapabilityAvailable;

  /// No description provided for @developerCapabilityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get developerCapabilityUnavailable;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About OneBit'**
  String get aboutTitle;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'OneBit is a fully decentralized, offline-first Bluetooth Low Energy mesh communication platform. Every device is a node, router, relay, cache and secure endpoint.'**
  String get aboutDescription;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'No internet. No cloud. No servers. No phone numbers. No accounts.'**
  String get aboutPrivacy;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get settingsThemeTerminal;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get settingsBluetooth;

  /// No description provided for @settingsDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get settingsDeveloper;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// No description provided for @settingsSectionTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get settingsSectionTools;

  /// No description provided for @channelDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel details'**
  String get channelDetailsTitle;

  /// No description provided for @channelIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Channel ID'**
  String get channelIdLabel;

  /// No description provided for @composeMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get composeMessageTitle;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @nodeDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Node details'**
  String get nodeDetailsTitle;

  /// No description provided for @nodeIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Node ID'**
  String get nodeIdLabel;

  /// No description provided for @qrIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity QR'**
  String get qrIdentityTitle;

  /// No description provided for @qrScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get qrScannerTitle;

  /// No description provided for @routeInspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Route inspector'**
  String get routeInspectorTitle;

  /// No description provided for @transferProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer progress'**
  String get transferProgressTitle;

  /// No description provided for @sessionIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Session ID'**
  String get sessionIdLabel;

  /// No description provided for @messageIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Message ID'**
  String get messageIdLabel;

  /// No description provided for @mediaGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Media gallery'**
  String get mediaGalleryTitle;

  /// No description provided for @galleryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get galleryFilterAll;

  /// No description provided for @galleryFilterImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get galleryFilterImages;

  /// No description provided for @galleryFilterVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get galleryFilterVideos;

  /// No description provided for @galleryFilterAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get galleryFilterAudio;

  /// No description provided for @galleryFilterVoiceNotes.
  ///
  /// In en, this message translates to:
  /// **'Voice notes'**
  String get galleryFilterVoiceNotes;

  /// No description provided for @galleryFilterDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get galleryFilterDocuments;

  /// No description provided for @galleryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No media yet'**
  String get galleryEmptyTitle;

  /// No description provided for @galleryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Photos, videos, audio and documents shared with you will appear here.'**
  String get galleryEmptyMessage;

  /// No description provided for @galleryUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the gallery'**
  String get galleryUnavailableTitle;

  /// No description provided for @galleryUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The media catalog could not be read. Try again in a moment.'**
  String get galleryUnavailableMessage;

  /// No description provided for @developerTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developerTitle;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutLicenses;

  /// No description provided for @licensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licensesTitle;

  /// No description provided for @developerModeEnabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Developer mode enabled'**
  String get developerModeEnabledMessage;

  /// No description provided for @meshTitle.
  ///
  /// In en, this message translates to:
  /// **'Mesh'**
  String get meshTitle;

  /// No description provided for @meshEmpty.
  ///
  /// In en, this message translates to:
  /// **'Mesh graph will appear here'**
  String get meshEmpty;

  /// No description provided for @identityOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get identityOverviewTitle;

  /// No description provided for @identityOverviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your identity profile will appear here'**
  String get identityOverviewEmpty;

  /// No description provided for @qrHubTitle.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrHubTitle;

  /// No description provided for @qrHubEmpty.
  ///
  /// In en, this message translates to:
  /// **'QR code features will appear here'**
  String get qrHubEmpty;

  /// No description provided for @nodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get nodesTitle;

  /// No description provided for @nodesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No nodes yet'**
  String get nodesEmpty;

  /// No description provided for @nodesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Trusted nodes and nearby nodes appear here.'**
  String get nodesEmptyMessage;

  /// No description provided for @channelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channelsTitle;

  /// No description provided for @channelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get channelsEmpty;

  /// No description provided for @channelsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Search for a node to start a conversation.'**
  String get channelsEmptyMessage;

  /// No description provided for @nearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearbyTitle;

  /// No description provided for @nearbyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No devices nearby yet'**
  String get nearbyEmpty;

  /// No description provided for @nearbyEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep this screen open while nearby nodes announce themselves.'**
  String get nearbyEmptyMessage;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String timeMinutesAgo(Object minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} h ago'**
  String timeHoursAgo(Object hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} d ago'**
  String timeDaysAgo(Object days);

  /// No description provided for @timeDateLabel.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String timeDateLabel(Object date);

  /// No description provided for @channelsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get channelsSearch;

  /// No description provided for @channelsArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get channelsArchive;

  /// No description provided for @channelsUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get channelsUnarchive;

  /// No description provided for @channelsPin.
  ///
  /// In en, this message translates to:
  /// **'Pin channel'**
  String get channelsPin;

  /// No description provided for @channelsUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin channel'**
  String get channelsUnpin;

  /// No description provided for @channelsMute.
  ///
  /// In en, this message translates to:
  /// **'Mute channel'**
  String get channelsMute;

  /// No description provided for @channelsUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute channel'**
  String get channelsUnmute;

  /// No description provided for @channelsMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get channelsMarkRead;

  /// No description provided for @channelsArchived.
  ///
  /// In en, this message translates to:
  /// **'Channel archived'**
  String get channelsArchived;

  /// No description provided for @channelsRestored.
  ///
  /// In en, this message translates to:
  /// **'Channel restored'**
  String get channelsRestored;

  /// No description provided for @channelsDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get channelsDraft;

  /// No description provided for @channelsOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get channelsOfflineTitle;

  /// No description provided for @channelsOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'The mesh radio is not running. Your conversations stay available on this device.'**
  String get channelsOfflineMessage;

  /// No description provided for @channelsShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived channels'**
  String get channelsShowArchived;

  /// No description provided for @channelsHideArchived.
  ///
  /// In en, this message translates to:
  /// **'Show active channels'**
  String get channelsHideArchived;

  /// No description provided for @channelsArchivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get channelsArchivedTitle;

  /// No description provided for @channelsArchivedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No archived channels'**
  String get channelsArchivedEmpty;

  /// No description provided for @channelsArchivedEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Channels you archive will appear here.'**
  String get channelsArchivedEmptyMessage;

  /// No description provided for @channelNotFound.
  ///
  /// In en, this message translates to:
  /// **'Channel not found'**
  String get channelNotFound;

  /// No description provided for @channelInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel info'**
  String get channelInfoTitle;

  /// No description provided for @channelPeerLabel.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get channelPeerLabel;

  /// No description provided for @channelCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get channelCreatedLabel;

  /// No description provided for @channelPinnedSection.
  ///
  /// In en, this message translates to:
  /// **'Pinned messages'**
  String get channelPinnedSection;

  /// No description provided for @channelNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get channelNoMessages;

  /// No description provided for @channelLoadOlder.
  ///
  /// In en, this message translates to:
  /// **'Load older messages'**
  String get channelLoadOlder;

  /// No description provided for @channelActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel actions'**
  String get channelActionsTitle;

  /// No description provided for @channelReadLabel.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get channelReadLabel;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get searchHint;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Search your messages'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Find any text in your conversations.'**
  String get searchEmptyMessage;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String searchNoResults(Object query);

  /// No description provided for @searchLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more results'**
  String get searchLoadMore;

  /// No description provided for @nodesTrustedSection.
  ///
  /// In en, this message translates to:
  /// **'Trusted'**
  String get nodesTrustedSection;

  /// No description provided for @nodesNearbySection.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nodesNearbySection;

  /// No description provided for @nodesTrustedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} nodes'**
  String nodesTrustedCount(Object count);

  /// No description provided for @nodesNearbyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} nodes'**
  String nodesNearbyCount(Object count);

  /// No description provided for @nodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Node not found'**
  String get nodeNotFound;

  /// No description provided for @nodeIdentitySection.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get nodeIdentitySection;

  /// No description provided for @nodeFingerprintLabel.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get nodeFingerprintLabel;

  /// No description provided for @nodeTrustLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Trust level'**
  String get nodeTrustLevelLabel;

  /// No description provided for @nodeTrustKnown.
  ///
  /// In en, this message translates to:
  /// **'Known'**
  String get nodeTrustKnown;

  /// No description provided for @nodeTrustVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get nodeTrustVerified;

  /// No description provided for @nodeTrustBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get nodeTrustBlocked;

  /// No description provided for @nodeNotInContacts.
  ///
  /// In en, this message translates to:
  /// **'Not in your nodes'**
  String get nodeNotInContacts;

  /// No description provided for @nodeVerificationSection.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get nodeVerificationSection;

  /// No description provided for @nodeShowVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Show verification code'**
  String get nodeShowVerificationCode;

  /// No description provided for @nodeVerificationNote.
  ///
  /// In en, this message translates to:
  /// **'Ask the owner to read this code back to you. Matching codes mean the connection is authentic.'**
  String get nodeVerificationNote;

  /// No description provided for @nodeVerificationCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get nodeVerificationCodeTitle;

  /// No description provided for @nodeConnectionSection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get nodeConnectionSection;

  /// No description provided for @nodeRssiLatest.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get nodeRssiLatest;

  /// No description provided for @nodeRssiSmoothed.
  ///
  /// In en, this message translates to:
  /// **'Smoothed RSSI'**
  String get nodeRssiSmoothed;

  /// No description provided for @nodeDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get nodeDistanceLabel;

  /// No description provided for @nodeHopLabel.
  ///
  /// In en, this message translates to:
  /// **'Hops'**
  String get nodeHopLabel;

  /// No description provided for @nodeFirstSeen.
  ///
  /// In en, this message translates to:
  /// **'First seen'**
  String get nodeFirstSeen;

  /// No description provided for @nodeLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get nodeLastSeen;

  /// No description provided for @nodeLinkQuality.
  ///
  /// In en, this message translates to:
  /// **'Link quality'**
  String get nodeLinkQuality;

  /// No description provided for @nodeCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get nodeCapabilities;

  /// No description provided for @nodeCapabilityRelay.
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get nodeCapabilityRelay;

  /// No description provided for @nodeCapabilityRouter.
  ///
  /// In en, this message translates to:
  /// **'Router'**
  String get nodeCapabilityRouter;

  /// No description provided for @nodeCapabilityStoreForward.
  ///
  /// In en, this message translates to:
  /// **'Store & forward'**
  String get nodeCapabilityStoreForward;

  /// No description provided for @nodeOpenConversation.
  ///
  /// In en, this message translates to:
  /// **'Open conversation'**
  String get nodeOpenConversation;

  /// No description provided for @nodeActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Node actions'**
  String get nodeActionsTitle;

  /// No description provided for @nodeTrustSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Trust level'**
  String get nodeTrustSelectionTitle;

  /// No description provided for @nearbyScan.
  ///
  /// In en, this message translates to:
  /// **'Scan for devices'**
  String get nearbyScan;

  /// No description provided for @nearbyStopScan.
  ///
  /// In en, this message translates to:
  /// **'Stop scanning'**
  String get nearbyStopScan;

  /// No description provided for @nearbyScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get nearbyScanning;

  /// No description provided for @nearbyRadioOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off'**
  String get nearbyRadioOffTitle;

  /// No description provided for @nearbyRadioOffMessage.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth to discover nearby nodes.'**
  String get nearbyRadioOffMessage;

  /// No description provided for @nearbyRadioUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth unavailable'**
  String get nearbyRadioUnavailableTitle;

  /// No description provided for @nearbyRadioUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This device has no usable Bluetooth adapter.'**
  String get nearbyRadioUnavailableMessage;

  /// No description provided for @nearbyPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth access needed'**
  String get nearbyPermissionTitle;

  /// No description provided for @nearbyPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'OneBit uses Bluetooth to discover and connect to nearby nodes. No data leaves your device.'**
  String get nearbyPermissionMessage;

  /// No description provided for @nearbyPeerCount.
  ///
  /// In en, this message translates to:
  /// **'{count} devices'**
  String nearbyPeerCount(Object count);

  /// No description provided for @nearbyPeersTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get nearbyPeersTitle;

  /// No description provided for @nodesOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get nodesOfflineTitle;

  /// No description provided for @nodesOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'The mesh radio is not running. Known nodes stay listed on this device.'**
  String get nodesOfflineMessage;

  /// No description provided for @nodesPeerIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Peer ID'**
  String get nodesPeerIdLabel;

  /// No description provided for @nodesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Nodes could not be loaded'**
  String get nodesLoadError;

  /// No description provided for @nearbyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices could not be loaded'**
  String get nearbyLoadError;

  /// No description provided for @nodeConnectionAdvertising.
  ///
  /// In en, this message translates to:
  /// **'Advertising'**
  String get nodeConnectionAdvertising;

  /// No description provided for @nodeConnectionConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get nodeConnectionConnecting;

  /// No description provided for @nodeConnectionConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get nodeConnectionConnected;

  /// No description provided for @nodeConnectionDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting'**
  String get nodeConnectionDisconnecting;

  /// No description provided for @nodeConnectionDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get nodeConnectionDisconnected;

  /// No description provided for @nodeVerificationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get nodeVerificationUnknown;

  /// No description provided for @nodeVerificationTrusted.
  ///
  /// In en, this message translates to:
  /// **'Trusted'**
  String get nodeVerificationTrusted;

  /// No description provided for @nodeRemoveContact.
  ///
  /// In en, this message translates to:
  /// **'Remove from nodes'**
  String get nodeRemoveContact;

  /// No description provided for @nodeRemoveContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove node?'**
  String get nodeRemoveContactTitle;

  /// No description provided for @nodeRemoveContactMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the node from your device. Existing conversations are kept.'**
  String get nodeRemoveContactMessage;

  /// No description provided for @nodeContactRemoved.
  ///
  /// In en, this message translates to:
  /// **'Node removed'**
  String get nodeContactRemoved;

  /// No description provided for @nodeNotNearby.
  ///
  /// In en, this message translates to:
  /// **'This node is not currently nearby'**
  String get nodeNotNearby;

  /// No description provided for @nodeChannelOpened.
  ///
  /// In en, this message translates to:
  /// **'Conversation opened'**
  String get nodeChannelOpened;

  /// No description provided for @nodeChannelCreateError.
  ///
  /// In en, this message translates to:
  /// **'Could not open a conversation'**
  String get nodeChannelCreateError;

  /// No description provided for @nodeVerificationCodeError.
  ///
  /// In en, this message translates to:
  /// **'Could not derive the verification code'**
  String get nodeVerificationCodeError;

  /// No description provided for @nearbyPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission is permanently denied'**
  String get nearbyPermissionDenied;

  /// No description provided for @nearbyPermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Grant Bluetooth access in system settings, then scan again.'**
  String get nearbyPermissionDeniedMessage;

  /// No description provided for @nearbyOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get nearbyOpenSettings;

  /// No description provided for @nearbyRssiLabel.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get nearbyRssiLabel;

  /// No description provided for @nearbyScanError.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get nearbyScanError;

  /// No description provided for @nearbyScanToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle scanning'**
  String get nearbyScanToggle;

  /// No description provided for @nodeTrustLabel.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get nodeTrustLabel;

  /// No description provided for @nodeIdentityNote.
  ///
  /// In en, this message translates to:
  /// **'Identity material is only available for nodes you added.'**
  String get nodeIdentityNote;

  /// No description provided for @nodeUnknownNode.
  ///
  /// In en, this message translates to:
  /// **'Unknown node'**
  String get nodeUnknownNode;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get commonPause;

  /// No description provided for @commonResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get commonResume;

  /// No description provided for @composeEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get composeEditTitle;

  /// No description provided for @composeReplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get composeReplyTitle;

  /// No description provided for @composeHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get composeHint;

  /// No description provided for @composeOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Offline — messages stay queued'**
  String get composeOfflineHint;

  /// No description provided for @composeReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to'**
  String get composeReplyingTo;

  /// No description provided for @composeEditingMessage.
  ///
  /// In en, this message translates to:
  /// **'Editing message'**
  String get composeEditingMessage;

  /// No description provided for @composeAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get composeAttachFile;

  /// No description provided for @composeVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get composeVoiceNote;

  /// No description provided for @composeEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get composeEmoji;

  /// No description provided for @composeVoiceNoteAttached.
  ///
  /// In en, this message translates to:
  /// **'Voice note attached'**
  String get composeVoiceNoteAttached;

  /// No description provided for @composeAttachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get composeAttachmentTitle;

  /// No description provided for @composeAttachmentImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get composeAttachmentImage;

  /// No description provided for @composeAttachmentDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get composeAttachmentDocument;

  /// No description provided for @composeAttachmentFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get composeAttachmentFile;

  /// No description provided for @composeAttachmentError.
  ///
  /// In en, this message translates to:
  /// **'Could not attach the file'**
  String get composeAttachmentError;

  /// No description provided for @composeVoiceRecordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get composeVoiceRecordingTitle;

  /// No description provided for @composeVoiceRecordingHint.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get composeVoiceRecordingHint;

  /// No description provided for @composeVoiceRecordStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get composeVoiceRecordStart;

  /// No description provided for @composeVoiceRecordStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get composeVoiceRecordStop;

  /// No description provided for @composeVoiceRecordDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get composeVoiceRecordDiscard;

  /// No description provided for @composeVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice recording is not available on this device'**
  String get composeVoiceUnavailable;

  /// No description provided for @composeVoiceError.
  ///
  /// In en, this message translates to:
  /// **'Could not record the voice note'**
  String get composeVoiceError;

  /// No description provided for @composeDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get composeDraftSaved;

  /// No description provided for @composeMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent'**
  String get composeMessageSent;

  /// No description provided for @composeSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the message'**
  String get composeSendFailed;

  /// No description provided for @messageActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Message actions'**
  String get messageActionsTitle;

  /// No description provided for @messageReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get messageReply;

  /// No description provided for @messageCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get messageCopy;

  /// No description provided for @messageForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get messageForward;

  /// No description provided for @messageEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get messageEdit;

  /// No description provided for @messageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get messageDelete;

  /// No description provided for @messageRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get messageRetry;

  /// No description provided for @messageSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get messageSelect;

  /// No description provided for @selectionSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectionSelectAll;

  /// No description provided for @selectionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get selectionCopy;

  /// No description provided for @selectionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get selectionDelete;

  /// No description provided for @channelTyping.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get channelTyping;

  /// No description provided for @channelReplyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}'**
  String channelReplyTo(Object name);

  /// No description provided for @commonYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get commonYou;

  /// No description provided for @commonDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get commonDelivered;

  /// No description provided for @commonVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get commonVerified;

  /// No description provided for @commonRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get commonRead;

  /// No description provided for @composeAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get composeAttach;

  /// No description provided for @messageEditedLabel.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get messageEditedLabel;

  /// No description provided for @messageForwardedLabel.
  ///
  /// In en, this message translates to:
  /// **'Forwarded'**
  String get messageForwardedLabel;

  /// No description provided for @forwardToTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward to…'**
  String get forwardToTitle;

  /// No description provided for @conversationComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get conversationComposerHint;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the message'**
  String get sendFailed;

  /// No description provided for @editFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t edit the message'**
  String get editFailed;

  /// No description provided for @forwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t forward the message'**
  String get forwardFailed;

  /// No description provided for @channelPinMessage.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get channelPinMessage;

  /// No description provided for @channelUnpinMessage.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get channelUnpinMessage;

  /// No description provided for @messageCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied'**
  String get messageCopied;

  /// No description provided for @messageDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get messageDeletedTitle;

  /// No description provided for @messageDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'This message will be removed for you and your peers.'**
  String get messageDeletedMessage;

  /// No description provided for @messageEditedSuffix.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get messageEditedSuffix;

  /// No description provided for @messageForwardedSuffix.
  ///
  /// In en, this message translates to:
  /// **'forwarded'**
  String get messageForwardedSuffix;

  /// No description provided for @messageTyping.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing…'**
  String messageTyping(Object name);

  /// No description provided for @messageSomeoneTyping.
  ///
  /// In en, this message translates to:
  /// **'Someone is typing…'**
  String get messageSomeoneTyping;

  /// No description provided for @messageSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String messageSelectionCount(Object count);

  /// No description provided for @messageSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get messageSelectAll;

  /// No description provided for @messageClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get messageClearSelection;

  /// No description provided for @messageStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get messageStatusSending;

  /// No description provided for @messageStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get messageStatusQueued;

  /// No description provided for @messageStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get messageStatusWaiting;

  /// No description provided for @messageStatusRouting.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get messageStatusRouting;

  /// No description provided for @messageStatusRelayed.
  ///
  /// In en, this message translates to:
  /// **'Relayed'**
  String get messageStatusRelayed;

  /// No description provided for @messageStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get messageStatusDelivered;

  /// No description provided for @messageStatusVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get messageStatusVerified;

  /// No description provided for @messageStatusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get messageStatusRead;

  /// No description provided for @messageStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get messageStatusExpired;

  /// No description provided for @messageStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get messageStatusFailed;

  /// No description provided for @messageRepliedToLabel.
  ///
  /// In en, this message translates to:
  /// **'Replying to'**
  String get messageRepliedToLabel;

  /// No description provided for @messageOriginalDeleted.
  ///
  /// In en, this message translates to:
  /// **'Original message deleted'**
  String get messageOriginalDeleted;

  /// No description provided for @messageForwardTo.
  ///
  /// In en, this message translates to:
  /// **'Forward to'**
  String get messageForwardTo;

  /// No description provided for @messageNoChannels.
  ///
  /// In en, this message translates to:
  /// **'No conversations to forward to'**
  String get messageNoChannels;

  /// No description provided for @messagePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get messagePlay;

  /// No description provided for @messageStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get messageStop;

  /// No description provided for @messageTapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get messageTapToOpen;

  /// No description provided for @messageAttachmentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} attachment(s)'**
  String messageAttachmentCount(Object count);

  /// No description provided for @qrIdentityCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity card'**
  String get qrIdentityCardTitle;

  /// No description provided for @qrIdentityNodeId.
  ///
  /// In en, this message translates to:
  /// **'Node ID'**
  String get qrIdentityNodeId;

  /// No description provided for @qrIdentityFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get qrIdentityFingerprint;

  /// No description provided for @qrIdentityCopyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Copy fingerprint'**
  String get qrIdentityCopyFingerprint;

  /// No description provided for @qrIdentityFingerprintCopied.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint copied'**
  String get qrIdentityFingerprintCopied;

  /// No description provided for @qrIdentityShare.
  ///
  /// In en, this message translates to:
  /// **'Share identity'**
  String get qrIdentityShare;

  /// No description provided for @qrIdentityShareCopied.
  ///
  /// In en, this message translates to:
  /// **'Identity card copied to clipboard'**
  String get qrIdentityShareCopied;

  /// No description provided for @qrIdentityVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get qrIdentityVerification;

  /// No description provided for @qrIdentityVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get qrIdentityVerified;

  /// No description provided for @qrIdentityUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get qrIdentityUnverified;

  /// No description provided for @qrIdentityScanHint.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code with another node to verify your identity.'**
  String get qrIdentityScanHint;

  /// No description provided for @qrIdentityBuildError.
  ///
  /// In en, this message translates to:
  /// **'Could not build the identity card'**
  String get qrIdentityBuildError;

  /// No description provided for @qrIdentityCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get qrIdentityCreated;

  /// No description provided for @qrIdentityDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get qrIdentityDisplayName;

  /// No description provided for @qrScannerScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get qrScannerScanning;

  /// No description provided for @qrScannerStart.
  ///
  /// In en, this message translates to:
  /// **'Start scanning'**
  String get qrScannerStart;

  /// No description provided for @qrScannerCancelScan.
  ///
  /// In en, this message translates to:
  /// **'Stop scanning'**
  String get qrScannerCancelScan;

  /// No description provided for @qrScannerPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access needed'**
  String get qrScannerPermissionTitle;

  /// No description provided for @qrScannerPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'OneBit uses the camera to scan identity QR codes. Nothing is recorded or shared.'**
  String get qrScannerPermissionMessage;

  /// No description provided for @qrScannerAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow camera'**
  String get qrScannerAllow;

  /// No description provided for @qrScannerOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get qrScannerOpenSettings;

  /// No description provided for @qrScannerInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Not a valid identity card'**
  String get qrScannerInvalidTitle;

  /// No description provided for @qrScannerInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'This QR code does not contain a valid OneBit identity card.'**
  String get qrScannerInvalidMessage;

  /// No description provided for @qrScannerScanAnother.
  ///
  /// In en, this message translates to:
  /// **'Scan another'**
  String get qrScannerScanAnother;

  /// No description provided for @qrScannerErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get qrScannerErrorTitle;

  /// No description provided for @qrScannerCancelled.
  ///
  /// In en, this message translates to:
  /// **'Scan cancelled'**
  String get qrScannerCancelled;

  /// No description provided for @qrScannerFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity found'**
  String get qrScannerFoundTitle;

  /// No description provided for @qrScannerFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} · {nodeId}'**
  String qrScannerFoundMessage(Object name, Object nodeId);

  /// No description provided for @qrScannerAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add to nodes'**
  String get qrScannerAddContact;

  /// No description provided for @qrScannerContactAdded.
  ///
  /// In en, this message translates to:
  /// **'Node added'**
  String get qrScannerContactAdded;

  /// No description provided for @qrScannerFingerprintMatches.
  ///
  /// In en, this message translates to:
  /// **'Compare fingerprints to verify this identity.'**
  String get qrScannerFingerprintMatches;

  /// No description provided for @transferQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get transferQueued;

  /// No description provided for @transferTransferring.
  ///
  /// In en, this message translates to:
  /// **'Transferring'**
  String get transferTransferring;

  /// No description provided for @transferPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get transferPaused;

  /// No description provided for @transferResuming.
  ///
  /// In en, this message translates to:
  /// **'Resuming'**
  String get transferResuming;

  /// No description provided for @transferVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get transferVerifying;

  /// No description provided for @transferCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get transferCompleted;

  /// No description provided for @transferFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transferFailed;

  /// No description provided for @transferCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get transferCancelled;

  /// No description provided for @transferExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get transferExpired;

  /// No description provided for @transferSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get transferSending;

  /// No description provided for @transferReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get transferReceiving;

  /// No description provided for @transferRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get transferRemaining;

  /// No description provided for @transferSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get transferSpeed;

  /// No description provided for @transferEta.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get transferEta;

  /// No description provided for @transferEtaUnknown.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get transferEtaUnknown;

  /// No description provided for @transferCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel transfer?'**
  String get transferCancelTitle;

  /// No description provided for @transferCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'The partial transfer will be discarded.'**
  String get transferCancelMessage;

  /// No description provided for @transferNotFound.
  ///
  /// In en, this message translates to:
  /// **'Transfer not found'**
  String get transferNotFound;

  /// No description provided for @transferFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get transferFile;

  /// No description provided for @transferSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get transferSize;

  /// No description provided for @transferPeer.
  ///
  /// In en, this message translates to:
  /// **'Peer'**
  String get transferPeer;

  /// No description provided for @transferAttempts.
  ///
  /// In en, this message translates to:
  /// **'Attempt {count}'**
  String transferAttempts(Object count);

  /// No description provided for @transferError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get transferError;

  /// No description provided for @transferStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get transferStarted;

  /// No description provided for @transferProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'{transferred} of {total}'**
  String transferProgressLabel(Object total, Object transferred);

  /// No description provided for @transferSpeedValue.
  ///
  /// In en, this message translates to:
  /// **'{speed}/s'**
  String transferSpeedValue(Object speed);

  /// No description provided for @mediaGalleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No media yet'**
  String get mediaGalleryEmpty;

  /// No description provided for @mediaGalleryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Images, videos, audio, documents and voice notes appear here.'**
  String get mediaGalleryEmptyMessage;

  /// No description provided for @mediaGalleryUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Media unavailable'**
  String get mediaGalleryUnavailableTitle;

  /// No description provided for @mediaGalleryUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Saved media will appear here.'**
  String get mediaGalleryUnavailableMessage;

  /// No description provided for @mediaGalleryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Media could not be loaded'**
  String get mediaGalleryFailedTitle;

  /// No description provided for @mediaGalleryFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Try again in a moment.'**
  String get mediaGalleryFailedMessage;

  /// No description provided for @mediaGalleryOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get mediaGalleryOfflineTitle;

  /// No description provided for @mediaGalleryOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Saved media stays available on this device.'**
  String get mediaGalleryOfflineMessage;

  /// No description provided for @mediaGalleryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get mediaGalleryAll;

  /// No description provided for @mediaGalleryImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get mediaGalleryImages;

  /// No description provided for @mediaGalleryVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get mediaGalleryVideos;

  /// No description provided for @mediaGalleryAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get mediaGalleryAudio;

  /// No description provided for @mediaGalleryDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get mediaGalleryDocuments;

  /// No description provided for @mediaGalleryVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get mediaGalleryVoice;

  /// No description provided for @mediaCategoryImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get mediaCategoryImage;

  /// No description provided for @mediaCategoryVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get mediaCategoryVideo;

  /// No description provided for @mediaCategoryAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get mediaCategoryAudio;

  /// No description provided for @mediaCategoryVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get mediaCategoryVoice;

  /// No description provided for @mediaCategoryDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get mediaCategoryDocument;

  /// No description provided for @mediaCategoryArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get mediaCategoryArchive;

  /// No description provided for @mediaCategoryBinary.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get mediaCategoryBinary;

  /// No description provided for @mediaCategoryCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get mediaCategoryCustom;

  /// No description provided for @mediaAttachmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get mediaAttachmentUnavailable;

  /// No description provided for @mediaAttachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get mediaAttachmentFailed;

  /// No description provided for @mediaOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get mediaOpen;

  /// No description provided for @mediaSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get mediaSizeLabel;

  /// No description provided for @mediaDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get mediaDurationLabel;

  /// No description provided for @mediaDimensionLabel.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get mediaDimensionLabel;

  /// No description provided for @openingErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Launch failed'**
  String get openingErrorTitle;

  /// No description provided for @openingErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'The application could not start. Please try again.'**
  String get openingErrorDetail;

  /// No description provided for @introTagline.
  ///
  /// In en, this message translates to:
  /// **'Offline-first communication through a decentralized mesh.'**
  String get introTagline;

  /// No description provided for @introPrinciples.
  ///
  /// In en, this message translates to:
  /// **'No cloud.\nNo phone number.\nNo central server.'**
  String get introPrinciples;

  /// No description provided for @introInitLine.
  ///
  /// In en, this message translates to:
  /// **'[INIT] ONEBIT v{version}'**
  String introInitLine(Object version);

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @displayNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your display name'**
  String get displayNameTitle;

  /// No description provided for @displayNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This is the name other nodes can see when you communicate.'**
  String get displayNameSubtitle;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get displayNameHint;

  /// No description provided for @displayNamePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your display name is used as a human-readable name in OneBit. It is not an account or login credential.'**
  String get displayNamePrivacy;

  /// No description provided for @displayNameSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your display name. Please try again.'**
  String get displayNameSaveError;

  /// No description provided for @displayNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Display name cannot be empty.'**
  String get displayNameEmpty;

  /// No description provided for @displayNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Display name must be at most {maxLength} characters.'**
  String displayNameTooLong(Object maxLength);

  /// No description provided for @displayNameControlCharacters.
  ///
  /// In en, this message translates to:
  /// **'Display name contains invalid characters.'**
  String get displayNameControlCharacters;

  /// No description provided for @displayNameInvalidUnicode.
  ///
  /// In en, this message translates to:
  /// **'Display name contains invalid text.'**
  String get displayNameInvalidUnicode;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileDisplayNameLabel;

  /// No description provided for @profileDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get profileDisplayNameHint;

  /// No description provided for @profileNote.
  ///
  /// In en, this message translates to:
  /// **'The display name is presentation metadata. Your Node ID and cryptographic identity never change.'**
  String get profileNote;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileSaved;

  /// No description provided for @profileError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile. Please try again.'**
  String get profileError;

  /// No description provided for @initializingTitle.
  ///
  /// In en, this message translates to:
  /// **'Initializing OneBit'**
  String get initializingTitle;

  /// No description provided for @initializingIdle.
  ///
  /// In en, this message translates to:
  /// **'Preparing local services…'**
  String get initializingIdle;

  /// No description provided for @initializingIdentity.
  ///
  /// In en, this message translates to:
  /// **'Local identity'**
  String get initializingIdentity;

  /// No description provided for @initializingStorage.
  ///
  /// In en, this message translates to:
  /// **'Local storage'**
  String get initializingStorage;

  /// No description provided for @initializingMessaging.
  ///
  /// In en, this message translates to:
  /// **'Messaging'**
  String get initializingMessaging;

  /// No description provided for @initializingMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get initializingMedia;

  /// No description provided for @initializingMesh.
  ///
  /// In en, this message translates to:
  /// **'Mesh services'**
  String get initializingMesh;

  /// No description provided for @initializingFailed.
  ///
  /// In en, this message translates to:
  /// **'ONEBIT INITIALIZATION FAILED'**
  String get initializingFailed;

  /// No description provided for @nodeRouteSection.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get nodeRouteSection;

  /// No description provided for @nodeRouteAvailable.
  ///
  /// In en, this message translates to:
  /// **'Route available'**
  String get nodeRouteAvailable;

  /// No description provided for @nodeRouteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No route'**
  String get nodeRouteUnavailable;

  /// No description provided for @nodeRouteHopCount.
  ///
  /// In en, this message translates to:
  /// **'{count} hop'**
  String nodeRouteHopCount(Object count);

  /// No description provided for @nodeRouteHopCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} hops'**
  String nodeRouteHopCountPlural(Object count);

  /// No description provided for @nodeViewIdentity.
  ///
  /// In en, this message translates to:
  /// **'View identity'**
  String get nodeViewIdentity;

  /// No description provided for @nodeViewRoute.
  ///
  /// In en, this message translates to:
  /// **'View route'**
  String get nodeViewRoute;

  /// No description provided for @nodeTrustPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get nodeTrustPending;

  /// No description provided for @nodeTrustNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nodeTrustNearby;

  /// No description provided for @nearbyDiscoveryState.
  ///
  /// In en, this message translates to:
  /// **'Discovering'**
  String get nearbyDiscoveryState;

  /// No description provided for @nearbyDistanceEstimate.
  ///
  /// In en, this message translates to:
  /// **'≈{distance} m'**
  String nearbyDistanceEstimate(Object distance);

  /// No description provided for @nearbyVerificationState.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get nearbyVerificationState;

  /// No description provided for @identityVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify identity'**
  String get identityVerifyTitle;

  /// No description provided for @identityVerifyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Compare fingerprints to verify this identity.'**
  String get identityVerifyFingerprint;

  /// No description provided for @identityVerifyMatch.
  ///
  /// In en, this message translates to:
  /// **'Fingerprints match'**
  String get identityVerifyMatch;

  /// No description provided for @identityVerifyMismatch.
  ///
  /// In en, this message translates to:
  /// **'Fingerprints do not match'**
  String get identityVerifyMismatch;

  /// No description provided for @identityVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get identityVerifiedBadge;

  /// No description provided for @identityUnverifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get identityUnverifiedBadge;

  /// No description provided for @meshOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get meshOverviewTitle;

  /// No description provided for @meshNetworkHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Network Health'**
  String get meshNetworkHealthTitle;

  /// No description provided for @meshTopologyTitle.
  ///
  /// In en, this message translates to:
  /// **'Topology'**
  String get meshTopologyTitle;

  /// No description provided for @meshActiveNodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Nodes'**
  String get meshActiveNodesTitle;

  /// No description provided for @meshRoutesTitle.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get meshRoutesTitle;

  /// No description provided for @meshStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get meshStatsTitle;

  /// No description provided for @meshEngineState.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get meshEngineState;

  /// No description provided for @meshEngineStart.
  ///
  /// In en, this message translates to:
  /// **'Start mesh'**
  String get meshEngineStart;

  /// No description provided for @meshEngineStop.
  ///
  /// In en, this message translates to:
  /// **'Stop mesh'**
  String get meshEngineStop;

  /// No description provided for @meshNeighborsLabel.
  ///
  /// In en, this message translates to:
  /// **'Neighbors'**
  String get meshNeighborsLabel;

  /// No description provided for @meshKnownNodesLabel.
  ///
  /// In en, this message translates to:
  /// **'Known nodes'**
  String get meshKnownNodesLabel;

  /// No description provided for @meshPartitionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Partitions'**
  String get meshPartitionsLabel;

  /// No description provided for @meshQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get meshQualityLabel;

  /// No description provided for @meshStabilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Stability'**
  String get meshStabilityLabel;

  /// No description provided for @meshRelayRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Relay rate'**
  String get meshRelayRateLabel;

  /// No description provided for @meshPacketSuccessLabel.
  ///
  /// In en, this message translates to:
  /// **'Packet success'**
  String get meshPacketSuccessLabel;

  /// No description provided for @meshPacketsPerMinute.
  ///
  /// In en, this message translates to:
  /// **'pkts/min'**
  String get meshPacketsPerMinute;

  /// No description provided for @meshRouteDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get meshRouteDestination;

  /// No description provided for @meshRouteNextHop.
  ///
  /// In en, this message translates to:
  /// **'Next hop'**
  String get meshRouteNextHop;

  /// No description provided for @meshRouteHopCount.
  ///
  /// In en, this message translates to:
  /// **'Hops'**
  String get meshRouteHopCount;

  /// No description provided for @meshRouteCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get meshRouteCost;

  /// No description provided for @meshRouteQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get meshRouteQuality;

  /// No description provided for @meshRouteReliability.
  ///
  /// In en, this message translates to:
  /// **'Reliability'**
  String get meshRouteReliability;

  /// No description provided for @meshRoutePreferred.
  ///
  /// In en, this message translates to:
  /// **'Preferred'**
  String get meshRoutePreferred;

  /// No description provided for @meshRoutePrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get meshRoutePrimary;

  /// No description provided for @meshRouteAlternative.
  ///
  /// In en, this message translates to:
  /// **'Alternative'**
  String get meshRouteAlternative;

  /// No description provided for @meshRouteExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get meshRouteExpired;

  /// No description provided for @meshRouteLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get meshRouteLastUsed;

  /// No description provided for @meshNodeLocal.
  ///
  /// In en, this message translates to:
  /// **'This node'**
  String get meshNodeLocal;

  /// No description provided for @meshNodeHop.
  ///
  /// In en, this message translates to:
  /// **'hop'**
  String get meshNodeHop;

  /// No description provided for @meshNodeHops.
  ///
  /// In en, this message translates to:
  /// **'hops'**
  String get meshNodeHops;

  /// No description provided for @meshNodeRssi.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get meshNodeRssi;

  /// No description provided for @meshNodeDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get meshNodeDistance;

  /// No description provided for @meshNodeConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get meshNodeConnection;

  /// No description provided for @meshNodeCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get meshNodeCapabilities;

  /// No description provided for @meshPacketSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get meshPacketSeen;

  /// No description provided for @meshPacketForwarded.
  ///
  /// In en, this message translates to:
  /// **'Forwarded'**
  String get meshPacketForwarded;

  /// No description provided for @meshPacketDeliveredUp.
  ///
  /// In en, this message translates to:
  /// **'Delivered up'**
  String get meshPacketDeliveredUp;

  /// No description provided for @meshPacketDrops.
  ///
  /// In en, this message translates to:
  /// **'Drops'**
  String get meshPacketDrops;

  /// No description provided for @meshPacketDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get meshPacketDuplicates;

  /// No description provided for @meshPacketSuccessRate.
  ///
  /// In en, this message translates to:
  /// **'Success rate'**
  String get meshPacketSuccessRate;

  /// No description provided for @meshDuplicateCache.
  ///
  /// In en, this message translates to:
  /// **'Duplicate cache'**
  String get meshDuplicateCache;

  /// No description provided for @meshDuplicateCacheCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get meshDuplicateCacheCapacity;

  /// No description provided for @meshDuplicateCacheEntries.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get meshDuplicateCacheEntries;

  /// No description provided for @meshDuplicateCacheHits.
  ///
  /// In en, this message translates to:
  /// **'Hits'**
  String get meshDuplicateCacheHits;

  /// No description provided for @meshDuplicateCacheEvictions.
  ///
  /// In en, this message translates to:
  /// **'Evictions'**
  String get meshDuplicateCacheEvictions;

  /// No description provided for @meshMemoryEstimate.
  ///
  /// In en, this message translates to:
  /// **'Memory estimate'**
  String get meshMemoryEstimate;

  /// No description provided for @meshEmptyNodes.
  ///
  /// In en, this message translates to:
  /// **'No active neighbors'**
  String get meshEmptyNodes;

  /// No description provided for @meshEmptyNodesMessage.
  ///
  /// In en, this message translates to:
  /// **'Start the mesh engine to discover nearby nodes.'**
  String get meshEmptyNodesMessage;

  /// No description provided for @meshEmptyRoutes.
  ///
  /// In en, this message translates to:
  /// **'No routes learned'**
  String get meshEmptyRoutes;

  /// No description provided for @meshEmptyRoutesMessage.
  ///
  /// In en, this message translates to:
  /// **'Routes appear as the mesh discovers paths to other nodes.'**
  String get meshEmptyRoutesMessage;

  /// No description provided for @meshEmptyTopology.
  ///
  /// In en, this message translates to:
  /// **'No topology data'**
  String get meshEmptyTopology;

  /// No description provided for @meshEmptyTopologyMessage.
  ///
  /// In en, this message translates to:
  /// **'Topology information appears when the mesh is running.'**
  String get meshEmptyTopologyMessage;

  /// No description provided for @meshVisualizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Network topology'**
  String get meshVisualizationTitle;

  /// No description provided for @meshVisualizationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No nodes to visualize'**
  String get meshVisualizationEmpty;

  /// No description provided for @meshVisualizationLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get meshVisualizationLocal;

  /// No description provided for @meshVisualizationLinkQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get meshVisualizationLinkQuality;

  /// No description provided for @meshRssiTitle.
  ///
  /// In en, this message translates to:
  /// **'RSSI'**
  String get meshRssiTitle;

  /// No description provided for @meshRssiLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get meshRssiLatest;

  /// No description provided for @meshRssiSmoothed.
  ///
  /// In en, this message translates to:
  /// **'Smoothed'**
  String get meshRssiSmoothed;

  /// No description provided for @meshLatencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get meshLatencyTitle;

  /// No description provided for @meshTtlTitle.
  ///
  /// In en, this message translates to:
  /// **'TTL'**
  String get meshTtlTitle;

  /// No description provided for @meshTtlDefault.
  ///
  /// In en, this message translates to:
  /// **'Default TTL'**
  String get meshTtlDefault;

  /// No description provided for @meshTtlValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get meshTtlValue;

  /// No description provided for @meshConnectionStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection state'**
  String get meshConnectionStateTitle;

  /// No description provided for @meshConnectionAdvertising.
  ///
  /// In en, this message translates to:
  /// **'Advertising'**
  String get meshConnectionAdvertising;

  /// No description provided for @meshConnectionConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get meshConnectionConnecting;

  /// No description provided for @meshConnectionConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get meshConnectionConnected;

  /// No description provided for @meshConnectionDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting'**
  String get meshConnectionDisconnecting;

  /// No description provided for @meshConnectionDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get meshConnectionDisconnected;

  /// No description provided for @settingsAppearanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose your visual identity'**
  String get settingsAppearanceDescription;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacyE2eLabel.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption'**
  String get settingsPrivacyE2eLabel;

  /// No description provided for @settingsPrivacyE2eDescription.
  ///
  /// In en, this message translates to:
  /// **'All messages are encrypted end-to-end. Only you and the recipient can read them.'**
  String get settingsPrivacyE2eDescription;

  /// No description provided for @settingsPrivacyIdentityLabel.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get settingsPrivacyIdentityLabel;

  /// No description provided for @settingsPrivacyIdentityDescription.
  ///
  /// In en, this message translates to:
  /// **'Your identity is stored locally on this device. No server holds your private keys.'**
  String get settingsPrivacyIdentityDescription;

  /// No description provided for @settingsPrivacyFingerprintLabel.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get settingsPrivacyFingerprintLabel;

  /// No description provided for @settingsPrivacyFingerprintDescription.
  ///
  /// In en, this message translates to:
  /// **'Each device has a unique fingerprint used to verify identity.'**
  String get settingsPrivacyFingerprintDescription;

  /// No description provided for @settingsPrivacyLocalStorageLabel.
  ///
  /// In en, this message translates to:
  /// **'Local storage'**
  String get settingsPrivacyLocalStorageLabel;

  /// No description provided for @settingsPrivacyLocalStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'All data stays on your device. Nothing is uploaded to any server.'**
  String get settingsPrivacyLocalStorageDescription;

  /// No description provided for @settingsPrivacyNoServerLabel.
  ///
  /// In en, this message translates to:
  /// **'No server dependency'**
  String get settingsPrivacyNoServerLabel;

  /// No description provided for @settingsPrivacyNoServerDescription.
  ///
  /// In en, this message translates to:
  /// **'OneBit works entirely offline via Bluetooth mesh. No internet connection required.'**
  String get settingsPrivacyNoServerDescription;

  /// No description provided for @settingsStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorageTitle;

  /// No description provided for @settingsStorageUsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get settingsStorageUsedLabel;

  /// No description provided for @settingsStorageAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get settingsStorageAvailableLabel;

  /// No description provided for @settingsStorageCacheLabel.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get settingsStorageCacheLabel;

  /// No description provided for @settingsStorageAttachmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get settingsStorageAttachmentsLabel;

  /// No description provided for @settingsStorageTempLabel.
  ///
  /// In en, this message translates to:
  /// **'Temporary files'**
  String get settingsStorageTempLabel;

  /// No description provided for @settingsStorageCleanup.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get settingsStorageCleanup;

  /// No description provided for @settingsStorageCleanupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear cached files?'**
  String get settingsStorageCleanupConfirm;

  /// No description provided for @settingsStorageCleanupMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes temporary and cached files. Attachments and messages are kept.'**
  String get settingsStorageCleanupMessage;

  /// No description provided for @settingsStorageCleanupDone.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get settingsStorageCleanupDone;

  /// No description provided for @settingsStorageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No storage information available'**
  String get settingsStorageEmpty;

  /// No description provided for @settingsNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsTitle;

  /// No description provided for @settingsNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences will be configurable when the messaging engine supports notification rules.'**
  String get settingsNotificationsDescription;

  /// No description provided for @settingsBluetoothTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get settingsBluetoothTitle;

  /// No description provided for @settingsBluetoothStateLabel.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get settingsBluetoothStateLabel;

  /// No description provided for @settingsBluetoothEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get settingsBluetoothEnabled;

  /// No description provided for @settingsBluetoothDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get settingsBluetoothDisabled;

  /// No description provided for @settingsBluetoothUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get settingsBluetoothUnavailable;

  /// No description provided for @settingsBluetoothPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get settingsBluetoothPermissionDenied;

  /// No description provided for @settingsBluetoothScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get settingsBluetoothScanning;

  /// No description provided for @settingsBluetoothConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsBluetoothConnected;

  /// No description provided for @settingsBluetoothDescription.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth state reflects the local adapter. OneBit uses BLE for mesh communication.'**
  String get settingsBluetoothDescription;

  /// No description provided for @settingsBluetoothOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get settingsBluetoothOpenSettings;

  /// No description provided for @aboutBuildLabel.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get aboutBuildLabel;

  /// No description provided for @aboutTechnicalInfo.
  ///
  /// In en, this message translates to:
  /// **'Technical information'**
  String get aboutTechnicalInfo;

  /// No description provided for @aboutPlatformLabel.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get aboutPlatformLabel;

  /// No description provided for @aboutEngineLabel.
  ///
  /// In en, this message translates to:
  /// **'Mesh engine'**
  String get aboutEngineLabel;

  /// No description provided for @devHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer tools'**
  String get devHubTitle;

  /// No description provided for @devHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspection, diagnostics and performance'**
  String get devHubSubtitle;

  /// No description provided for @devPacketInspector.
  ///
  /// In en, this message translates to:
  /// **'Packet inspector'**
  String get devPacketInspector;

  /// No description provided for @devPacketInspectorDesc.
  ///
  /// In en, this message translates to:
  /// **'Compose, inspect and decode protocol frames'**
  String get devPacketInspectorDesc;

  /// No description provided for @devMeshInspector.
  ///
  /// In en, this message translates to:
  /// **'Mesh inspector'**
  String get devMeshInspector;

  /// No description provided for @devMeshInspectorDesc.
  ///
  /// In en, this message translates to:
  /// **'Neighbors, routes, RSSI and topology details'**
  String get devMeshInspectorDesc;

  /// No description provided for @devLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get devLogs;

  /// No description provided for @devLogsDesc.
  ///
  /// In en, this message translates to:
  /// **'System log buffer with search and filter'**
  String get devLogsDesc;

  /// No description provided for @devDatabaseViewer.
  ///
  /// In en, this message translates to:
  /// **'Database viewer'**
  String get devDatabaseViewer;

  /// No description provided for @devDatabaseViewerDesc.
  ///
  /// In en, this message translates to:
  /// **'Table row counts and storage diagnostics'**
  String get devDatabaseViewerDesc;

  /// No description provided for @devStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get devStatistics;

  /// No description provided for @devStatisticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Packet, mesh, DTN and storage counters'**
  String get devStatisticsDesc;

  /// No description provided for @devPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get devPerformance;

  /// No description provided for @devPerformanceDesc.
  ///
  /// In en, this message translates to:
  /// **'FPS, memory and system resource usage'**
  String get devPerformanceDesc;

  /// No description provided for @devDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get devDiagnosticsTitle;

  /// No description provided for @devDiagnosticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Engine state, radio health and diagnostic probes'**
  String get devDiagnosticsDesc;

  /// No description provided for @logsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search logs'**
  String get logsSearchHint;

  /// No description provided for @logsFilterLevel.
  ///
  /// In en, this message translates to:
  /// **'Filter level'**
  String get logsFilterLevel;

  /// No description provided for @logsAllLevels.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get logsAllLevels;

  /// No description provided for @logsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get logsCopy;

  /// No description provided for @logsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get logsCopied;

  /// No description provided for @logsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log records'**
  String get logsEmpty;

  /// No description provided for @logsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Log records appear here as the system runs.'**
  String get logsEmptyMessage;

  /// No description provided for @logsAutoRefresh.
  ///
  /// In en, this message translates to:
  /// **'Auto-refresh'**
  String get logsAutoRefresh;

  /// No description provided for @dbViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Database viewer'**
  String get dbViewerTitle;

  /// No description provided for @dbViewerTableMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get dbViewerTableMessages;

  /// No description provided for @dbViewerTableChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get dbViewerTableChannels;

  /// No description provided for @dbViewerTablePackets.
  ///
  /// In en, this message translates to:
  /// **'Packets'**
  String get dbViewerTablePackets;

  /// No description provided for @dbViewerTableRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get dbViewerTableRoutes;

  /// No description provided for @dbViewerTableNeighbors.
  ///
  /// In en, this message translates to:
  /// **'Neighbors'**
  String get dbViewerTableNeighbors;

  /// No description provided for @dbViewerTableTrustedNodes.
  ///
  /// In en, this message translates to:
  /// **'Trusted nodes'**
  String get dbViewerTableTrustedNodes;

  /// No description provided for @dbViewerTableSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get dbViewerTableSessions;

  /// No description provided for @dbViewerTableLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get dbViewerTableLogs;

  /// No description provided for @dbViewerTableStats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get dbViewerTableStats;

  /// No description provided for @dbViewerTableDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get dbViewerTableDiagnostics;

  /// No description provided for @dbViewerTableEvents.
  ///
  /// In en, this message translates to:
  /// **'Developer events'**
  String get dbViewerTableEvents;

  /// No description provided for @dbViewerTotalRows.
  ///
  /// In en, this message translates to:
  /// **'Total rows'**
  String get dbViewerTotalRows;

  /// No description provided for @dbViewerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No data loaded'**
  String get dbViewerEmpty;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsPacketSection.
  ///
  /// In en, this message translates to:
  /// **'Packet protocol'**
  String get statsPacketSection;

  /// No description provided for @statsMeshSection.
  ///
  /// In en, this message translates to:
  /// **'Mesh engine'**
  String get statsMeshSection;

  /// No description provided for @statsDtnSection.
  ///
  /// In en, this message translates to:
  /// **'DTN store-and-forward'**
  String get statsDtnSection;

  /// No description provided for @statsStorageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get statsStorageSection;

  /// No description provided for @statsMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get statsMessages;

  /// No description provided for @statsPacketsCreated.
  ///
  /// In en, this message translates to:
  /// **'Packets created'**
  String get statsPacketsCreated;

  /// No description provided for @statsPacketsSent.
  ///
  /// In en, this message translates to:
  /// **'Packets sent'**
  String get statsPacketsSent;

  /// No description provided for @statsPacketsDelivered.
  ///
  /// In en, this message translates to:
  /// **'Packets delivered'**
  String get statsPacketsDelivered;

  /// No description provided for @statsPacketsRejected.
  ///
  /// In en, this message translates to:
  /// **'Packets rejected'**
  String get statsPacketsRejected;

  /// No description provided for @statsBytesSent.
  ///
  /// In en, this message translates to:
  /// **'Bytes sent'**
  String get statsBytesSent;

  /// No description provided for @statsFragmentsAccepted.
  ///
  /// In en, this message translates to:
  /// **'Fragments accepted'**
  String get statsFragmentsAccepted;

  /// No description provided for @statsFragmentsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Fragments completed'**
  String get statsFragmentsCompleted;

  /// No description provided for @statsFragmentsExpired.
  ///
  /// In en, this message translates to:
  /// **'Fragments expired'**
  String get statsFragmentsExpired;

  /// No description provided for @statsActiveAssemblies.
  ///
  /// In en, this message translates to:
  /// **'Active assemblies'**
  String get statsActiveAssemblies;

  /// No description provided for @statsMeshPacketsSeen.
  ///
  /// In en, this message translates to:
  /// **'Packets seen'**
  String get statsMeshPacketsSeen;

  /// No description provided for @statsMeshPacketsForwarded.
  ///
  /// In en, this message translates to:
  /// **'Packets forwarded'**
  String get statsMeshPacketsForwarded;

  /// No description provided for @statsMeshPacketsDeliveredUp.
  ///
  /// In en, this message translates to:
  /// **'Delivered up'**
  String get statsMeshPacketsDeliveredUp;

  /// No description provided for @statsMeshDrops.
  ///
  /// In en, this message translates to:
  /// **'Drops'**
  String get statsMeshDrops;

  /// No description provided for @statsMeshDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get statsMeshDuplicates;

  /// No description provided for @statsMeshPacketSuccessRate.
  ///
  /// In en, this message translates to:
  /// **'Packet success rate'**
  String get statsMeshPacketSuccessRate;

  /// No description provided for @statsMeshRoutesLearned.
  ///
  /// In en, this message translates to:
  /// **'Routes learned'**
  String get statsMeshRoutesLearned;

  /// No description provided for @statsMeshRouteSwitches.
  ///
  /// In en, this message translates to:
  /// **'Route switches'**
  String get statsMeshRouteSwitches;

  /// No description provided for @statsDtnStored.
  ///
  /// In en, this message translates to:
  /// **'Stored'**
  String get statsDtnStored;

  /// No description provided for @statsDtnDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statsDtnDelivered;

  /// No description provided for @statsDtnAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get statsDtnAcknowledged;

  /// No description provided for @statsDtnExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statsDtnExpired;

  /// No description provided for @statsDtnRetried.
  ///
  /// In en, this message translates to:
  /// **'Retried'**
  String get statsDtnRetried;

  /// No description provided for @statsDtnRelayed.
  ///
  /// In en, this message translates to:
  /// **'Relayed'**
  String get statsDtnRelayed;

  /// No description provided for @statsDtnParked.
  ///
  /// In en, this message translates to:
  /// **'Parked'**
  String get statsDtnParked;

  /// No description provided for @statsDtnAvgLatency.
  ///
  /// In en, this message translates to:
  /// **'Avg delivery latency'**
  String get statsDtnAvgLatency;

  /// No description provided for @statsStorageRoot.
  ///
  /// In en, this message translates to:
  /// **'Root storage'**
  String get statsStorageRoot;

  /// No description provided for @statsStorageFree.
  ///
  /// In en, this message translates to:
  /// **'Free space'**
  String get statsStorageFree;

  /// No description provided for @statsStoragePayload.
  ///
  /// In en, this message translates to:
  /// **'Payloads'**
  String get statsStoragePayload;

  /// No description provided for @statsStorageTemp.
  ///
  /// In en, this message translates to:
  /// **'Temporary'**
  String get statsStorageTemp;

  /// No description provided for @statsStorageCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get statsStorageCache;

  /// No description provided for @statsStorageAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get statsStorageAttachments;

  /// No description provided for @perfTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get perfTitle;

  /// No description provided for @perfFpsSection.
  ///
  /// In en, this message translates to:
  /// **'Frame rate'**
  String get perfFpsSection;

  /// No description provided for @perfFps.
  ///
  /// In en, this message translates to:
  /// **'FPS'**
  String get perfFps;

  /// No description provided for @perfFpsDescription.
  ///
  /// In en, this message translates to:
  /// **'Estimated frames per second based on frame timing'**
  String get perfFpsDescription;

  /// No description provided for @perfMemorySection.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get perfMemorySection;

  /// No description provided for @perfMemoryUsage.
  ///
  /// In en, this message translates to:
  /// **'Memory usage'**
  String get perfMemoryUsage;

  /// No description provided for @perfMemoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Estimated from active providers and caches'**
  String get perfMemoryDescription;

  /// No description provided for @perfMeshMemoryEstimate.
  ///
  /// In en, this message translates to:
  /// **'Mesh memory estimate'**
  String get perfMeshMemoryEstimate;

  /// No description provided for @perfStorageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get perfStorageSection;

  /// No description provided for @perfDatabaseSection.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get perfDatabaseSection;

  /// No description provided for @perfDatabaseSize.
  ///
  /// In en, this message translates to:
  /// **'Database size'**
  String get perfDatabaseSize;

  /// No description provided for @perfLogBufferSize.
  ///
  /// In en, this message translates to:
  /// **'Log buffer size'**
  String get perfLogBufferSize;

  /// No description provided for @perfDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get perfDiagnostics;

  /// No description provided for @diagEngineState.
  ///
  /// In en, this message translates to:
  /// **'Engine state'**
  String get diagEngineState;

  /// No description provided for @diagRadioState.
  ///
  /// In en, this message translates to:
  /// **'Radio state'**
  String get diagRadioState;

  /// No description provided for @diagActiveNeighbors.
  ///
  /// In en, this message translates to:
  /// **'Active neighbors'**
  String get diagActiveNeighbors;

  /// No description provided for @diagKnownNodes.
  ///
  /// In en, this message translates to:
  /// **'Known nodes'**
  String get diagKnownNodes;

  /// No description provided for @diagRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get diagRoutes;

  /// No description provided for @diagMemoryEstimate.
  ///
  /// In en, this message translates to:
  /// **'Memory estimate'**
  String get diagMemoryEstimate;

  /// No description provided for @diagUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get diagUptime;

  /// No description provided for @diagPacketsPerMinute.
  ///
  /// In en, this message translates to:
  /// **'Packets/min'**
  String get diagPacketsPerMinute;

  /// No description provided for @diagConnectionQuality.
  ///
  /// In en, this message translates to:
  /// **'Connection quality'**
  String get diagConnectionQuality;

  /// No description provided for @diagMeshStability.
  ///
  /// In en, this message translates to:
  /// **'Mesh stability'**
  String get diagMeshStability;

  /// No description provided for @diagDuplicateCache.
  ///
  /// In en, this message translates to:
  /// **'Duplicate cache'**
  String get diagDuplicateCache;

  /// No description provided for @diagDtnQueueDepth.
  ///
  /// In en, this message translates to:
  /// **'DTN queue depth'**
  String get diagDtnQueueDepth;

  /// No description provided for @diagLogTagFilter.
  ///
  /// In en, this message translates to:
  /// **'Log tag filter'**
  String get diagLogTagFilter;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsTerminalPalette.
  ///
  /// In en, this message translates to:
  /// **'Terminal palette'**
  String get settingsTerminalPalette;

  /// No description provided for @settingsTerminalPaletteDescription.
  ///
  /// In en, this message translates to:
  /// **'IBM 5153 color palette for the terminal identity'**
  String get settingsTerminalPaletteDescription;

  /// No description provided for @settingsTerminalPaletteIbm5153.
  ///
  /// In en, this message translates to:
  /// **'IBM 5153'**
  String get settingsTerminalPaletteIbm5153;

  /// No description provided for @settingsTerminalPaletteIbm5153Description.
  ///
  /// In en, this message translates to:
  /// **'Classic IBM 5153 PC/AT palette'**
  String get settingsTerminalPaletteIbm5153Description;

  /// No description provided for @settingsTerminalPaletteFuture.
  ///
  /// In en, this message translates to:
  /// **'More palettes coming soon'**
  String get settingsTerminalPaletteFuture;

  /// No description provided for @settingsPrivacyIdentityPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Identity privacy'**
  String get settingsPrivacyIdentityPrivacy;

  /// No description provided for @settingsPrivacyIdentityPrivacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your cryptographic identity is stored locally. Private keys never leave this device.'**
  String get settingsPrivacyIdentityPrivacyDescription;

  /// No description provided for @settingsPrivacyMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get settingsPrivacyMetadata;

  /// No description provided for @settingsPrivacyMetadataDescription.
  ///
  /// In en, this message translates to:
  /// **'OneBit minimizes metadata exposure. Message timing and routing information stays within the mesh.'**
  String get settingsPrivacyMetadataDescription;

  /// No description provided for @settingsPrivacyNodeVisibility.
  ///
  /// In en, this message translates to:
  /// **'Node visibility'**
  String get settingsPrivacyNodeVisibility;

  /// No description provided for @settingsPrivacyNodeVisibilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Your node is only visible to devices within Bluetooth range. No central registry tracks you.'**
  String get settingsPrivacyNodeVisibilityDescription;

  /// No description provided for @settingsPrivacyVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get settingsPrivacyVerification;

  /// No description provided for @settingsPrivacyVerificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify node identities by comparing fingerprints. This ensures you\'re talking to the right person.'**
  String get settingsPrivacyVerificationDescription;

  /// No description provided for @settingsPrivacySecureStorage.
  ///
  /// In en, this message translates to:
  /// **'Secure storage'**
  String get settingsPrivacySecureStorage;

  /// No description provided for @settingsPrivacySecureStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'Cryptographic keys are stored in the device\'s secure enclave when available.'**
  String get settingsPrivacySecureStorageDescription;

  /// No description provided for @settingsStorageMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get settingsStorageMedia;

  /// No description provided for @settingsStorageMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get settingsStorageMessages;

  /// No description provided for @settingsStorageDatabase.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get settingsStorageDatabase;

  /// No description provided for @settingsStorageManageMedia.
  ///
  /// In en, this message translates to:
  /// **'Manage media'**
  String get settingsStorageManageMedia;

  /// No description provided for @settingsStorageRemoveTemp.
  ///
  /// In en, this message translates to:
  /// **'Remove temporary files'**
  String get settingsStorageRemoveTemp;

  /// No description provided for @settingsStorageRemoveTempConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove temporary files?'**
  String get settingsStorageRemoveTempConfirm;

  /// No description provided for @settingsStorageRemoveTempMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes temporary files created during transfers. Cached data and attachments are kept.'**
  String get settingsStorageRemoveTempMessage;

  /// No description provided for @settingsStorageRemoveTempDone.
  ///
  /// In en, this message translates to:
  /// **'Temporary files removed'**
  String get settingsStorageRemoveTempDone;

  /// No description provided for @settingsStorageManageMediaDescription.
  ///
  /// In en, this message translates to:
  /// **'Review and manage stored photos, videos, audio and documents'**
  String get settingsStorageManageMediaDescription;

  /// No description provided for @settingsStorageDatabaseDescription.
  ///
  /// In en, this message translates to:
  /// **'Local SQLite database for messages, channels and mesh state'**
  String get settingsStorageDatabaseDescription;

  /// No description provided for @settingsStorageMediaValue.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String settingsStorageMediaValue(Object count);

  /// No description provided for @settingsStorageMessagesValue.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String settingsStorageMessagesValue(Object count);

  /// No description provided for @settingsBluetoothMeshRadio.
  ///
  /// In en, this message translates to:
  /// **'Mesh radio'**
  String get settingsBluetoothMeshRadio;

  /// No description provided for @settingsBluetoothPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get settingsBluetoothPermissions;

  /// No description provided for @settingsBluetoothScanningState.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get settingsBluetoothScanningState;

  /// No description provided for @settingsBluetoothMeshRadioDescription.
  ///
  /// In en, this message translates to:
  /// **'BLE mesh radio state for decentralized communication'**
  String get settingsBluetoothMeshRadioDescription;

  /// No description provided for @settingsBluetoothPermissionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth and location permissions required for mesh operation'**
  String get settingsBluetoothPermissionsDescription;

  /// No description provided for @aboutVersionValue.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String aboutVersionValue(Object version);

  /// No description provided for @aboutDescriptionShort.
  ///
  /// In en, this message translates to:
  /// **'OneBit is a fully decentralized, offline-first Bluetooth Low Energy mesh communication platform.'**
  String get aboutDescriptionShort;

  /// No description provided for @aboutNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet. No cloud. No servers. No phone numbers. No accounts.'**
  String get aboutNoInternet;

  /// No description provided for @aboutEveryDevice.
  ///
  /// In en, this message translates to:
  /// **'Every device is a node, router, relay, cache and secure endpoint.'**
  String get aboutEveryDevice;

  /// No description provided for @licensesFlutterTitle.
  ///
  /// In en, this message translates to:
  /// **'Flutter packages'**
  String get licensesFlutterTitle;

  /// No description provided for @licensesOneBitTitle.
  ///
  /// In en, this message translates to:
  /// **'OneBit application'**
  String get licensesOneBitTitle;

  /// No description provided for @licensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View all open-source packages used by OneBit and their respective licenses.'**
  String get licensesSubtitle;

  /// No description provided for @licensesCopyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright (c) 2026 OneBit contributors'**
  String get licensesCopyright;

  /// No description provided for @settingsReducedMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduced motion'**
  String get settingsReducedMotion;

  /// No description provided for @settingsReducedMotionOn.
  ///
  /// In en, this message translates to:
  /// **'System setting: animations are reduced'**
  String get settingsReducedMotionOn;

  /// No description provided for @settingsReducedMotionOff.
  ///
  /// In en, this message translates to:
  /// **'System setting: full animations enabled'**
  String get settingsReducedMotionOff;

  /// No description provided for @settingsReducedMotionDescription.
  ///
  /// In en, this message translates to:
  /// **'Controlled by your device accessibility settings. OneBit respects the system reduced-motion preference.'**
  String get settingsReducedMotionDescription;

  /// No description provided for @settingsTerminalPreview.
  ///
  /// In en, this message translates to:
  /// **'Terminal preview'**
  String get settingsTerminalPreview;

  /// No description provided for @settingsTerminalPreviewSample.
  ///
  /// In en, this message translates to:
  /// **'Hello, World!'**
  String get settingsTerminalPreviewSample;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
