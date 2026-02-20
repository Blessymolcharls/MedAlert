#include <ArduinoJson.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <LittleFS.h>
#include <WiFi.h>
#include <time.h>

const char *ssid = "1234";
const char *password = "87654321 ";

const char *ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 19800; // +05:30 default
const int daylightOffset_sec = 0;

#define SERVICE_UUID "7f6d0001-4b5c-4a7a-9c7e-9a2f3b6c1d10"
#define CHARACTERISTIC_UUID "7f6d0002-4b5c-4a7a-9c7e-9a2f3b6c1d10"

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Hardware Config (Adjust pins to match MedAlert hardware)
const int rowPins[3] = {25, 26, 27};
const int colPins[6] = {14, 12, 13, 23, 22, 21};
const int buzzerPin = 19;

struct Slot {
  bool active;
  int hour;
  int minute;
  bool triggeredToday;
};

Slot scheduleMatrix[3][6];

unsigned long lastTimeSync = 0;
const unsigned long syncInterval = 60000; // 60 seconds

unsigned long lastScheduleCheck = 0;

int activeLedRow = -1;
int activeLedCol = -1;
unsigned long buzzerStartTime = 0;
bool buzzerActive = false;
const unsigned long buzzerDuration = 10000;

int testLedRow = -1;
int testLedCol = -1;
unsigned long testLedStartTime = 0;
bool testLedActive = false;

String inputString = "";
bool stringComplete = false;

// Function declarations
void printEvent(String msg);
void saveSchedule();
void loadSchedule();
void sendDataOverBLE();
void turnOnLed(int row, int col);
void turnOffLed();
void beepBuzzer(bool state);
bool syncTime();
void handleBLECommand(String cmd);
void parseSerialCommand();

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    deviceConnected = true;
    printEvent("BLE connected");
  };

  void onDisconnect(BLEServer *pServer) {
    deviceConnected = false;
    printEvent("BLE disconnected");
  }
};

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
    String rxValue = pChar->getValue().c_str();

    if (rxValue.length() > 0) {
      printEvent("Command received: " + rxValue);
      handleBLECommand(rxValue);
    }
  }
};

void printEvent(String msg) { Serial.println("[EVENT] " + msg); }

void turnOnLed(int row, int col) {
  turnOffLed();
  if (row >= 0 && row < 3 && col >= 0 && col < 6) {
    digitalWrite(rowPins[row], HIGH); // Assuming Rows source current
    digitalWrite(colPins[col], LOW);  // Assuming Cols sink current
    printEvent("LED turned ON -> Row: " + String(row) +
               ", Col: " + String(col));
  }
}

void turnOffLed() {
  for (int i = 0; i < 3; i++)
    digitalWrite(rowPins[i], LOW);
  for (int i = 0; i < 6; i++)
    digitalWrite(colPins[i], HIGH);
}

void beepBuzzer(bool state) {
  // Use LOW for ON, HIGH for OFF assuming active-low buzzer behavior.
  digitalWrite(buzzerPin, state ? LOW : HIGH);
  if (state) {
    printEvent("Buzzer ringing ON.");
  } else {
    printEvent("Buzzer turned OFF.");
  }
}

bool syncTime() {
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  struct tm timeinfo;
  if (getLocalTime(&timeinfo, 5000)) {
    printEvent("Time sync success. Current time: " + String(timeinfo.tm_hour) +
               ":" + String(timeinfo.tm_min));
    return true;
  }
  printEvent("Time sync failed");
  return false;
}

void handleBLECommand(String cmd) {
  DynamicJsonDocument doc(1024);
  DeserializationError error = deserializeJson(doc, cmd);
  if (error) {
    printEvent("Failed to parse command");
    return;
  }

  String command = doc["cmd"].as<String>();

  if (command == "SET") {
    if (!doc.containsKey("r") || !doc.containsKey("c") ||
        !doc.containsKey("time"))
      return;

    int r = doc["r"].as<int>();
    int c = doc["c"].as<int>();
    String t = doc["time"].as<String>();

    if (r >= 0 && r < 3 && c >= 0 && c < 6 && t.indexOf(":") != -1) {
      int sep = t.indexOf(":");
      int h = t.substring(0, sep).toInt();
      int m = t.substring(sep + 1).toInt();

      scheduleMatrix[r][c].active = true;
      scheduleMatrix[r][c].hour = h;
      scheduleMatrix[r][c].minute = m;
      scheduleMatrix[r][c].triggeredToday = false;

      printEvent("Added/Updated new time limit. Row: " + String(r) +
                 " Col: " + String(c) + " Time: " + t);
      saveSchedule();
    }
  } else if (command == "GET_ALL") {
    printEvent("GET_ALL command received. Sending full schedule...");
    sendDataOverBLE();
  }
}

