const STATUS_TRANSITIONS = {
  PENDING: ['ASSIGNED', 'CANCELLED'],
  ASSIGNED: ['ACKNOWLEDGED', 'PENDING', 'CANCELLED'],
  ACKNOWLEDGED: ['RESOLVED', 'CANCELLED'],
  RESOLVED: [],
  CANCELLED: [],
  ACTIVE: ['ASSIGNED', 'ACKNOWLEDGED', 'CANCELLED'],
  RESCUED: [],
};

const canTransition = (from, to) =>
  typeof from === 'string' &&
  typeof to === 'string' &&
  STATUS_TRANSITIONS[from]?.includes(to) === true;

const isDispatchableStatus = (status) =>
  ['PENDING', 'ASSIGNED', 'ACKNOWLEDGED', 'ACTIVE'].includes(status);

module.exports = { STATUS_TRANSITIONS, canTransition, isDispatchableStatus };
