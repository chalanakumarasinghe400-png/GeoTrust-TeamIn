# geotrust_app

A new Flutter project for a centralized mobile platform designed to completely digitize the lifecycle of sand and mineral transportation in Sri Lanka[cite: 1, 2]. 

## ⚠️ The Problem
The current sand mining and distribution process relies heavily on manual paperwork and phone calls[cite: 1, 2]. This causes several issues:
* **Inefficiency:** Paper permits are slow to issue and hard to update[cite: 1].
* **Lack of Visibility:** The Geological Survey and Mines Bureau (GSMB) and truck owners cannot easily track active transports in real-time[cite: 1].
* **Coordination Gaps:** Hardware owners often do not know exactly when their deliveries will arrive[cite: 1].

## ✨ Core Features
* **Automated Quota Management:** The system automatically deducts sand volume from a mine's permitted quota the moment a trip begins[cite: 1].
* **Digital Licensing:** Time-bound digital transport permits are issued instantly, but only when drivers are physically at the verified loading site[cite: 1].
* **Offline-First & Proof of Presence:** Uses device-to-device Bluetooth Low Energy (BLE) for a "Double-Handshake" protocol[cite: 2]. This verifies that the truck is physically at the correct location (within 15 meters) for loading and unloading, even in remote areas without internet connectivity[cite: 2].

## 👥 User Roles
* **GSMB (Admin):** Registers all users and sets initial mining quotas[cite: 1].
* **Mine Owner:** Manages the mining yard, approves truck loading, and holds the mining license[cite: 1].
* **Truck Owner:** Manages the transport fleet and assigns specific drivers and trucks to jobs[cite: 1].
* **Truck Driver:** Broadcasts location via BLE, transports the material, and completes the journey[cite: 1, 2].
* **Hardware Owner (Buyer):** Scans the incoming truck to confirm delivery and finalize the trip[cite: 1, 2].

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
