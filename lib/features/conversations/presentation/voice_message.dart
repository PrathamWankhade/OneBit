import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';

/// A voice note in the thread: tap to hear what arrived.
///
/// The player is created only once the file resolves — a note whose
/// bytes never arrived renders as an honest placeholder, never a
/// dead play button.
class VoiceMessage extends StatefulWidget {
  const VoiceMessage({
    required this.fileName,
    required this.timestamp,
    required this.isReceived,
    required this.status,
    this.durationMs = 0,
    this.directoryProvider,
    super.key,
  });

  final String fileName;
  final DateTime timestamp;
  final bool isReceived;
  final String status;

  /// Recorded length from the manifest. The player reports the truer
  /// number once it loads; this covers the moment before it does.
  final int durationMs;

  /// Where voice files live. Overridable in tests, where the platform
  /// plugin has nothing to answer with.
  final Future<Directory> Function()? directoryProvider;

  @override
  State<VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<VoiceMessage> {
  Future<File?>? _fileFuture;
  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSub;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _loadedDuration;

  @override
  void initState() {
    super.initState();
    _fileFuture = _resolveFile();
  }

  @override
  void didUpdateWidget(VoiceMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileName != widget.fileName) {
      _stopPlayer();
      setState(() => _fileFuture = _resolveFile());
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<File?> _resolveFile() async {
    final provider = widget.directoryProvider;
    final appDir = provider != null
        ? await provider()
        : await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/${widget.fileName}');
    return file.existsSync() ? file : null;
  }

  Future<void> _toggle(File file) async {
    if (_playing) {
      await _player?.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }

    final player = _player ??= AudioPlayer();
    try {
      if (_loadedDuration == null) {
        final duration = await player.setFilePath(file.path);
        if (mounted) setState(() => _loadedDuration = duration);
      }
      _positionSub ??=
          player.positionStream.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
        if (_loadedDuration != null &&
            position >= _loadedDuration! &&
            _loadedDuration! > Duration.zero) {
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
          player.seek(Duration.zero);
          player.pause();
        }
      });
      await player.play();
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play this voice note')),
        );
      }
    }
  }

  Future<void> _stopPlayer() async {
    await _positionSub?.cancel();
    _positionSub = null;
    await _player?.dispose();
    _player = null;
    _playing = false;
    _position = Duration.zero;
    _loadedDuration = null;
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          widget.isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: widget.isReceived
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isReceived
                    ? AppTheme.bgElevated
                    : AppTheme.accentMuted,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft:
                      Radius.circular(widget.isReceived ? 4 : 12),
                  bottomRight:
                      Radius.circular(widget.isReceived ? 12 : 4),
                ),
              ),
              child: FutureBuilder<File?>(
                future: _fileFuture,
                builder: (context, snapshot) {
                  final file = snapshot.data;
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      width: 180,
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (file == null) {
                    return const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic_off_outlined,
                          size: 20,
                          color: AppTheme.textTertiary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Voice note unavailable',
                          style: AppTheme.caption,
                        ),
                      ],
                    );
                  }

                  final total =
                      _loadedDuration ?? Duration(milliseconds: widget.durationMs);
                  final progress = total.inMilliseconds > 0
                      ? (_position.inMilliseconds / total.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _toggle(file),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _playing ? Icons.pause : Icons.play_arrow,
                            size: 20,
                            color: AppTheme.bgBase,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 140,
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: AppTheme.divider,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_format(_position)} / ${_format(total)}',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
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
                    style:
                        AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                  ),
                  if (!widget.isReceived) ...[
                    const SizedBox(width: 4),
                    Icon(
                      widget.status == 'read' ? Icons.done_all : Icons.done,
                      size: 12,
                      color: widget.status == 'read'
                          ? AppTheme.accent
                          : AppTheme.textTertiary,
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
