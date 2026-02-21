
<img width="1280" height="640" alt="image" src="https://github.com/user-attachments/assets/d6218733-0a3d-4bb5-91fd-0569581ce4d9" />


# MedAlert  💊

## Basic Details

### Team Name: Eclipse 

### Team Members
- Member 1: Blessy Mol Charls  - Muthoot Institute of Technology and Science 
- Member 2: Niharika C - Muthoot Institute of Technology and Science

### Hosted Project Link
GitHub Repository: https://github.com/Blessymolcharls/MedAlert
### Project Description
**MedAlert** is a hardware-software integrated pillbox system. It combines a physical ESP32-powered medicine organizer with a Flutter mobile app. Through real-time Bluetooth Low Energy (BLE) synchronization, MedAlert tracks your medication schedule, triggers physical LED and buzzer alerts directly at the designated compartment, and updates your intake status instantly on your phone.


### The Problem statement
Many people, especially elderly people and those who take many medicines, forget to take their medicines properly. Most reminder apps only send phone notifications, and these can be ignored or missed. There is also no clear physical signal to show which medicine compartment should be opened.
### The Solution
MedAlert solves this problem by combining a smart ESP32-powered pillbox with LED matrix indications, a Flutter mobile application for managing medicine schedules, and real-time synchronization between the app and hardware using BLE. When it is time to take the medicine, the pillbox lights up the exact compartment and activates a buzzer. The mobile app allows users to confirm that they have taken the medicine and track its status as Upcoming, Active, Taken, or Missed.

## Technical Details

### Technologies/Components Used

**For Software:**
- Languages used: Dart,C++
- Frameworks used: Flutter
- Libraries used:
    flutter_blue_plus (BLE communication)
    Hive (local database)
    Provider (state management)
- Tools used: [e.g., VS Code, Git, Docker]

**For Hardware:**
- Main components:
    ESP32 Development Board
    LED Matrix (3 Rows × 6 Columns – 18 Compartments)
    Buzzer
    Jumper Wires & Breadboard
  
- Specifications:
    ESP32: Dual-core 240MHz, Wi-Fi + BLE
    LED Grid: 18-slot matrix layout
    BLE Protocol: Real-time bidirectional communication
- Tools required:
  	Arduino IDE
  	Soldering Iron
    USB Cable
  	Laptop with Flutter SDK

---

## Features

List the key features of your project:
- Feature 1: Supports a day planner with structured Morning,Noon,and Night slots, making medicine organization simple and systematic.
- Feature 2: Allows users to choose Before Food / After Food options and set fully customizable reminder times instead of fixed schedules
- Feature 3: Features a clean, intuitive UI with simple reset options for each column, allowing users to update or clear schedules effortlessly.
- Feature 4: Enables users to manually mark each dose as Taken or Missed, helping track medication consistency and maintain accountability.

---

## Implementation

### For Software:

#### Installation
```bash
cd software
flutter pub get
```

#### Run
```bash
flutter run
```

### For Hardware:

#### Components Required
- ESP32 Board
- LED matrix configuration (18)
- Resistors (1kΩ)
- Active Buzzer
- Breadboard
- Jumper wires
- Power supply

#### Circuit Setup
The circuit is designed using a 3 × 6 LED matrix configuration, where the 18 LEDs are arranged with 3 positive rows and 6 negative columns. The anodes (positive terminals) of each row are connected together and linked to three ESP32 GPIO pins through 220Ω current-limiting resistors (one resistor per row). The cathodes (negative terminals) of each column are connected vertically and directly connected to six dedicated ESP32 GPIO pins. This setup allows multiplexed control of all 18 LEDs using 9 GPIO pins (3 rows + 6 columns). An active buzzer is connected to another GPIO pin (positive to GPIO, negative to GND) to provide audio alerts. The ESP32 is powered via USB (5V), and all components share a common ground. When a scheduled time is reached, the ESP32 activates the corresponding row and column to light the specific LED while simultaneously triggering the buzzer.

---

## Project Documentation

### For Software:

#### Screenshots (Add at least 3)
<img width="410" height="912" alt="0" src="https://github.com/user-attachments/assets/80f84534-0c6a-42a2-9171-62aed388d355" />
Home page 
<img width="410" height="912" alt="0" src="https://github.com/user-attachments/assets/3b8ca90d-b78b-4071-afbc-cb824b5c7c0d" />
Dialog for adding medicine details
<img width="410" height="912" alt="0" src="https://github.com/user-attachments/assets/55933f37-40b4-4f8e-a8e7-ee7ff83e15a0" />
Medicine in Active state with confirm intake option

#### Diagrams

**System Architecture:**

![Architecture Diagram](docs/architecture.png)
Flutter App ↔ BLE Communication ↔ ESP32 Firmware
Hive stores local medicine schedules.
BLE transmits schedule to ESP32.
ESP32 stores fallback in LittleFS.
LED Matrix + Buzzer triggered based on RTC logic.

**Application Workflow:**

![Workflow](docs/workflow.png)
User adds medicine in Flutter app
Data stored in Hive
Data transmitted via BLE to ESP32
ESP32 schedules internal trigger
At scheduled time → LED + buzzer activated
User confirms intake → status updated

---

### For Hardware:

#### Schematic & Circuit

Circuit Diagram: 
<img width="1024" height="559" alt="image" src="https://github.com/user-attachments/assets/433260cf-260a-4bc5-8af3-0187acab2937" />

