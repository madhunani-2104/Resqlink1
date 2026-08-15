/**
 * Offline, explainable emergency prioritization.
 * This is a deterministic application-level priority heuristic, not a
 * medically or scientifically validated emergency prediction model.
 */

const HIGH_THRESHOLD = Number.parseInt(process.env.RISK_HIGH_THRESHOLD || '70', 10);
const MEDIUM_THRESHOLD = Number.parseInt(process.env.RISK_MEDIUM_THRESHOLD || '40', 10);

const HIGH_TERMS = [
  'fire', 'accident', 'unconscious', 'bleeding', 'severe', 'critical',
  'trapped', 'attack', 'assault', 'danger', 'urgent', 'ambulance',
  'heart', 'breathing', 'injury', 'injured', 'explosion', 'faint',
];
const MEDIUM_TERMS = [
  'help', 'lost', 'stuck', 'threat', 'fall', 'minor injury', 'stranded',
  'unsafe', 'emergency',
];
const LOW_TERMS = ['test', 'false alarm', 'safe', 'resolved', 'minor', 'okay'];

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

function scoreText(text) {
  const normalized = String(text || '').toLowerCase();
  let score = 0;
  const reasons = [];

  const highMatches = HIGH_TERMS.filter((term) => normalized.includes(term));
  const mediumMatches = MEDIUM_TERMS.filter((term) => normalized.includes(term));
  const lowMatches = LOW_TERMS.filter((term) => normalized.includes(term));

  if (highMatches.length) {
    score += 55;
    reasons.push(`High-severity emergency wording: ${highMatches.slice(0, 3).join(', ')}`);
  } else if (mediumMatches.length) {
    score += 25;
    reasons.push(`Moderate emergency wording: ${mediumMatches.slice(0, 3).join(', ')}`);
  } else if (lowMatches.length) {
    score -= 15;
    reasons.push(`Lower-priority wording: ${lowMatches.slice(0, 3).join(', ')}`);
  } else {
    reasons.push('No additional severity keywords were provided.');
  }

  return { score, reasons };
}

function predictEmergencyRisk({ severity, notes, latitude, longitude, accuracy }) {
  let score = 20;
  const reasons = ['Base emergency priority applied to an SOS event.'];

  const validCoordinates = Number.isFinite(latitude) && latitude >= -90 && latitude <= 90
    && Number.isFinite(longitude) && longitude >= -180 && longitude <= 180;

  if (validCoordinates) {
    score += 10;
    reasons.push('Valid GPS coordinates are available.');
  } else {
    reasons.push('GPS coordinates are unavailable or invalid.');
  }

  if (Number.isFinite(accuracy) && accuracy >= 0) {
    if (accuracy <= 20) {
      score += 10;
      reasons.push('GPS accuracy is high (20 m or better).');
    } else if (accuracy <= 100) {
      score += 6;
      reasons.push('GPS accuracy is usable (100 m or better).');
    } else {
      score += 2;
      reasons.push('GPS accuracy is low (over 100 m).');
    }
  } else {
    reasons.push('GPS accuracy is unavailable.');
  }

  const normalizedSeverity = String(severity || '').toUpperCase();
  if (normalizedSeverity === 'CRITICAL') {
    score += 15;
    reasons.push('Existing SOS severity is CRITICAL.');
  } else if (normalizedSeverity === 'HIGH') {
    score += 10;
    reasons.push('Existing SOS severity is HIGH.');
  } else if (normalizedSeverity === 'MEDIUM') {
    score += 5;
    reasons.push('Existing SOS severity is MEDIUM.');
  } else if (normalizedSeverity === 'LOW') {
    score -= 5;
    reasons.push('Existing SOS severity is LOW.');
  }

  const textResult = scoreText(notes);
  score += textResult.score;
  reasons.push(...textResult.reasons);

  score = clamp(score, 0, 100);
  const high = Number.isFinite(HIGH_THRESHOLD) ? HIGH_THRESHOLD : 70;
  const medium = Number.isFinite(MEDIUM_THRESHOLD) ? MEDIUM_THRESHOLD : 40;
  const riskLevel = score >= high ? 'HIGH' : score >= medium ? 'MEDIUM' : 'LOW';

  return {
    riskLevel,
    riskScore: score,
    riskReason: reasons.join(' '),
    predictedAt: new Date(),
  };
}

module.exports = {
  predictEmergencyRisk,
  HIGH_THRESHOLD,
  MEDIUM_THRESHOLD,
};
