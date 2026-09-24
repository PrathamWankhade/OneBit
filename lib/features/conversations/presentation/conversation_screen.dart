import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onebit/app/app.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/conversations/presentation/attachment_sheet.dart';
import 'package:onebit/features/conversations/presentation/message_bubble.dart';
import 'package:onebit/features/conversations/presentation/voice_recording_widget.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/conversations/providers/conversation_providers.dart';
import 'package:onebit/features/reliable/transfer.dart';
import 'package:onebit/features/ui/components/components.dart';
import 'package:url_launcher/url_launcher.dart';

enum _ChatMenuAction {
  viewContact,
  search,
  media,
  mute,
  disappearing,
  theme,
  more,
}

/// F4 — One-to-one conversation screen.
///
/// Shows message timeline, header with peer status, and composer.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.conversationId, super.key});

  final int conversationId;

  @override
  ConsumerState<ConversationScreen> createState() =>
      _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isRecording = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final db = ref.read(databaseProvider);
    final transport = ref.read(messageTransportProvider);

    final conversation = await db.getConversation(widget.conversationId);

    if (conversation != null && conversation.peerDeviceId != null) {
      final result = await transport.sendMessage(
        peerDeviceId: conversation.peerDeviceId!,
        conversationId: widget.conversationId,
        content: text,
      );

      if (!mounted) return;
      if (result != TransferResult.delivered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } else {
      await db.insertMessage(
        conversationId: widget.conversationId,
        content: text,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _showAttachmentMenu() async {
    final type = await showAttachmentSheet(context);
    if (type == null || !mounted) return;

    switch (type) {
      case AttachmentType.camera:
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.camera);
        if (image != null && mounted) {
          await _sendFileMessage(File(image.path), 'image');
        }
      case AttachmentType.gallery:
        final picker = ImagePicker();
        final images = await picker.pickMultiImage();
        if (images.isNotEmpty && mounted) {
          for (final image in images) {
            await _sendFileMessage(File(image.path), 'image');
          }
        }
      case AttachmentType.document:
        await _showDocumentPicker();
      case AttachmentType.location:
        await _showLocationPicker();
      case AttachmentType.contact:
        await _showContactPicker();
      case AttachmentType.poll:
        await _showPollCreator();
    }
  }

  Future<void> _showDocumentPicker() async {
    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DocumentPickerSheet(),
    );

    if (result != null && mounted) {
      await _sendFileMessage(File(result), 'file');
    }
  }

  Future<void> _showLocationPicker() async {
    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _LocationPickerSheet(),
    );

    if (result != null && mounted) {
      await _sendFileMessage(File(result), 'location');
    }
  }

  Future<void> _showContactPicker() async {
    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ContactPickerSheet(),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await _sendFileMessage(File(result), 'contact');
    }
  }

  Future<void> _showPollCreator() async {
    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PollCreatorSheet(),
    );

    if (result != null && mounted) {
      await _sendFileMessage(File(result), 'poll');
    }
  }

  Future<void> _sendFileMessage(File file, String type) async {
    final db = ref.read(databaseProvider);
    final transport = ref.read(messageTransportProvider);

    final conversation = await db.getConversation(widget.conversationId);

    // Copy file to persistent app storage
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = file.path.split('.').last;
    final savedFile = await file.copy('${appDir.path}/${type}_$timestamp.$ext');
    final savedName = savedFile.path.split('/').last;

    final content = '[$type:$savedName]';

    if (conversation != null && conversation.peerDeviceId != null) {
      final result = await transport.sendMessage(
        peerDeviceId: conversation.peerDeviceId!,
        conversationId: widget.conversationId,
        content: content,
      );

      if (!mounted) return;
      if (result != TransferResult.delivered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send')),
        );
      }
    } else {
      await db.insertMessage(
        conversationId: widget.conversationId,
        content: content,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversationAsync =
        ref.watch(conversationProvider(widget.conversationId));
    final messagesAsync =
        ref.watch(messagesProvider(widget.conversationId));

    return Scaffold(
      appBar: _ChatHeader(
        conversationAsync: conversationAsync,
        conversationId: widget.conversationId,
      ),
      body: conversationAsync.when(
        loading: () => const ChatSkeleton(),
        error: (e, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load conversation.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
        data: (conversation) {
          if (conversation == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Conversation not found.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  loading: () => const ChatSkeleton(),
                  error: (e, st) => Center(child: Text('Error: $e')),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return _EmptyConversation(
                        peerName: conversation.title,
                      );
                    }
                    return _MessageList(
                      messages: messages,
                      scrollController: _scrollController,
                    );
                  },
                ),
              ),
              if (_isRecording)
                VoiceRecordingWidget(
                  onCancel: () => setState(() => _isRecording = false),
                  onSend: (duration) {
                    setState(() => _isRecording = false);
                    // TODO: Send voice message with duration
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Voice message (${duration.inSeconds}s) ready to send'),
                      ),
                    );
                  },
                )
              else
                _Composer(
                  controller: _controller,
                  onSend: _send,
                  onStartRecording: () => setState(() => _isRecording = true),
                  onAttach: _showAttachmentMenu,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────

class _ChatHeader extends ConsumerWidget implements PreferredSizeWidget {
  const _ChatHeader({
    required this.conversationAsync,
    required this.conversationId,
  });

  final AsyncValue<dynamic> conversationAsync;
  final int conversationId;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conv = conversationAsync.valueOrNull;
    final title = conv?.title ?? 'Unknown';
    final peerDeviceId = conv?.peerDeviceId;

    String statusText;
    Color statusColor;

    if (peerDeviceId == null) {
      statusText = 'No peer connected';
      statusColor = AppTheme.textTertiary;
    } else {
      final bleService = ref.read(bleServiceProvider);
      final connInfo = bleService.current.connectionFor(peerDeviceId);
      final bleState = connInfo?.state ?? BleConnectionState.disconnected;

      switch (bleState) {
        case BleConnectionState.connected:
          statusText = 'Online';
          statusColor = AppTheme.trust;
        case BleConnectionState.connecting:
          statusText = 'Connecting...';
          statusColor = AppTheme.warning;
        case BleConnectionState.disconnecting:
          statusText = 'Disconnecting...';
          statusColor = AppTheme.warning;
        case BleConnectionState.disconnected:
          statusText = 'Offline';
          statusColor = AppTheme.textTertiary;
        case BleConnectionState.error:
          statusText = 'Connection error';
          statusColor = AppTheme.danger;
      }
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 24, color: AppTheme.textSecondary),
        onPressed: () => context.pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppTheme.bgElevated,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 10,
                      color: AppTheme.trust.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      statusText,
                      style: AppTheme.caption.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
        actions: [
        PopupMenuButton<_ChatMenuAction>(
          icon: const Icon(Icons.more_vert, size: 24, color: AppTheme.textSecondary),
          color: AppTheme.bgElevated,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.borderDefault, width: 0.5),
          ),
          onSelected: (action) => _handleMenuAction(context, action, conversationId),
          itemBuilder: (context) => [
            _buildMenuItem(
              icon: Icons.person_outline,
              label: 'View contact',
              action: _ChatMenuAction.viewContact,
            ),
            _buildMenuItem(
              icon: Icons.search,
              label: 'Search',
              action: _ChatMenuAction.search,
            ),
            _buildMenuItem(
              icon: Icons.photo_library_outlined,
              label: 'Media, links, and docs',
              action: _ChatMenuAction.media,
            ),
            _buildMenuItem(
              icon: Icons.notifications_off_outlined,
              label: 'Mute notifications',
              action: _ChatMenuAction.mute,
            ),
            _buildMenuItem(
              icon: Icons.timer_outlined,
              label: 'Disappearing messages',
              action: _ChatMenuAction.disappearing,
            ),
            _buildMenuItem(
              icon: Icons.palette_outlined,
              label: 'Chat theme',
              action: _ChatMenuAction.theme,
            ),
            _buildMenuItem(
              icon: Icons.more_horiz,
              label: 'More',
              action: _ChatMenuAction.more,
            ),
          ],
        ),
      ],
    );
  }

  void _handleMenuAction(
    BuildContext context,
    _ChatMenuAction action,
    int conversationId,
  ) {
    switch (action) {
      case _ChatMenuAction.viewContact:
        break;
      case _ChatMenuAction.search:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search coming soon')),
        );
      case _ChatMenuAction.media:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media gallery coming soon')),
        );
      case _ChatMenuAction.mute:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mute toggled')),
        );
      case _ChatMenuAction.disappearing:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disappearing messages coming soon')),
        );
      case _ChatMenuAction.theme:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat theme coming soon')),
        );
      case _ChatMenuAction.more:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('More options coming soon')),
        );
    }
  }

  PopupMenuItem<_ChatMenuAction> _buildMenuItem({
    required IconData icon,
    required String label,
    required _ChatMenuAction action,
  }) {
    return PopupMenuItem<_ChatMenuAction>(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ── Message List ───────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.scrollController,
  });

  final List<dynamic> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isReceived = msg.status == 'received';

        final showDateDivider = index == 0 ||
            !_sameDay(
              messages[index - 1].createdAt as DateTime,
              msg.createdAt as DateTime,
            );

        return RepaintBoundary(
          child: Column(
            children: [
              if (showDateDivider)
                DateDivider(date: msg.createdAt as DateTime),
              GestureDetector(
                onLongPress: () => _showMessageActions(context, msg),
                child: _buildMessageWidget(msg, isReceived),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMessageWidget(dynamic msg, bool isReceived) {
    final content = msg.content as String;
    final timestamp = msg.createdAt as DateTime;
    final status = isReceived ? '' : (msg.status as String? ?? 'sent');

    if (content.startsWith('[image:') && content.endsWith(']')) {
      final fileName = content.substring(7, content.length - 1);
      return _ImageMessage(
        fileName: fileName,
        timestamp: timestamp,
        isReceived: isReceived,
        status: status,
      );
    }

    if (content.startsWith('[file:') && content.endsWith(']')) {
      final fileName = content.substring(6, content.length - 1);
      return _FileMessage(
        fileName: fileName,
        timestamp: timestamp,
        isReceived: isReceived,
        status: status,
      );
    }

    if (content.startsWith('[location:') && content.endsWith(']')) {
      final locationData = content.substring(10, content.length - 1);
      return _LocationMessage(
        locationData: locationData,
        timestamp: timestamp,
        isReceived: isReceived,
        status: status,
      );
    }

    if (content.startsWith('[contact:') && content.endsWith(']')) {
      final contactName = content.substring(9, content.length - 1);
      return _ContactMessage(
        contactName: contactName,
        timestamp: timestamp,
        isReceived: isReceived,
        status: status,
      );
    }

    if (content.startsWith('[poll:') && content.endsWith(']')) {
      final pollData = content.substring(6, content.length - 1);
      return _PollMessage(
        pollData: pollData,
        timestamp: timestamp,
        isReceived: isReceived,
        status: status,
      );
    }

    return MessageBubble(
      content: content,
      timestamp: timestamp,
      isReceived: isReceived,
      status: status,
    );
  }

  void _showMessageActions(BuildContext context, dynamic msg) async {
    final isOwnMessage = msg.status != 'received';
    final action = await showMessageActions(
      context,
      isOwnMessage: isOwnMessage,
      canEdit: isOwnMessage,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case MessageActionType.copy:
        showCopySnackbar(context);
      case MessageActionType.delete:
        showDeleteSnackbar(context);
      default:
        break;
    }
  }
}

// ── Empty Conversation ─────────────────────────────────────────────

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.peerName});

  final String peerName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.accentMuted,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 28,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            'Start a conversation with $peerName',
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.space8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.trustMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 12, color: AppTheme.trust),
                SizedBox(width: 4),
                Text(
                  'End-to-end encrypted',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Composer ───────────────────────────────────────────────────────

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    this.onStartRecording,
    this.onAttach,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onStartRecording;
  final VoidCallback? onAttach;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        top: 4,
        bottom: MediaQuery.of(context).padding.bottom + 4,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgBase,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Emoji button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(bottom: 2),
              child: const Icon(
                Icons.sentiment_satisfied_alt_outlined,
                size: 24,
                color: AppTheme.textSecondary,
              ),
            ),
          ),

          // Text field with rounded border
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.borderDefault,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      onSubmitted: (_) => widget.onSend(),
                    ),
                  ),

                  // Paperclip / attachment
                  GestureDetector(
                    onTap: widget.onAttach,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.attach_file,
                        size: 22,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),

                  // Camera
                  GestureDetector(
                    onTap: () {},
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 22,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Mic / Send button (larger, accent colored)
          GestureDetector(
            onTap: _hasText ? widget.onSend : widget.onStartRecording,
            child: Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(bottom: 0),
              decoration: BoxDecoration(
                color: _hasText ? AppTheme.accent : AppTheme.bgElevated,
                shape: BoxShape.circle,
                border: _hasText
                    ? null
                    : Border.all(color: AppTheme.borderDefault, width: 0.5),
              ),
              child: Icon(
                _hasText ? Icons.send_rounded : Icons.mic,
                size: 20,
                color: _hasText ? AppTheme.bgBase : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Specialized Message Widgets ──────────────────────────────────────

class _ImageMessage extends StatefulWidget {
  const _ImageMessage({
    required this.fileName,
    required this.timestamp,
    required this.isReceived,
    required this.status,
  });

  final String fileName;
  final DateTime timestamp;
  final bool isReceived;
  final String status;

  @override
  State<_ImageMessage> createState() => _ImageMessageState();
}

class _ImageMessageState extends State<_ImageMessage> {
  late final Future<File?> _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = _resolveImage();
  }

  Future<File?> _resolveImage() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/${widget.fileName}');
    if (await file.exists()) return file;

    final files = await appDir.list().toList();
    for (final f in files) {
      if (f is File && f.path.endsWith(widget.fileName)) return f;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: widget.isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(widget.isReceived ? 4 : 12),
                  bottomRight: Radius.circular(widget.isReceived ? 12 : 4),
                ),
              ),
              child: FutureBuilder<File?>(
                future: _fileFuture,
                builder: (context, snapshot) {
                  final file = snapshot.data;
                  if (file != null) {
                    return Image.file(
                      file,
                      width: 250,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => _placeholder(),
                    );
                  }
                  return _placeholder();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.timestamp.hour.toString().padLeft(2, '0')}:${widget.timestamp.minute.toString().padLeft(2, '0')}',
                    style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                  ),
                  if (!widget.isReceived) ...[
                    const SizedBox(width: 4),
                    Icon(
                      widget.status == 'read' ? Icons.done_all : Icons.done,
                      size: 12,
                      color: widget.status == 'read' ? AppTheme.accent : AppTheme.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 200,
      width: 250,
      color: AppTheme.bgElevated,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 48, color: AppTheme.textTertiary),
      ),
    );
  }
}

