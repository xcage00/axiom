import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../utilis/permission_helper.dart';

class VoiceRecorder extends StatefulWidget {
  final Function(File) onRecordingComplete;

  const VoiceRecorder({super.key, required this.onRecordingComplete});

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  late final StreamSubscription<void> _playbackCompletionSubscription;

  @override
  void initState() {
    super.initState();
    _playbackCompletionSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _playbackCompletionSubscription.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasMicrophonePermission =
          await PermissionHelper.requestMicrophonePermission();
      if (!hasMicrophonePermission || !mounted) return;

      final Directory appDir = await getTemporaryDirectory();
      final String filePath =
          '${appDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(const RecordConfig(), path: filePath);
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingPath = filePath;
      });
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });
      await _getDuration();
    } catch (_) {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _getDuration() async {
    if (_recordingPath != null) {
      await _player.setSource(DeviceFileSource(_recordingPath!));
      final duration = await _player.getDuration();
      if (mounted) {
        setState(() {
          _recordingDuration = duration ?? Duration.zero;
        });
      }
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;

    try {
      await _player.play(DeviceFileSource(_recordingPath!));
      if (mounted) setState(() => _isPlaying = true);
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _stopPlayback() async {
    await _player.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  void _sendRecording() {
    if (_recordingPath != null) {
      widget.onRecordingComplete(File(_recordingPath!));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Voice Message',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Duration display
          Text(
            '${_recordingDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_recordingDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Record button
              IconButton(
                icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 48),
                color: Colors.red,
                onPressed: _isRecording ? _stopRecording : _startRecording,
              ),

              // Play button
              if (_recordingPath != null && !_isRecording)
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.stop : Icons.play_arrow,
                    size: 48,
                  ),
                  color: AppColors.primary,
                  onPressed: _isPlaying ? _stopPlayback : _playRecording,
                ),

              // Send button
              if (_recordingPath != null && !_isRecording)
                IconButton(
                  icon: const Icon(Icons.send, size: 48),
                  color: AppColors.primary,
                  onPressed: _sendRecording,
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
