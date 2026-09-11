const { canTransition, isDispatchableStatus } = require('../src/utils/dispatchUtils');

describe('Dispatch status rules', () => {
  test('allows the supported dispatch lifecycle', () => {
    expect(canTransition('PENDING', 'ASSIGNED')).toBe(true);
    expect(canTransition('ASSIGNED', 'ACKNOWLEDGED')).toBe(true);
    expect(canTransition('ACKNOWLEDGED', 'RESOLVED')).toBe(true);
  });

  test('rejects duplicate or invalid transitions', () => {
    expect(canTransition('RESOLVED', 'ASSIGNED')).toBe(false);
    expect(canTransition('CANCELLED', 'ACKNOWLEDGED')).toBe(false);
    expect(isDispatchableStatus('PENDING')).toBe(true);
    expect(isDispatchableStatus('RESOLVED')).toBe(false);
  });
});
