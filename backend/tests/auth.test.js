const request = require('supertest');
const { app } = require('../server');

describe('Auth Endpoints', () => {
  it('GET /api/health should return HEALTHY status', async () => {
    const res = await request(app).get('/api/health');
    expect(res.statusCode).toEqual(200);
    expect(res.body).toHaveProperty('status', 'HEALTHY');
  });

  it('POST /api/auth/login with missing parameters should return 401 or 400', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'nonexistent@resq.org', password: 'wrongpassword' });
    expect(res.statusCode).toBeGreaterThanOrEqual(400);
    expect(res.body.success).toBe(false);
  });
});
