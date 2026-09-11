import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_file_storage.dart';

class VoiceRecordingService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();

  static Stream<Duration> get playbackPositionStream =>
      _player.onPositionChanged;

  static Stream<Duration> get playbackDurationStream =>
      _player.onDurationChanged;

  static Stream<void> get playbackCompleteStream => _player.onPlayerComplete;

  static bool _isRecording = false;
  static DateTime? _recordingStartedAt;

  static bool get isRecording => _isRecording;

  static Duration getCurrentRecordingDuration() {
    if (!_isRecording || _recordingStartedAt == null) {
      return Duration.zero;
    }

    return DateTime.now().difference(_recordingStartedAt!);
  }

  static Duration get recordingDuration {
    return getCurrentRecordingDuration();
  }

  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  // ============================================================
  // START RECORDING
  // ============================================================

  static Future<String?> startRecording() async {
    try {
      if (_isRecording) {
        return null;
      }

      final permission = await _recorder.hasPermission();

      if (!permission) {
        return null;
      }

      final directory = await getTemporaryDirectory();

      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final path = '${directory.path}/$fileName';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      _recordingStartedAt = DateTime.now();
      _isRecording = true;

      return path;
    } catch (e) {
      _isRecording = false;
      _recordingStartedAt = null;

      print('VOICE START ERROR: $e');

      return null;
    }
  }

  // ============================================================
  // STOP RECORDING
  // ============================================================

  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        return null;
      }

      final path = await _recorder.stop();

      _isRecording = false;
      _recordingStartedAt = null;

      if (path == null || path.isEmpty) {
        return null;
      }

      final bytes = await readVoiceFile(path);

      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      print('VOICE SAVED: $path');
      print('VOICE SIZE: ${bytes.length} bytes');

      return path;
    } catch (e) {
      _isRecording = false;
      _recordingStartedAt = null;

      print('VOICE STOP ERROR: $e');

      return null;
    }
  }

  // ============================================================
  // CREATE VOICE MESSAGE PAYLOAD
  //
  // duration is optional.
  //
  // ChatRoomScreen passes the duration captured by its timer.
  // SOS can call this without duration if necessary.
  // ============================================================

  static Future<String?> createVoiceMessagePayload(
    String path, {
    Duration? duration,
  }) async {
    try {
      final bytes = await readVoiceFile(path);

      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      final actualDuration = duration ?? Duration.zero;

      final payload = {
        'version': 1,
        'mimeType': 'audio/mp4',
        'fileName': _safeFileName(path),
        'durationMs': actualDuration.inMilliseconds,
        'audio': base64Encode(bytes),
      };

      final jsonString = jsonEncode(payload);

      return base64Encode(utf8.encode(jsonString));
    } catch (e) {
      print('VOICE PAYLOAD ERROR: $e');

      return null;
    }
  }

  // ============================================================
  // READ RAW BASE64
  // ============================================================

  static Future<String?> readRecordingBase64(String path) async {
    try {
      final bytes = await readVoiceFile(path);

      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      return base64Encode(bytes);
    } catch (e) {
      print('VOICE BASE64 ERROR: $e');

      return null;
    }
  }

  // ============================================================
  // PLAY VOICE PAYLOAD
  //
  // Supports:
  //
  // 1. New format:
  //    base64(JSON)
  //
  // 2. JSON containing base64 audio
  //
  // 3. Old raw audio base64
  // ============================================================

  static Future<bool> playBase64(String payload, {String? playbackId}) async {
    try {
      if (payload.trim().isEmpty) {
        return false;
      }

      Uint8List audioBytes;

      // ----------------------------------------------------------
      // Try new JSON payload
      // ----------------------------------------------------------

      try {
        final decodedJson = utf8.decode(
          base64Decode(payload),
          allowMalformed: true,
        );

        final data = jsonDecode(decodedJson);

        if (data is Map && data['audio'] != null) {
          audioBytes = base64Decode(data['audio'].toString());
        } else {
          audioBytes = base64Decode(payload);
        }
      } catch (_) {
        // --------------------------------------------------------
        // Backward compatibility with raw audio base64.
        // --------------------------------------------------------

        audioBytes = base64Decode(payload);
      }

      if (audioBytes.isEmpty) {
        return false;
      }

      await _player.stop();

      await _player.play(BytesSource(audioBytes, mimeType: 'audio/mp4'));

      return true;
    } catch (e) {
      print('VOICE PLAY ERROR: $e');

      return false;
    }
  }

  // ============================================================
  // PLAY LOCAL FILE
  // ============================================================

  static Future<bool> playFile(String path) async {
    try {
      if (!await voiceFileExists(path)) {
        return false;
      }

      await _player.stop();

      await _player.play(DeviceFileSource(path, mimeType: 'audio/mp4'));

      return true;
    } catch (e) {
      print('VOICE FILE PLAY ERROR: $e');

      return false;
    }
  }

  // ============================================================
  // STOP PLAYBACK
  // ============================================================

  static Future<void> stopPlayback() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  static Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}

    try {
      await _player.dispose();
    } catch (_) {}
  }

  static String _safeFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final candidate = normalized.split('/').last;
    final safe = candidate.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'voice_message.m4a' : safe;
  }
}
