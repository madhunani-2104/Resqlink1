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
      AppLogger.error('Failed to init location/map layers', e, null, 'MapProvider');
      _loadDummyOfflineData();
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
        _safeZones = (data['safeZones'] as List)
            .map((item) => SafeZoneModel.fromJson(item))
            .toList();
        _shelters = (data['shelters'] as List)
            .map((item) => ShelterModel.fromJson(item))
            .toList();
        _victims = (data['victims'] as List)
            .map((item) => SosModel.fromJson(item))
            .toList();
      }
    } catch (e) {
      AppLogger.warning('Map layers API unavailable, loading offline GIS layers', 'MapProvider');
      _loadDummyOfflineData();
    }
  }

  void _loadDummyOfflineData() {
    _safeZones = [
      SafeZoneModel(
        id: 'SZ-101',
        name: 'Central Assembly Safe Haven',
        description: 'High ground assembly area with medical personnel',
        latitude: _currentLocation.latitude + 0.005,
        longitude: _currentLocation.longitude + 0.005,
        radiusMeters: 400,
        status: 'OPEN',
      ),
      SafeZoneModel(
        id: 'SZ-102',
        name: 'East Stadium Safe Zone',
        description: 'Flood relief shelter and helipad',
        latitude: _currentLocation.latitude - 0.008,
        longitude: _currentLocation.longitude + 0.003,
        radiusMeters: 600,
        status: 'OPEN',
      ),
    ];

    _shelters = [
      ShelterModel(
        id: 'SH-201',
        name: 'St. Mary Disaster Relief Shelter',
        address: '124 Emergency Way, Sector 4',
        latitude: _currentLocation.latitude + 0.003,
        longitude: _currentLocation.longitude - 0.006,
        capacity: 350,
        currentOccupants: 120,
        amenities: ['Food', 'Water', 'Medical', 'Power Generators'],
      ),
      ShelterModel(
        id: 'SH-202',
        name: 'Civic Community Shelter',
        address: '89 North Ave',
        latitude: _currentLocation.latitude - 0.004,
        longitude: _currentLocation.longitude - 0.004,
        capacity: 200,
        currentOccupants: 180,
        amenities: ['Food', 'Beds', 'First Aid'],
      ),
    ];

    _victims = [
      SosModel(
        sosId: 'SOS-V1',
        userId: 'U1',
        userName: 'John Doe',
        userPhone: '+1987654321',
        latitude: _currentLocation.latitude + 0.002,
        longitude: _currentLocation.longitude + 0.002,
        severity: 'CRITICAL',
        status: 'ACTIVE',
        notes: 'Trapped in building ground floor due to rising water.',
      ),
    ];
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
