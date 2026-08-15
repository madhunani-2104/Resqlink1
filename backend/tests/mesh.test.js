const request = require('supertest');
const { app } = require('../server');

describe('Mesh Communication Endpoints', () => {
  it('POST /api/mesh/message without auth token should return 401', async () => {
    const res = await request(app).post('/api/mesh/message').send({
      content: 'Emergency beacon test',
      packetType: 'SOS_BEACON',
    });
    expect(res.statusCode).toEqual(401);
    expect(res.body.success).toBe(false);
  });
});
