# PROJECT REPORT
## ResQ: Offline Mesh Communication & SOS Emergency System

**A Dissertation / Major Project Report Submitted in Partial Fulfillment of the Requirements for the Degree of Bachelor of Technology (B.Tech) in Computer Science & Engineering**

---

### Abstract

During large-scale natural disasters such as earthquakes, floods, and hurricanes, centralized telecommunication infrastructures (cellular towers, fiber backbones, and power grids) frequently suffer catastrophic damage or physical failure. This creates a critical "communication blackout" during the most vital hours of emergency response.

This project presents **ResQ**, an ad-hoc, disaster-resilient emergency response system that establishes peer-to-peer (P2P) wireless mesh networks using Bluetooth Low Energy (BLE) and Wi-Fi Direct protocols on commodity mobile hardware. ResQ enables multi-hop text messaging, location telemetry transmission, and one-tap SOS emergency broadcasting without requiring active cellular network connections or internet access.

The system combines a cross-platform mobile client built on Flutter and Material 3 design, a local SQLite store-and-forward transaction queue, and a central cloud synchronization backend powered by Node.js, Express.js, MongoDB, and Socket.IO. Empirical validation demonstrates multi-hop packet propagation, packet deduplication, and reliable automatic cloud database synchronization upon network recovery.

---

### Table of Contents
1. Introduction & Background
2. Literature Survey & Related Work
3. System Architecture & Methodology
4. Mesh Routing Algorithm & Protocol Specification
5. Module Implementation & Code Structure
6. Results, Verification & Performance Analysis
7. Conclusion & Future Scope

---

### 1. Introduction & Background

Immediate post-disaster response efficiency is heavily constrained by communication availability. Traditional disaster recovery solutions often rely on expensive satellite phones or dedicated radio hardware. ResQ leverages existing consumer smartphones to form an autonomous, self-healing Mobile Ad-Hoc Network (MANET).

#### Objectives:
1. Provide an intuitive one-tap SOS alert mechanism for trapped disaster victims.
2. Implement multi-hop packet routing over BLE and Wi-Fi Direct with Time-To-Live (TTL) packet bounds.
3. Guarantee local data persistence using SQLite for eventual cloud database synchronization.
4. Render interactive GIS spatial maps for emergency responders displaying victim locations, safe zones, and shelters.

---

### 2. Literature Survey & Related Work

Existing literature in Mobile Ad-Hoc Networks (MANETs) highlights several challenges:
- **Energy Efficiency**: Prolonged scanning in mobile devices causes rapid battery depletion.
- **Packet Flooding & Broadcast Storms**: Unbounded flooding degrades wireless medium capacity.
- **Intermittent Connectivity**: Node mobility leads to frequent path disconnections.

ResQ addresses these challenges by implementing bounded Time-To-Live (TTL = 7) packet limits, packet hash deduplication tables, and store-and-forward queueing.

---

### 3. System Architecture & Methodology

The architecture follows Clean Architecture principles divided into three decoupled tiers:

1. **Client Interface Tier**: Flutter application providing Material 3 responsive UI, Provider state management, and OpenStreetMap rendering.
2. **Local Data & Mesh Tier**: Custom native platform channels (Kotlin) interfacing with Android BLE and Wi-Fi Direct stacks, backed by an offline SQLite database.
3. **Central Cloud Infrastructure Tier**: Node.js microservice API, Mongoose ORM models, JWT auth middleware, and Socket.IO real-time event streaming server.

---

### 4. Mesh Routing Algorithm & Protocol Specification

```
[ Sender Node ] ===(BLE Broadcast)===> [ Intermediate Relay Node ] ===(Wi-Fi Direct)===> [ Receiver / Cloud Gateway ]
```

#### Algorithm Steps (Packet Handling):
1. **Packet Generation**: Generate `packetId = Hash(senderId + timestamp + content)`.
2. **Deduplication Check**: If `packetId` exists in `seenPacketIds` set, discard packet.
3. **Local Store**: Save packet into SQLite local database (`mesh_messages`).
4. **TTL Evaluation**:
   - If `TTL <= 1`: Halt propagation.
   - Else: Decrement `TTL = TTL - 1`, increment `hopCount = hopCount + 1`, append `localNodeId` to `relayedBy`, and enqueue packet for broadcast.

---

### 5. Results & Verification

- **Backend Integration Testing**: Verified via Jest test suites covering authentication, SOS beacon ingestion, and batch offline queue processing (100% pass rate).
- **Web Simulation**: Validated multi-node cluster packet exchange in Chrome browser environments.
- **Local Persistence**: Verified SQLite transactional integrity across simulated app restarts and network disconnections.

---

### 6. Conclusion & Future Scope

ResQ provides a complete, scalable, and resilient emergency communication architecture suitable for deployment in natural disaster scenarios. 

**Future Enhancement Scope**:
- Integration of LoRaWAN long-range radio hardware modules via USB-OTG/Serial.
- End-to-end asymmetric key encryption for private channels.
- AI-driven automated rescue route optimization using A* algorithm over road network graphs.
