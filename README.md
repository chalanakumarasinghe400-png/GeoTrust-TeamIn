# geotrust_app

A new Flutter project.

"GeoTrust" is a centralized mobile platform designed to digitize the entire lifecycle of mineral transportation[cite: 2]. By adopting an Object-Oriented Programming (OOP) framework and enforcing a "Double-Handshake" Bluetooth Low Energy (BLE) Proof of Presence protocol, GeoTrust physically binds the digital license to the geographic reality of the transport vehicle[cite: 2].

## ⚠️ Background & Problem Statement
The current sand mining and distribution process in Sri Lanka relies heavily on manual paperwork and disjointed communication between stakeholders[cite: 1, 2]. 
* **Inefficiency:** Paper permits are slow to issue and difficult to update in real-time[cite: 1].
* **Lack of Visibility:** Truck owners cannot easily track trip status, and the GSMB lacks real-time data on active transports[cite: 1].
* **Coordination Gaps:** Hardware owners often lack real-time updates on incoming deliveries[cite: 1].

## 🏗️ System Architecture & Core Objects
To resolve these logistical challenges and ensure a robust, maintainable architecture, GeoTrust utilizes the Object-Oriented Software Development (OOSD) methodology[cite: 2]. The application achieves its outcomes through the communication of encapsulated objects[cite: 2]:
* **User Role (Actor Objects):** Utilizing Role-Based Access Control (RBAC), physical users are encapsulated into specific roles[cite: 2].
* **Transport Permit (Stateful Entity):** This core domain object replaces the manual paper permit and encapsulates its own strict state machine (Pending -> Active -> Completed)[cite: 2].
* **Ledger Service (Controller Object):** This main controller holds sand inventory numbers to automatically calculate available amounts and stops the creation of new permits if the requested amount goes over the allowed limit[cite: 2].

## 🛡️ Key Features & Non-Functional Requirements
* **Offline-First Capability:** Utilizes localized, device-to-device BLE communications to validate object state transitions offline, synchronizing with the central server via a Store-and-Forward architecture when network access is restored[cite: 2].
* **Universal Device Support:** Utilizes universal BLE rather than premium Near Field Communication (NFC) chips, ensuring 100% user inclusion across legacy and budget-tier Android devices[cite: 2].
* **Security (Proof of Presence):** The BLE handshake enforces a strict 15-meter verification radius before allowing a Transport Permit to transition states, preventing remote "Relay Attacks"[cite: 2].
* **Usability:** The mobile application interface features fast-switch RBAC menus, ensuring ease of use for multi-role Owner-Operators[cite: 2].

## 👥 System Actors
* **GSMB (Admin):** Registers all users (Mine Owners, Truck Owners, Drivers, Hardware Owners) and sets initial quotas[cite: 1].
* **Mine Owner:** Has a mining license and approves loading[cite: 1].
* **Truck Owner:** Has a transport license and assigns specific trucks/drivers to trips[cite: 1].
* **Truck Driver:** Executes the transport[cite: 1].
* **Hardware Owner (Buyer):** Receives the sand and confirms unloading[cite: 1].

## 🔄 The 6-Step Workflow
GeoTrust follows a linear, step-by-step workflow to ensure the digital license is valid only during the actual trip[cite: 1]:
1. **Assignment:** The Truck Owner logs in and selects a specific Truck and Driver for a job[cite: 1].
2. **Arrival at Mine:** The Driver drives to the mining site and presses the "Arrived" button, which the system verifies against the Mine Owner's registered GPS location[cite: 1].
3. **Loading:** Once physical loading is complete, the Mine Owner presses "Loaded", which unlocks the "Start Trip" button on the Driver's app[cite: 1].
4. **License Issuance:** The Driver presses "Start Trip" inside the mining site, deducting the load volume from the quota and generating a Digital Transport License valid for the specific trip duration[cite: 1].
5. **Transportation & Arrival:** The Driver proceeds to the destination and presses "Arrived" upon reaching the Hardware Owner's verified GPS location[cite: 1].
6. **Unloading & Completion:** The Hardware Owner confirms unloading, which immediately cancels the Digital License and marks the trip as completed[cite: 1].

---

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
