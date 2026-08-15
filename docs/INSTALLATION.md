# ResQ - Installation & Setup Guide

This guide details the step-by-step setup procedure required to build, run, and test the **ResQ** emergency system locally.

---

## System Requirements

- **Node.js**: v18.0.0 or higher
- **npm**: v9.0.0 or higher
- **MongoDB**: Community Edition v6.0+ or MongoDB Atlas connection string
- **Flutter SDK**: v3.10.0 or higher
- **Java Development Kit (JDK)**: OpenJDK 17 or higher
- **Android Studio / VS Code**: With Flutter and Dart plugins installed

---

## 1. Backend Setup

1. Open terminal and navigate to `backend/`:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create environment configuration `.env`:
   ```env
   PORT=5000
   NODE_ENV=development
   MONGO_URI=mongodb://127.0.0.1:27017/resq_db
   JWT_SECRET=resq_emergency_secret_key_2026_jwt_token_btech_capstone
   JWT_EXPIRE=30d
   ```

4. Start local MongoDB service (if running locally):
   ```bash
   mongod --dbpath /data/db
   ```

5. Run development server:
   ```bash
   npm run dev
   ```
   *The server will initialize at `http://localhost:5000`.*

---

## 2. Flutter Mobile & Web Setup

1. Navigate to `resq_app/`:
   ```bash
   cd resq_app
   ```

2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```

3. Run in Chrome Browser (Web Mesh Simulator Mode):
   ```bash
   flutter run -d chrome
   ```

4. Run on Android Emulator or Physical Hardware:
   - Connect your Android device with USB Debugging enabled or start Android Emulator.
   - Run:
     ```bash
     flutter run
     ```

---

## 3. Running Test Suites

- **Backend Integration Tests**:
  ```bash
  cd backend
  npm test
  ```

- **Flutter Unit & Widget Tests**:
  ```bash
  cd resq_app
  flutter test
  ```
