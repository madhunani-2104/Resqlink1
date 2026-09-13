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

  LatLng _currentLocation = const LatLng(40.730610, -73.935242);
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
        'Failed to init location/map layers',
        e,
        null,
        'MapProvider',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMapLayers() async {
    try {
      final response = await _dioClient.instance.get(ApiEndpoints.mapLayers);
      final responseData = response.data;
      if (responseData is! Map<String, dynamic> ||
          responseData['success'] != true ||
          responseData['data'] is! Map<String, dynamic>) {
        throw StateError('Map layers API returned an invalid response');
      }

      final data = responseData['data'] as Map<String, dynamic>;
      _safeZones = _parseSafeZones(data['safeZones']);
      _shelters = _parseShelters(data['shelters']);
      _victims = _parseVictims(data['victims']);
      notifyListeners();
    } catch (e) {
      AppLogger.error(
        'Failed to load map layers from API',
        e,
        null,
        'MapProvider',
      );
    }
  }

  List<SafeZoneModel> _parseSafeZones(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((item) {
          return SafeZoneModel.fromJson(item);
        })
        .where(_hasValidSafeZoneCoordinates)
        .toList();
  }

  List<ShelterModel> _parseShelters(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((item) {
          return ShelterModel.fromJson(item);
        })
        .where(_hasValidShelterCoordinates)
        .toList();
  }

  List<SosModel> _parseVictims(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map<String, dynamic>>().map((item) {
      return SosModel.fromJson(item);
    }).toList();
  }

  bool _hasValidSafeZoneCoordinates(SafeZoneModel zone) {
    return _hasValidCoordinates(zone.latitude, zone.longitude);
  }

  bool _hasValidShelterCoordinates(ShelterModel shelter) {
    return _hasValidCoordinates(shelter.latitude, shelter.longitude);
  }

  bool _hasValidCoordinates(double latitude, double longitude) {
    return latitude != 0 &&
        longitude != 0 &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
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
