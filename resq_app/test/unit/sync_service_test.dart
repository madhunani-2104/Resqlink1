import 'package:flutter_test/flutter_test.dart';
import 'package:resq_app/core/utils/distance_calculator.dart';

void main() {
  group('DistanceCalculator Unit Tests', () {
    test('Calculates distance in meters between two coordinates', () {
      // Distance between two points ~ 1km apart
      final double distance = DistanceCalculator.calculateDistanceMeters(
        40.730610, -73.935242,
        40.739610, -73.935242,
      );

      expect(distance, greaterThan(900));
      expect(distance, lessThan(1100));
    });

    test('Formats distance text correctly', () {
      expect(DistanceCalculator.formatDistance(450), '450 m');
      expect(DistanceCalculator.formatDistance(2500), '2.5 km');
    });
  });
}
