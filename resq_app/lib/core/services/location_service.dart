import 'package:geolocator/geolocator.dart';

import '../utils/logger.dart';

enum LocationRequestStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
}

class LocationService {
  /// Request GPS permissions and fetch the device's current position.
  /// Returns null when location services/permissions are unavailable instead
  /// of fabricating coordinates.
  static Future<({Position? position, LocationRequestStatus status})>
  getCurrentPositionWithStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning(
          'Location services are disabled on device.',
          'LocationService',
        );
        return (position: null, status: LocationRequestStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        AppLogger.warning('Location permission was denied.', 'LocationService');
        return (position: null, status: LocationRequestStatus.permissionDenied);
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.warning(
          'Location permission is permanently denied.',
          'LocationService',
        );
        return (
          position: null,
          status: LocationRequestStatus.permissionPermanentlyDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      return (position: position, status: LocationRequestStatus.success);
    } on LocationServiceDisabledException {
      AppLogger.warning(
        'Location services became unavailable while reading GPS.',
        'LocationService',
      );
      return (position: null, status: LocationRequestStatus.serviceDisabled);
    } on PermissionDeniedException {
      AppLogger.warning(
        'Location permission was denied while reading GPS.',
        'LocationService',
      );
      return (position: null, status: LocationRequestStatus.permissionDenied);
    } catch (e) {
      AppLogger.error(
        'Error fetching current GPS position',
        e,
        null,
        'LocationService',
      );
      return (position: null, status: LocationRequestStatus.unavailable);
    }
  }

  static Future<Position?> getCurrentPosition() async {
    final result = await getCurrentPositionWithStatus();
    return result.position;
  }
}