void saveSchedule() {
  DynamicJsonDocument doc(1024);
  JsonArray arr = doc.createNestedArray("schedule");

  for (int r = 0; r < 3; r++) {
    for (int c = 0; c < 6; c++) {
      if (scheduleMatrix[r][c].active) {
        JsonObject obj = arr.createNestedObject();
        obj["r"] = r;
        obj["c"] = c;
        char timeStr[6];
        sprintf(timeStr, "%02d:%02d", scheduleMatrix[r][c].hour,
                scheduleMatrix[r][c].minute);
        obj["time"] = timeStr;
      }
    }
  }

  File file = LittleFS.open("/schedule.json", "w");
  if (!file) {
    printEvent("Failed to open LittleFS for writing.");
    return;
  }
  serializeJson(doc, file);
  file.close();
  printEvent("Schedule saved successfully to LittleFS.");
}

void loadSchedule() {
  File file = LittleFS.open("/schedule.json", "r");
  if (!file) {
    printEvent(
        "No schedule found on LittleFS. Proceeding with empty schedule.");
    return;
  }

  DynamicJsonDocument doc(1024);
  DeserializationError err = deserializeJson(doc, file);
  file.close();

  if (err) {
    printEvent("Failed to read schedule from LittleFS.");
    return;
  }

  JsonArray arr = doc["schedule"].as<JsonArray>();
  for (JsonObject obj : arr) {
    int r = obj["r"];
    int c = obj["c"];
    String t = obj["time"].as<String>();
    int sep = t.indexOf(":");
    int h = t.substring(0, sep).toInt();
    int m = t.substring(sep + 1).toInt();
    scheduleMatrix[r][c].active = true;
    scheduleMatrix[r][c].hour = h;
    scheduleMatrix[r][c].minute = m;
    scheduleMatrix[r][c].triggeredToday = false;
  }
  printEvent("Schedule loaded from LittleFS.");
}

void sendDataOverBLE() {
  if (!deviceConnected)
    return;

  DynamicJsonDocument doc(2048);
  doc["cmd"] = "DATA";
  JsonObject payload = doc.createNestedObject("payload");
  JsonArray arr = payload.createNestedArray("schedule");

  for (int r = 0; r < 3; r++) {
    for (int c = 0; c < 6; c++) {
      if (scheduleMatrix[r][c].active) {
        JsonObject obj = arr.createNestedObject();
        obj["r"] = r;
        obj["c"] = c;
        char timeStr[6];
        sprintf(timeStr, "%02d:%02d", scheduleMatrix[r][c].hour,
                scheduleMatrix[r][c].minute);
        obj["time"] = timeStr;
      }
    }
  }

  String output;
  serializeJson(doc, output);

  // Note: Standard BLE packet size is restricted. For large JSON payloads, MTU
  // needs to be raised or payload chunked. Here we assume MTU is negotiated
  // higher by the client (e.g. 512 bytes).
  pCharacteristic->setValue(output.c_str());
  pCharacteristic->notify();
  printEvent("Data sent over BLE Notification.");
}

void parseSerialCommand() {
  inputString.trim();
  int commaIndex = inputString.indexOf(',');
  if (commaIndex > 0) {
    int r = inputString.substring(0, commaIndex).toInt();
    int c = inputString.substring(commaIndex + 1).toInt();

    if (r >= 0 && r < 3 && c >= 0 && c < 6) {
      testLedRow = r;
      testLedCol = c;
      testLedStartTime = millis();
      testLedActive = true;

      turnOnLed(r, c);
      printEvent("Test command via Serial -> Row: " + String(r) +
                 " Col: " + String(c) + " (ON for 5s)");
    } else {
      printEvent(
          "Error: Invalid row/col test coordinate. Row (0-2), Col (0-5).");
    }
  }
}

