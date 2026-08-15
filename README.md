# ResQ – Offline Mesh Communication & SOS Emergency System

> **B.Tech Final Year Capstone Computer Science & Engineering Project**  
> A disaster-resilient emergency infrastructure and mobile platform powered by peer-to-peer (P2P) BLE & Wi-Fi Direct multi-hop mesh networking, offline SQLite data queuing, interactive GIS live mapping, and cloud synchronization.

---

## Key Features & Highlights

- 🆘 **One-Tap Emergency SOS Beacon**: Broadcasts instant distress alerts containing GPS coordinates, medical history, and battery telemetry.
- 📡 **Offline Multi-Hop Mesh Network**: Relays text messages and distress packets across nearby mobile nodes using Bluetooth Low Energy (BLE) & Wi-Fi Direct without active cellular or internet coverage.
- 🔄 **Automatic Recovery Sync**: Queues offline transactions in SQLite and automatically syncs with the central server once internet connectivity is restored.
- 🗺️ **Interactive GIS Map**: Real-time OpenStreetMap rendering displaying Safe Zones, Evacuation Shelters, Rescue Teams, and Victim distress markers.
- 🏥 **Emergency Medical Profile & Contacts**: Quick access to blood group, allergies, chronic conditions, and emergency family phone numbers.
- 🛡️ **Rescue Responder & Admin Dashboard**: Real-time incident command monitoring, victim location tracking, and emergency resource management.
- 💻 **Cross-Platform Support**: Runs natively on Android devices and as a Web application with a built-in P2P Web Mesh Simulator.

---

## Tech Stack

### Frontend (Mobile & Web)
- **Framework**: Flutter 3.x (Material 3 Design)
- **State Management**: Provider
- **Local Storage**: SQLite (`sqflite`), Shared Preferences
- **Network**: Dio REST API client, Socket.IO WebSockets client
- **Maps & Location**: `flutter_map` (OpenStreetMap), `geolocator`
- **Native Android Interop**: Kotlin MethodChannels (BLE & Wi-Fi Direct)

### Backend Services
- **Runtime**: Node.js & Express.js
- **Database**: MongoDB & Mongoose ORM
- **Authentication**: JSON Web Tokens (JWT) & bcryptjs
- **Real-Time Communication**: Socket.IO Engine
- **Logging & Uploads**: Winston Logger, Multer file handler
- **Test Framework**: Jest & Supertest

---

## Project Directory Structure

```
RESQ-LiNK/
├── backend/                  # Node.js + Express + MongoDB Central Server
│   ├── server.js             # Main server entrypoint & Socket.IO initialization
│   ├── src/
│   │   ├── config/           # Database connection, JWT & Winston logger
│   │   ├── controllers/      # Auth, SOS, Mesh, Map, User & Admin controllers
│   │   ├── models/           # Mongoose schemas (User, SosAlert, MeshMessage, etc.)
│   │   ├── routes/           # REST API route endpoints
│   │   ├── middleware/       # Auth, Role-based access, Uploads & Error handling
│   │   └── sockets/          # Socket.IO real-time event handlers
│   └── tests/                # Jest integration test suites
│
├── resq_app/                 # Flutter Cross-Platform Application (Android & Web)
│   ├── pubspec.yaml          # Dependencies and configuration
│   ├── android/              # Native Android platform channel files (Kotlin)
│   ├── web/                  # Web entrypoint and manifest
│   ├── lib/
│   │   ├── main.dart         # Flutter entrypoint
│   │   ├── core/             # Database, Network, Services, Constants & Utilities
│   │   ├── features/         # Auth, Profile, SOS, Mesh Chat, Map, Admin, Settings
│   │   └── widgets/          # Custom Material 3 UI widgets
│   └── test/                 # Flutter Unit and Widget test suites
│
└── docs/                     # Academic & Technical Documentation
    ├── INSTALLATION.md       # Developer setup guide
    ├── DEPLOYMENT.md         # Production deployment & Docker guide
    ├── API_DOCUMENTATION.md  # REST API & Socket.IO specification
    ├── USER_MANUAL.md        # Disaster victim & responder user guide
    └── PROJECT_REPORT.md     # Academic Capstone Project Final Report
```

---

## Quickstart Guide

### 1. Start Node.js Central Server
```bash
cd backend
npm install
npm start
```
*Backend server runs on `http://localhost:5000`.*

### 2. Run Backend Test Suite
```bash
cd backend
npm test
```

### 3. Launch Flutter Application
```bash
cd resq_app
flutter pub get
flutter run -d chrome # Or run on Android Device / Emulator
```

---

## License & Project Credits
Developed as a B.Tech Computer Science & Engineering Capstone Project. Distributed under the MIT License.
