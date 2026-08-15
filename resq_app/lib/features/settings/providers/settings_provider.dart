import 'package:flutter/material.dart';
import '../../../core/services/preference_service.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  bool _meshEnabled = true;

  bool get isDarkMode => _isDarkMode;
  bool get meshEnabled => _meshEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _isDarkMode = await PreferenceService.isDarkMode();
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool val) async {
    _isDarkMode = val;
    await PreferenceService.setDarkMode(val);
    notifyListeners();
  }

  void toggleMeshEnabled(bool val) {
    _meshEnabled = val;
    notifyListeners();
  }
}
