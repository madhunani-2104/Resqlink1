# ResQ - API Documentation & Specifications

Base URL: `http://localhost:5000/api`

---

## 1. Authentication Endpoints

### `POST /auth/register`
Create a new user account.
- **Request Body**:
  ```json
  {
    "name": "Jane Doe",
    "email": "jane@resq.org",
    "phone": "+1234567890",
    "password": "password123",
    "role": "user"
  }
  ```
- **Response (201)**:
  ```json
  {
    "success": true,
    "data": {
      "_id": "66a4bc1234...",
      "name": "Jane Doe",
      "email": "jane@resq.org",
      "meshId": "RESQ-A1B2",
      "token": "eyJhbGciOiJIUzI1Ni..."
    }
  }
  ```

### `POST /auth/login`
Authenticate user and retrieve Bearer token.
- **Request Body**:
  ```json
  {
    "email": "jane@resq.org",
    "password": "password123"
  }
  ```

---

## 2. SOS Emergency Endpoints

### `POST /sos`
Trigger SOS emergency distress beacon.
- **Headers**: `Authorization: Bearer <TOKEN>`
- **Request Body**:
  ```json
  {
    "sosId": "SOS-1722000000",
    "latitude": 40.73061,
    "longitude": -73.93524,
    "batteryLevel": 95,
    "severity": "CRITICAL",
    "notes": "Trapped in building ground floor."
  }
  ```

### `GET /sos/active`
Retrieve list of active victim SOS alerts.
- **Headers**: `Authorization: Bearer <TOKEN>`

---

## 3. Mesh Communication & Synchronization

### `POST /mesh/message`
Relay or store mesh packet.
- **Request Body**:
  ```json
  {
    "packetId": "PKT-1001",
    "senderId": "RESQ-A1B2",
    "senderName": "Jane Doe",
    "content": "Need medical assistance at Safe Zone Alpha",
    "packetType": "CHAT",
    "ttl": 7
  }
  ```

### `POST /mesh/sync-batch`
Synchronize queued offline transactions from client SQLite database.
- **Request Body**:
  ```json
  {
    "deviceId": "DEVICE-ANDROID-001",
    "items": [
      {
        "id": 1,
        "dataType": "SOS_ALERT",
        "payload": { ... }
      }
    ]
  }
  ```

---

## 4. Socket.IO Real-Time Events

- `new_sos_alert` (Server -> Client): Broadcasts new incoming SOS beacon.
- `update_location` (Client -> Server): Transmits real-time GPS telemetry stream.
- `broadcast_mesh_packet` (Client -> Client): P2P socket fallback for mesh packets.
