# ResQ - User Manual & Disaster Response Field Guide

This manual serves as a operational guide for both civilian disaster victims and emergency response field teams using the **ResQ** application.

---

## 1. Operating in Offline Mode (No Internet / No Cell Towers)

When a natural disaster disables cellular towers and power grids:
1. Ensure **Bluetooth** and **Wi-Fi** are enabled on your mobile device.
2. Launch the **ResQ** application.
3. The app will automatically initialize the local **SQLite Database** and start searching for nearby **BLE & Wi-Fi Direct** mesh nodes.

---

## 2. Triggering an SOS Emergency Alert

1. Open the **SOS** tab in the main navigation.
2. Tap the central red **PRESS FOR SOS** button.
3. Confirm the broadcast in the emergency dialog box.
4. Your phone will:
   - Begin broadcasting a distress signal containing your current GPS location and medical card across nearby mobile phones.
   - Save the alert in local storage.
   - Queue the alert for cloud auto-sync when cellular signal returns.

---

## 3. Using Offline Mesh Chat

1. Open the **Mesh Chat** tab.
2. Select **Emergency Broadcast Channel**.
3. Type text messages to communicate with surrounding victims or rescue workers in range.
4. Packets automatically hop across surrounding mobile phones (up to 7 hops) to extend communication range far beyond single-device Bluetooth distance.

---

## 4. Viewing Safe Zones & Shelters

1. Navigate to the **Live Map** tab.
2. View OpenStreetMap GIS layers showing:
   - 🛡️ **Green Circles**: Safe Zones and high-ground assembly points.
   - 🛖 **Amber Icons**: Evacuation Shelters with current capacity and available amenities (food, water, beds).
   - 🚨 **Red Markers**: Active Victim SOS locations.
