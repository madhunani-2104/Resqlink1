import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_models.dart';
import '../../sos/models/sos_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/logger.dart';

class MapProvider extends ChangeNotifier {
  final DioClient _dioClient = DioClient();

  LatLng _currentLocation = const LatLng(0.0, 0.0);
  List<SafeZoneModel> _safeZones = [];
  List<ShelterModel> _shelters = [];
  List<SosModel> _victims = [];
  bool _isLoading = false;

  bool _showSafeZones = true;
  bool _showShelters = true;
  bool _showVictims = true;

  LatLng get currentLocation => _currentLocation;
  List<SafeZoneModel> get safeZones => _showSafeZones ? _safeZones : [];
  List<ShelterModel> get shelters => _showShelters ? _shelters : [];
  List<SosModel> get victims => _showVictims ? _victims : [];
  bool get isLoading => _isLoading;

  bool get showSafeZones => _showSafeZones;
  bool get showShelters => _showShelters;
  bool get showVictims => _showVictims;

  MapProvider() {
    initLocationAndLayers();
  }

  Future<void> initLocationAndLayers() async {
    await refreshLocationAndLayers();
  }

  Future<void> refreshLocationAndLayers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      }

      await fetchMapLayers();
    } catch (e) {
      AppLogger.error(
        'Failed to refresh location and map layers',
        e,
        null,
        'MapProvider',
      );
      _safeZones = [];
      _shelters = [];
      _victims = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMapLayers() async {
    try {
      final response = await _dioClient.instance.get(ApiEndpoints.mapLayers);
      if (response.data['success'] == true) {
        final data = response.data['data'];
        _safeZones = (data['safeZones'] as List? ?? [])
            .map((item) => SafeZoneModel.fromJson(item))
            .toList();
        _shelters = (data['shelters'] as List? ?? [])
            .map((item) => ShelterModel.fromJson(item))
            .toList();
        _victims = (data['victims'] as List? ?? [])
            .map((item) => SosModel.fromJson(item))
            .toList();
      } else {
        _safeZones = [];
        _shelters = [];
        _victims = [];
      }
    } catch (e) {
      AppLogger.warning(
        'Map layers API unavailable; using live GPS without fabricated map data',
        'MapProvider',
      );
      _safeZones = [];
      _shelters = [];
      _victims = [];
    }
  }

  void toggleSafeZones(bool val) {
    _showSafeZones = val;
    notifyListeners();
  }

  void toggleShelters(bool val) {
    _showShelters = val;
    notifyListeners();
  }

  void toggleVictims(bool val) {
    _showVictims = val;
    notifyListeners();
  }
}
