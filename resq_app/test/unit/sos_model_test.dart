import 'package:flutter_test/flutter_test.dart';

import 'package:resq_app/features/sos/models/sos_model.dart';

void main() {
  test('parses live SOS event metadata and nested location', () {
    final alert = SosModel.fromJson({
      'sosId': 'SOS-1',
      'eventId': 'SOS-1',
      'messageId': 'MSG-1',
      'userId': 'victim-1',
      'userName': 'Victim',
      'userPhone': '123',
      'location': {'latitude': 12.34, 'longitude': 56.78, 'accuracy': 4.5},
      'status': 'ACKNOWLEDGED',
      'createdAt': '2026-09-11T10:00:00.000Z',
    });

    expect(alert.eventId, 'SOS-1');
    expect(alert.messageId, 'MSG-1');
    expect(alert.latitude, 12.34);
    expect(alert.longitude, 56.78);
    expect(alert.status, 'ACKNOWLEDGED');
    expect(alert.createdAt, DateTime.parse('2026-09-11T10:00:00.000Z'));
  });

  test('falls back to sosId for legacy event metadata', () {
    final alert = SosModel.fromJson({
      'sosId': 'SOS-legacy',
      'userId': 'victim-1',
      'userName': 'Victim',
      'userPhone': '123',
      'latitude': 1.0,
      'longitude': 2.0,
    });

    expect(alert.eventId, 'SOS-legacy');
    expect(alert.messageId, 'SOS-legacy');
  });
}