class _FileMessage extends StatelessWidget {
  const _FileMessage({
    required this.fileName,
    required this.timestamp,
    required this.isReceived,
    required this.status,
  });

  final String fileName;
  final DateTime timestamp;
  final bool isReceived;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isReceived ? AppTheme.bgElevated : AppTheme.accentMuted,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isReceived ? 4 : 12),
                  bottomRight: Radius.circular(isReceived ? 12 : 4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.description,
                      size: 22,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName.length > 25 ? '${fileName.substring(0, 25)}...' : fileName,
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Document',
                          style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                  ),
                  if (!isReceived) ...[
                    const SizedBox(width: 4),
                    Icon(
                      status == 'read' ? Icons.done_all : Icons.done,
                      size: 12,
                      color: status == 'read' ? AppTheme.accent : AppTheme.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationMessage extends StatelessWidget {
  const _LocationMessage({
    required this.locationData,
    required this.timestamp,
    required this.isReceived,
    required this.status,
  });

  final String locationData;
  final DateTime timestamp;
  final bool isReceived;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isReceived ? AppTheme.bgElevated : AppTheme.accentMuted,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isReceived ? 4 : 12),
                  bottomRight: Radius.circular(isReceived ? 12 : 4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      size: 22,
                      color: AppTheme.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shared Location',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          locationData,
                          style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                  ),
                  if (!isReceived) ...[
                    const SizedBox(width: 4),
                    Icon(
                      status == 'read' ? Icons.done_all : Icons.done,
                      size: 12,
                      color: status == 'read' ? AppTheme.accent : AppTheme.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactMessage extends StatelessWidget {
  const _ContactMessage({
    required this.contactName,
    required this.timestamp,
    required this.isReceived,
    required this.status,
  });

  final String contactName;
  final DateTime timestamp;
  final bool isReceived;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isReceived ? AppTheme.bgElevated : AppTheme.accentMuted,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isReceived ? 4 : 12),
                  bottomRight: Radius.circular(isReceived ? 12 : 4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 22,
                      color: AppTheme.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contactName,
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Contact',
                          style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                  ),
                  if (!isReceived) ...[
                    const SizedBox(width: 4),
                    Icon(
                      status == 'read' ? Icons.done_all : Icons.done,
                      size: 12,
                      color: status == 'read' ? AppTheme.accent : AppTheme.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollMessage extends StatelessWidget {
  const _PollMessage({
    required this.pollData,
    required this.timestamp,
    required this.isReceived,
    required this.status,
  });

  final String pollData;
  final DateTime timestamp;
  final bool isReceived;
  final String status;

  @override
  Widget build(BuildContext context) {
    final parts = pollData.split('|');
    final question = parts.isNotEmpty ? parts[0] : 'Poll';
    final options = parts.length > 1 ? parts.sublist(1) : ['Option 1', 'Option 2'];

    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isReceived ? AppTheme.bgElevated : AppTheme.accentMuted,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isReceived ? 4 : 12),
                  bottomRight: Radius.circular(isReceived ? 12 : 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.poll, size: 16, color: AppTheme.amber),
                      const SizedBox(width: 6),
                      Text(
                        'Poll',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question,
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  ...options.map((option) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgOverlay,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderDefault, width: 0.5),
                    ),
                    child: Text(
                      option,
                      style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                    ),
                  )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                  ),
                  if (!isReceived) ...[
                    const SizedBox(width: 4),
                    Icon(
                      status == 'read' ? Icons.done_all : Icons.done,
                      size: 12,
                      color: status == 'read' ? AppTheme.accent : AppTheme.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Picker Sheets ──────────────────────────────────────────────────

class _DocumentPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: AppTheme.blue),
              title: const Text('Browse files'),
              onTap: () {
                Navigator.pop(context, 'document');
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: AppTheme.green),
              title: const Text('Audio file'),
              onTap: () {
                Navigator.pop(context, 'audio');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LocationPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: AppTheme.green),
              title: const Text('Share current location'),
              subtitle: Text(
                'Opens your maps app',
                style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
              ),
              onTap: () async {
                final uri = Uri.parse('https://www.google.com/maps');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (context.mounted) {
                  Navigator.pop(context, 'Current Location (via Maps)');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: AppTheme.accent),
              title: const Text('Choose on map'),
              subtitle: Text(
                'Pick a location in maps',
                style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
              ),
              onTap: () async {
                final uri = Uri.parse('https://www.google.com/maps/search/locations');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (context.mounted) {
                  Navigator.pop(context, 'Selected Location (via Maps)');
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ContactPickerSheet extends StatefulWidget {
  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.bgMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Share Contact',
                style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Contact name',
                  hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.textSecondary),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Phone number (optional)',
                  hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.textSecondary),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isNotEmpty) {
                      Navigator.pop(context, name);
                    }
                  },
                  child: const Text('Share Contact'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollCreatorSheet extends StatefulWidget {
  @override
  State<_PollCreatorSheet> createState() => _PollCreatorSheetState();
}

class _PollCreatorSheetState extends State<_PollCreatorSheet> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 6) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Create Poll',
                  style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _questionController,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ask a question',
                    hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
                    prefixIcon: const Icon(Icons.help_outline, color: AppTheme.textSecondary),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                ...List.generate(_optionControllers.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[i],
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Option ${i + 1}',
                            hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: AppTheme.textTertiary),
                          onPressed: () => _removeOption(i),
                        ),
                    ],
                  ),
                )),
                if (_optionControllers.length < 6)
                  TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Add option', style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final question = _questionController.text.trim();
                      final options = _optionControllers
                          .map((c) => c.text.trim())
                          .where((t) => t.isNotEmpty)
                          .toList();
                      if (question.isNotEmpty && options.length >= 2) {
                        Navigator.pop(context, '$question|${options.join('|')}');
                      }
                    },
                    child: const Text('Create Poll'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
