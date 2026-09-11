import 'dart:io';

Future<bool> voiceFileExists(String path) => File(path).exists();

Future<List<int>?> readVoiceFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  return bytes.isEmpty ? null : bytes;
}
