import 'package:geolocator/geolocator.dart';
import '../utils/logger.dart';

class LocationService {
  /// Request GPS permissions and fetch the device's current position.
  /// Returns null when location services/permissions are unavailable instead
  /// of fabricating coordinates.
  static Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning(
          'Location services are disabled on device.',
          'LocationService',
        );
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        AppLogger.warning(
          'Location permission was denied.',
          'LocationService',
        );
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.warning(
          'Location permission is permanently denied.',
          'LocationService',
        );
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );
    } on LocationServiceDisabledException {
      AppLogger.warning(
        'Location services became unavailable while reading GPS.',
        'LocationService',
      );
      return null;
    } on PermissionDeniedException {
      AppLogger.warning(
        'Location permission was denied while reading GPS.',
        'LocationService',
      );
      return null;
    } catch (e) {
      AppLogger.error(
        'Error fetching current GPS position',
        e,
        null,
        'LocationService',
      );
      return null;
    }
  }
}
