# 💊 MedAlert: Smart Medicine Reminder System

> A seamlessly integrated IoT & Mobile Application ecosystem designed to ensure you never miss a dose again. 

## 📖 Overview
**MedAlert** is an intelligent, hardware-software integrated pillbox system. It combines a physical ESP32-powered medicine organizer with a beautifully crafted Flutter mobile app. Through real-time Bluetooth Low Energy (BLE) synchronization, MedAlert tracks your medication schedule, triggers physical LED and buzzer alerts directly at the designated compartment, and updates your intake status instantly on your phone.

## ✨ Key Features
* 🔄 **BLE Real-Time Sync:** Instantly syncs medication schedules between the companion Flutter app and the ESP32 hardware.
* 📦 **18-Compartment Matrix:** Supports a 3-day (Monday, Tuesday, Wednesday), 6-slot daily schedule tracked precisely via an embedded Matrix grid (3 Rows, 6 Columns).
* 🚨 **Multi-Sensory Alerts:** Employs bright LED indicators and a physical buzzer to pinpoint exactly which medicine needs to be taken.
* 📱 **Dynamic App States:** Medicine cards smoothly transition through `Upcoming`, `Active` (with pulsing animations), `Taken`, and `Missed` states.
* ⏱ **Grace Period Logic:** 15-minute grace window for intake confirmation before a dose is officially recorded right on the app.
* 💾 **Offline Functionality:** Built with Hive for local app data persistence and LittleFS for hardware fallback so your alerts work even without an active internet connection!

## 🛠 Tech Stack

### Mobile Application
* <img src="https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white" /> **Flutter:** Cross-platform mobile framework toolkit.
* <img src="https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white" /> **Dart:** Core UI and logic programming language.
* **Provider:** Efficient dependency injection and state management.
* **Hive:** Fast, lightweight NoSQL local database.
* **flutter_blue_plus:** Stable BLE communication plugin.

### Hardware (IoT)
* <img src="https://img.shields.io/badge/ESP32-E7352C?style=flat&logo=espressif&logoColor=white" /> **ESP32:** Powerful dual-core microcontroller with onboard Wi-Fi & BLE.
* <img src="https://img.shields.io/badge/C++-00599C?style=flat&logo=c%2B%2B&logoColor=white" /> **C++ (Arduino IDE):** Core embedded firmware logic routines.
* **ArduinoJson & LittleFS:** JSON parsing and robust local file system storage.

## 🚀 Installation & Setup

### 1. Hardware Setup (ESP32)
1. Ensure you have the [Arduino IDE](https://www.arduino.cc/en/software) installed.
2. Install the `ESP32` board package via the Boards Manager.
3. Install the required libraries via the Library Manager: `ArduinoJson`.
4. Open the `MedAlert.ino` sketch located in `hardware/MedAlert/`.
5. Connect your ESP32 board and verify the pinout (`rowPins`, `colPins`, `buzzerPin`) matches your physical LED Matrix layout.
6. Compile and **Upload** to the ESP32. 

### 2. Software Setup (Flutter App)
1. Ensure [Flutter](https://docs.flutter.dev/get-started/install) is installed and configured on your machine.
2. Navigate to the `software` directory:
   ```bash
   cd software
   ```
3. Fetch all required dependencies:
   ```bash
   flutter pub get
   ```
4. Connect an Android or iOS testing device.
5. Compile and run the companion app:
   ```bash
   flutter run
   ```

## 🎮 Usage
1. Power on the MedAlert ESP32 hardware device. By default, it begins advertising its BLE signature. 
2. Open the MedAlert app. 
3. The app will autonomously detect and connect to the ESP32 device! (Check the Bluetooth icon in the app bar; it will turn **Green**).
4. Tap any empty slot on your Monday-Wednesday schedule to add a medicine, dosage, and time.
5. When the time is reached, the ESP32 triggers the designated row/col LED and rings the buzzer.
6. Click **"Confirm Intake"** inside the app to kill the hardware alarm and officially mark the slot as `Taken`!

## 📂 Project Structure
```text
MedAlert/
├── hardware/
│   └── MedAlert/
│       └── MedAlert.ino            # Core ESP32 BLE and Matrix logic
├── software/
│   ├── lib/
│   │   ├── models/                 # Hive data models
│   │   ├── providers/              # AppState logic & time management
│   │   ├── screens/                # Flutter UI layout (HomeScreen)
│   │   ├── services/               # BLE and Storage wrappers
│   │   └── widgets/                # Reusable UI components (EditDialog, etc.)
│   ├── pubspec.yaml                # Flutter dependencies
│   └── README.md
```

## 🔮 Future Improvements
* **Extended Schedule Support:** Broadening the hardware matrix logic to seamlessly support all 7 days of the week natively.
* **Remote Caregiver Dashboard:** Integrating Firebase to allow doctors and relatives to remotely monitor missed doses via the cloud.
* **Battery Efficiency Mode:** Introduce hardware deep-sleep states between scheduled medicine intervals.

## 🤝 Contributors
* **Blessy Molcharls** - Lead Developer & Creator

## 📜 License
This project is licensed under the MIT License. Feel free to clone, modify, and utilize this system for personal and educational hackathon projects!
