const request = require('supertest');
const { app } = require('../server');

describe('SOS Endpoints', () => {
  it('GET /api/sos/active without auth token should return 401', async () => {
    const res = await request(app).get('/api/sos/active');
    expect(res.statusCode).toEqual(401);
    expect(res.body.success).toBe(false);
  });
});