void setup() {
  Serial.begin(115200);
  while (!Serial)
    ;
  delay(1000); // Give serial monitor time to connect

  printEvent("MedAlert Dev Board Booting...");

  for (int i = 0; i < 3; i++)
    pinMode(rowPins[i], OUTPUT);
  for (int i = 0; i < 6; i++)
    pinMode(colPins[i], OUTPUT);
  pinMode(buzzerPin, OUTPUT);
  turnOffLed();
  beepBuzzer(false);

  // Initialize LittleFS
  if (!LittleFS.begin(true)) {
    printEvent("LittleFS Mount Failed. Formatting...");
    return;
  }

  // Load persistence
  for (int r = 0; r < 3; r++) {
    for (int c = 0; c < 6; c++) {
      scheduleMatrix[r][c].active = false;
      scheduleMatrix[r][c].triggeredToday = false;
    }
  }
  loadSchedule();

  // WiFi Setup (Only for NTP)
  WiFi.begin(ssid, password);
  Serial.print("[EVENT] Connecting to WiFi");
  for (int i = 0; i < 20 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    printEvent("WiFi Connected.");
    if (syncTime()) {
      lastTimeSync = millis();
    }
  } else {
    printEvent(
        "WiFi Connect Failed. Continuing with last known or un-synced time.");
  }

  // BLE Setup
  BLEDevice::init("MedAlert");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ |
                               BLECharacteristic::PROPERTY_WRITE |
                               BLECharacteristic::PROPERTY_NOTIFY);

  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new MyCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(
      0x0); // Functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
  printEvent("BLE Advertising Started. Device is Ready.");
}

void loop() {
  unsigned long currentMillis = millis();

  // Handle BLE disconnects to restart advertising
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    printEvent("BLE Advertising Restarted");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  // Handling manual Serial inputs to test LEDs
  while (Serial.available()) {
    char inChar = (char)Serial.read();
    if (inChar == '\n' || inChar == '\r') {
      if (inputString.length() > 0) {
        stringComplete = true;
      }
    } else {
      inputString += inChar;
    }
  }

  if (stringComplete) {
    parseSerialCommand();
    inputString = "";
    stringComplete = false;
  }

  // Handle Test LED duration logic
  if (testLedActive) {
    if (currentMillis - testLedStartTime >= 5000) {
      turnOffLed();
      testLedActive = false;
      printEvent("Test LED auto turned OFF after 5 seconds.");
    }
  }

  // Time Sync every 60s
  if (currentMillis - lastTimeSync >= syncInterval) {
    lastTimeSync = currentMillis;
    if (WiFi.status() == WL_CONNECTED) {
      syncTime();
    }
  }

  // Hardware Buzzer/Alarm handling asynchronously
  if (buzzerActive) {
    if (currentMillis - buzzerStartTime < buzzerDuration) {
      // Stay ON continuously for the duration (already turned ON at trigger
      // time)
    } else {
      buzzerActive = false;
      beepBuzzer(false);
      printEvent("Slot event complete. Turning OFF buzzer/LED.");
      if (!testLedActive) {
        turnOffLed();
      }
      activeLedRow = -1;
      activeLedCol = -1;
    }
  }

  // Scheduler Loop, executes roughly every 1000 ms
  if (currentMillis - lastScheduleCheck >= 1000) {
    lastScheduleCheck = currentMillis;

    struct tm timeinfo;
    if (getLocalTime(&timeinfo, 10)) {
      int hr = timeinfo.tm_hour;
      int mn = timeinfo.tm_min;

      // Reset daily triggers at exact midnight
      if (hr == 0 && mn == 0) {
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 6; c++) {
            if (scheduleMatrix[r][c].triggeredToday) {
              scheduleMatrix[r][c].triggeredToday = false;
            }
          }
        }
      }

      // Check current time against matrix
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 6; c++) {
          if (scheduleMatrix[r][c].active &&
              !scheduleMatrix[r][c].triggeredToday) {
            if (scheduleMatrix[r][c].hour == hr &&
                scheduleMatrix[r][c].minute == mn) {
              scheduleMatrix[r][c].triggeredToday = true;

              // Set global reference to active alert
              activeLedRow = r;
              activeLedCol = c;

              printEvent("Slot triggered! Time matched for Row: " + String(r) +
                         " Col: " + String(c));

              if (!testLedActive) {
                turnOnLed(activeLedRow, activeLedCol);
              }

              buzzerStartTime = currentMillis;
              buzzerActive = true;
              beepBuzzer(true);
            }
          }
        }
      }
    }
  }
}
