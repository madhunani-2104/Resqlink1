/// Offline, explainable emergency prioritization heuristic.
/// This is an application-level priority estimate, not a medically or
/// scientifically validated emergency prediction model.
class RiskPrediction {
  final String riskLevel;
  final double riskScore;
  final String reason;

  const RiskPrediction({
    required this.riskLevel,
    required this.riskScore,
    required this.reason,
  });
}

class RiskPredictor {
  static const double mediumThreshold = 40;
  static const double highThreshold = 70;

  static const List<String> _highTerms = [
    'fire', 'accident', 'unconscious', 'bleeding', 'severe', 'critical',
    'trapped', 'attack', 'assault', 'danger', 'urgent', 'ambulance',
    'heart', 'breathing', 'injury', 'injured', 'explosion', 'faint',
  ];

  static const List<String> _mediumTerms = [
    'help', 'lost', 'stuck', 'threat', 'fall', 'minor injury', 'stranded',
    'unsafe', 'emergency',
  ];

  static const List<String> _lowTerms = [
    'test', 'false alarm', 'safe', 'resolved', 'minor', 'okay',
  ];

  static RiskPrediction predict({
    required String severity,
    required String notes,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) {
    var score = 20.0;
    final reasons = <String>['Base emergency priority applied to an SOS event.'];

    final validCoordinates = latitude >= -90 && latitude <= 90 &&
        longitude >= -180 && longitude <= 180;
    if (validCoordinates) {
      score += 10;
      reasons.add('Valid GPS coordinates are available.');
    } else {
      reasons.add('GPS coordinates are unavailable or invalid.');
    }

    if (accuracy >= 0) {
      if (accuracy <= 20) {
        score += 10;
        reasons.add('GPS accuracy is high (20 m or better).');
      } else if (accuracy <= 100) {
        score += 6;
        reasons.add('GPS accuracy is usable (100 m or better).');
      } else {
        score += 2;
        reasons.add('GPS accuracy is low (over 100 m).');
      }
    }

    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        score += 15;
        reasons.add('Existing SOS severity is CRITICAL.');
        break;
      case 'HIGH':
        score += 10;
        reasons.add('Existing SOS severity is HIGH.');
        break;
      case 'MEDIUM':
        score += 5;
        reasons.add('Existing SOS severity is MEDIUM.');
        break;
      case 'LOW':
        score -= 5;
        reasons.add('Existing SOS severity is LOW.');
        break;
    }

    final text = notes.toLowerCase();
    final highMatches = _highTerms.where(text.contains).take(3).toList();
    final mediumMatches = _mediumTerms.where(text.contains).take(3).toList();
    final lowMatches = _lowTerms.where(text.contains).take(3).toList();

    if (highMatches.isNotEmpty) {
      score += 55;
      reasons.add('High-severity emergency wording: ${highMatches.join(', ')}.');
    } else if (mediumMatches.isNotEmpty) {
      score += 25;
      reasons.add('Moderate emergency wording: ${mediumMatches.join(', ')}.');
    } else if (lowMatches.isNotEmpty) {
      score -= 15;
      reasons.add('Lower-priority wording: ${lowMatches.join(', ')}.');
    } else {
      reasons.add('No additional severity keywords were provided.');
    }

    score = score.clamp(0, 100).toDouble();
    final level = score >= highThreshold
        ? 'HIGH'
        : score >= mediumThreshold
            ? 'MEDIUM'
            : 'LOW';

    return RiskPrediction(
      riskLevel: level,
      riskScore: score,
      reason: reasons.join(' '),
    );
  }
}
