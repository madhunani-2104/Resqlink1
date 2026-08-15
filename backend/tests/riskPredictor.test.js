const { predictEmergencyRisk } = require('../src/utils/riskPredictor');

describe('offline emergency risk predictor', () => {
  test('LOW scenario', () => {
    const result = predictEmergencyRisk({
      severity: 'LOW',
      notes: 'test safe',
      latitude: 16.5,
      longitude: 80.6,
      accuracy: 250,
    });
    expect(result.riskLevel).toBe('LOW');
    expect(result.riskScore).toBeGreaterThanOrEqual(0);
  });

  test('MEDIUM scenario', () => {
    const result = predictEmergencyRisk({
      severity: 'MEDIUM',
      notes: 'I am lost and need help',
      latitude: 16.5,
      longitude: 80.6,
      accuracy: 80,
    });
    expect(result.riskLevel).toBe('MEDIUM');
  });

  test('HIGH scenario', () => {
    const result = predictEmergencyRisk({
      severity: 'HIGH',
      notes: 'accident with bleeding and urgent ambulance needed',
      latitude: 16.5,
      longitude: 80.6,
      accuracy: 10,
    });
    expect(result.riskLevel).toBe('HIGH');
  });

  test('invalid coordinates are handled without throwing', () => {
    const result = predictEmergencyRisk({
      severity: 'LOW',
      notes: '',
      latitude: 999,
      longitude: 999,
      accuracy: -1,
    });
    expect(['LOW', 'MEDIUM', 'HIGH']).toContain(result.riskLevel);
  });
});
