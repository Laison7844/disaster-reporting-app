import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class NetworkAudioPlayer extends StatefulWidget {
  const NetworkAudioPlayer({
    super.key,
    required this.audioUrl,
    this.label = 'Voice message attached',
    this.compact = false,
  });

  final String audioUrl;
  final String label;
  final bool compact;

  @override
  State<NetworkAudioPlayer> createState() => _NetworkAudioPlayerState();
}

class _NetworkAudioPlayerState extends State<NetworkAudioPlayer> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  PlayerState _playerState = PlayerState.stopped;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playerState = state;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    try {
      if (_playerState == PlayerState.playing) {
        await _player.pause();
        return;
      }

      setState(() => _isLoading = true);
      await _player.play(UrlSource(widget.audioUrl));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play audio attachment.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;

    if (widget.compact) {
      return Row(
        children: [
          const Icon(Icons.mic),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.label)),
          IconButton(
            onPressed: _isLoading ? null : _togglePlayback,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
          ),
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.mic),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.label)),
            FilledButton.icon(
              onPressed: _isLoading ? null : _togglePlayback,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_arrow,
                    ),
              label: Text(isPlaying ? 'Pause Audio' : 'Play Audio'),
            ),
          ],
        ),
      ),
    );
  }
}