The circuit consists of a 3×6 LED matrix controlled by an ESP32 using multiplexing. The three positive row lines are connected to dedicated ESP32 GPIO pins through 1kΩ current-limiting resistors (one resistor per row) to protect the LEDs. The six negative column lines are directly connected to six separate GPIO pins on the ESP32, allowing selective control of each LED by activating a specific row and column combination. An active buzzer is connected to another dedicated GPIO pin with its negative terminal connected to GND for audio alerts. All components share a common ground, and the ESP32 is powered via USB (5V), ensuring stable operation of the entire system.

Schematic Diagram:
The schematic diagram presents the logical design of the 3 × 6 LED matrix controlled by the ESP32. It shows three row lines (positive) connected to GPIO pins through 1kΩ current-limiting resistors, ensuring safe current flow to the LEDs. The six column lines (negative) are connected directly to separate GPIO pins configured as sinking outputs. By using multiplexing, the ESP32 activates one row at a time while selecting the required column, allowing individual control of all 18 LEDs with minimal GPIO usage. The schematic also includes an active buzzer connected to a dedicated GPIO pin and GND, which is triggered during scheduled alert conditions. All components share a common ground and are powered via a stable 5V USB supply.
#### Build Photos

![IMG_20260221_091016714 (1)](https://github.com/user-attachments/assets/e07a94c1-f364-4a54-8e3f-ad12728f96a1)


---

## Additional Documentation


### For Mobile Apps:

#### App Flow Diagram

![App Flow](docs/app-flow.png)
User adds medicine in Flutter app
Data stored in Hive
Data transmitted via BLE to ESP32
ESP32 schedules internal trigger
At scheduled time → LED + buzzer activated
User confirms intake → status updated

### For Hardware Projects:

#### Bill of Materials (BOM)

| Component                      | Quantity | Specifications                           | Approx. Price (₹) | Link / Source                   |
| ------------------------------ | -------- | ---------------------------------------- | ----------------- | ------------------------------- |
| ESP32 Development Board        | 1        | Dual-core 240MHz, WiFi + BLE, 3.3V logic | ₹450              | ocal electronics store          |
| 5mm LEDs                       | 18       | Forward Voltage: 2–2.2V, 20mA            |    ₹5 each        | Local electronics store         |
| Resistors (1kΩ, 1/4W)          | 3        | ±5% tolerance carbon film                |    ₹2 each        | Local electronics store         |
| Active Buzzer                  | 1        | 3–5V operating voltage                   |     ₹40           | Local electronics store         |
| Breadboard (830 points)        | 1        | Standard solderless                      |      ₹180         | Local electronics store         |
| Jumper Wires (M-M)             | 1 set    | 20–30 wires                              |     ₹120          | Local electronics store         |
| USB Cable (Micro-USB)          | 1        | 5V power supply                          |     ₹100          | Local electronics store         |

**Total Estimated Cost:** ₹[Amount]

#### Assembly Instructions

**Prepare the Workspace**
Place the ESP32 board on the breadboard.
Ensure the board is positioned so both sides of GPIO pins are accessible.

**Create the 3×6 LED Matrix**
Arrange 18 LEDs in a grid of 3 rows × 6 columns.
Connect the anodes (positive legs) of each row together horizontally.
Connect the cathodes (negative legs) of each column together vertically.

**Connect Row Lines (Positive)**
Connect each of the 3 row lines to the ESP32 GPIO pins through 1kΩ resistors (one resistor per row).
**Connect Column Lines (Negative)**
Connect each of the 6 column lines directly to dedicated ESP32 GPIO pins.

**Connect the Buzzer**
Connect the positive terminal of the active buzzer to GPIO 15.
Connect the negative terminal to GND.

**Establish Common Ground**

Ensure all GND connections (LED matrix, buzzer, ESP32) are connected to a common ground rail on the breadboard.

**Power the System**
Connect the ESP32 to a 5V USB power source.
Verify power indicator LED on ESP32 turns ON.

**Upload Firmware**

Connect ESP32 to your computer.
Upload the program that controls LED multiplexing and buzzer alerts.
Test each row and column to confirm correct LED activation.


## Project Demo

### Video
https://drive.google.com/drive/folders/1iY16gzxxFUQbxXte9GzcVOZMLpKaO7ag
---

## AI Tools Used 

If you used AI tools during development, document them here for transparency:

**Tool Used:**  ChatGPT, Claude 

**Purpose:** [What you used it for]
- Generated Flutter UI components and page structure
- Designed the app theme (colors, typography, card styles)
- Created step-by-step implementation prompts for each screen
- Debugging assistance for state management and widget layout
- Code review and UI polish suggestions


**Key Prompts Used:**
- "Create a Flutter mobile app with a healthcare theme using deep green, cream background, and muted yellow accent"
- "Build a day selector with 7 toggleable chips that highlight in dark green when selected"
- "Create 3 medicine section cards (Morning, Noon, Night) each with a time picker, medicine name input, dosage input, and before/after food toggle"
- "Add a floating + Add Reminder button with StadiumBorder shape that navigates to the Add Reminder page"
- "Implement a success animation with scale transition and floating SnackBar after saving a reminder"

**Percentage of AI-generated code:** 60%

**Human Contributions:**
- Problem identification and overall project concept
- Hardware architecture design (ESP32 + RTC + LED + Buzzer circuit)
- Deciding app structure, navigation flow, and feature scope
- Integration of Flutter app with ESP32 over WiFi
- Real device testing and debugging
- UI/UX design decisions and color scheme selection
- Customizing and fixing AI-generated code to match actual requirements


---

## Team Contributions

- Blessy Mol Charls [Flutter development, UI/UX, Hive integration,BLE logic]
- Niharika C [Hardware design, ESP32 firmware,Documentation]
---

## License
This project is licensed under the MIT License.
