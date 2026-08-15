/// Canonical route paths for every product area.
///
/// This is the navigation registry: each feature registers its screen
/// against one of these constants. Keeping paths in one place makes deep
/// links and shell tabs stable across phases. Parameterized routes use
/// [AppRouteParameters] for their segment names; the path builders below
/// produce concrete deep-link locations.
///
/// Deep-link contract (future app-link registration):
///
/// | Addresses | Location |
/// | --- | --- |
/// | Channel | `onebit:///channels/:channelId` |
/// | Message | `onebit:///channels/:channelId/message/:messageId` |
/// | Node | `onebit:///nodes/:nodeId` |
/// | Transfer | `onebit:///transfers/:sessionId` |
/// | Settings | `onebit:///settings` (and `/settings/*` sections) |
abstract final class AppRoutePaths {
  // App flows ------------------------------------------------------------

  /// Brand opening animation; first screen the user sees.
  static const String launch = '/launch';

  /// First-run intro (shown after opening animation on fresh install).
  static const String intro = '/intro';

  /// Display-name setup (shown after intro on fresh install).
  static const String displayNameSetup = '/setup/display-name';

  /// Initialization screen (shown after display-name setup).
  static const String initializing = '/setup/initializing';

  /// Legacy splash screen; kept for backward compatibility.
  @Deprecated('Use launch instead')
  static const String splash = '/splash';

  /// First-run identity creation (legacy, superseded by intro + displayName).
  @Deprecated('Use intro + displayNameSetup instead')
  static const String onboarding = '/onboarding';

  // Primary tabs ---------------------------------------------------------

  /// Channels tab (index 0).
  static const String channels = '/channels';

  /// Nodes tab (index 1).
  static const String nodes = '/nodes';

  /// Nearby tab (index 2).
  static const String nearby = '/nearby';

  /// Mesh tab (index 3).
  static const String mesh = '/mesh';

  /// Global settings (top-level route, not a shell tab).
  static const String settings = '/settings';

  // Channels area ----------------------------------------------------------

  /// Channel details (deep-linkable).
  static const String channel = '/channels/:channelId';

  /// Message anchor inside a channel (deep-linkable).
  static const String message = '/channels/:channelId/message/:messageId';

  /// New message composer for a channel.
  static const String composeMessage = '/channels/:channelId/compose';

  /// Message search.
  static const String search = '/search';

  /// Media area -------------------------------------------------------------

  /// Transfer progress (deep-linkable).
  static const String transfer = '/transfers/:sessionId';

  /// Shared media gallery.
  static const String mediaGallery = '/media';

  // Nodes area ---------------------------------------------------------------

  /// Node details (deep-linkable).
  static const String node = '/nodes/:nodeId';

  // Identity area -------------------------------------------------------------

  /// This node's identity overview.
  static const String identity = '/identity';

  /// This node's identity QR card.
  static const String qrIdentity = '/qr-identity';

  /// QR scanner.
  static const String qrScanner = '/qr-scan';

  /// Unified QR hub (identity + scan).
  static const String qr = '/qr';

  // Mesh area ------------------------------------------------------------------

  /// Routing table inspector.
  static const String routeInspector = '/mesh/routes';

  // Settings area -----------------------------------------------------------------

  static const String appearance = '/settings/appearance';
  static const String privacy = '/settings/privacy';
  static const String storage = '/settings/storage';
  static const String notifications = '/settings/notifications';
  static const String bluetooth = '/settings/bluetooth';

  // Developer area (gated until developer mode is unlocked) --------------------

  static const String developer = '/developer';
  static const String diagnostics = '/developer/diagnostics';
  static const String logs = '/developer/logs';
  static const String databaseViewer = '/developer/database';
  static const String statistics = '/developer/statistics';
  static const String performance = '/developer/performance';

  // About area ----------------------------------------------------------------------

  static const String about = '/settings/about';
  static const String licenses = '/settings/licenses';

  /// Legacy home console path; resolves to the first tab.
  static const String home = '/';

  /// Developer testing screen for the Bluetooth transport (Phase 4).
  static const String bluetoothDebug = '/bluetooth-debug';

  /// Developer dashboard for the mesh engine (Phase 5).
  static const String meshDebug = '/mesh-debug';

  /// Developer dashboard for the packet protocol engine (Phase 6).
  static const String packetDebug = '/packet-debug';

  /// Developer dashboard for the DTN store-and-forward layer (Phase 7).
  static const String dtnDebug = '/dtn-debug';

  // Deep-link builders -----------------------------------------------------------

  /// Concrete location for a channel deep link.
  static String channelOf(String channelId) => '/channels/$channelId';

  /// Concrete location for a message deep link inside a channel.
  static String messageOf(String channelId, String messageId) =>
      '/channels/$channelId/message/$messageId';

  /// Concrete location for the composer of [channelId].
  static String composeOf(String channelId) => '/channels/$channelId/compose';

  /// Concrete location for a node deep link.
  static String nodeOf(String nodeId) => '/nodes/$nodeId';

  /// Concrete location for a transfer deep link.
  static String transferOf(String sessionId) => '/transfers/$sessionId';

  /// The paths that only resolve once developer mode is enabled.
  static const List<String> developerGatedPaths = [
    developer,
    diagnostics,
    logs,
    databaseViewer,
    statistics,
    performance,
    bluetoothDebug,
    meshDebug,
    packetDebug,
    dtnDebug,
  ];

  const AppRoutePaths._();
}

/// Path segment names of parameterized routes.
///
/// Identifiers mirror the domain models (`Channel.channelId`,
/// `MeshNode.nodeId`, `TransferSession.sessionId`, `Message.messageId`) so
/// deep links never invent unsupported backend identifiers.
abstract final class AppRouteParameters {
  static const String channelId = 'channelId';
  static const String messageId = 'messageId';
  static const String nodeId = 'nodeId';
  static const String sessionId = 'sessionId';

  const AppRouteParameters._();
}
