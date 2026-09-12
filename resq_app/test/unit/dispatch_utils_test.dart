import 'package:flutter_test/flutter_test.dart';

import 'package:resq_app/features/sos/models/sos_model.dart';

void main() {
  test('dispatch model preserves assigned responder metadata', () {
    final alert = SosModel.fromJson({
      'sosId': 'SOS-1',
      'userId': 'victim',
      'userName': 'Victim',
      'userPhone': '123',
      'latitude': 1.0,
      'longitude': 2.0,
      'status': 'ASSIGNED',
      'assignedAt': '2026-09-11T10:00:00.000Z',
      'assignedResponder': {'_id': 'responder-1', 'name': 'Alex'},
    });

    expect(alert.status, 'ASSIGNED');
    expect(alert.assignedResponderId, 'responder-1');
    expect(alert.assignedResponderName, 'Alex');
    expect(alert.assignedAt, isNotNull);
  });
}
