#include <ArduinoJson.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <LittleFS.h>
#include <WiFi.h>
#include <time.h>

// --- HARDWARE PINS ---
// Rows (3)
const int rowPins[3] = {25, 26, 27};
// Columns (6)
const int colPins[6] = {14, 12, 13, 23, 22, 21};
// Buzzer
const int buzzerPin = 4;

// --- WIFI & NTP ---
const char *ssid = "1234";
const char *password = "87654321";
const char *ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 19800; // +5:30 for example, adjust as needed
const int daylightOffset_sec = 0;

unsigned long lastNtpSync = 0;
const unsigned long NTP_SYNC_INTERVAL = 60000; // 60s

// --- BLE ---
#define SERVICE_UUID "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define CHAR_READ_UUID "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define CHAR_WRITE_UUID "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
#define CHAR_NOTIFY_UUID "6e400004-b5a3-f393-e0a9-e50e24dcca9e"

BLEServer *pServer = NULL;
BLECharacteristic *pReadChar = NULL;
BLECharacteristic *pWriteChar = NULL;
BLECharacteristic *pNotifyChar = NULL;
bool deviceConnected = false;

// --- SCHEDULER ---
struct SlotStatus {
  bool triggeredToday;
};
SlotStatus slotStates[3][6]; // Track if triggered today

String scheduleJson = "{}"; // In-memory cache

// LED Alert state
bool isAlerting = false;
unsigned long alertStartTime = 0;
int alertRow = -1;
int alertCol = -1;

void loadSchedule() {
  if (LittleFS.exists("/schedule.json")) {
    File file = LittleFS.open("/schedule.json", "r");
    if (file) {
      scheduleJson = file.readString();
      file.close();
      Serial.println("Loaded schedule.json");
    }
  } else {
    scheduleJson = "{\"Monday\":[],\"Tuesday\":[],\"Wednesday\":[]}";
    saveSchedule();
  }
}

void saveSchedule() {
  File file = LittleFS.open("/schedule.json", "w");
  if (file) {
    file.print(scheduleJson);
    file.close();
    Serial.println("Saved schedule.json");
  }
}

void updateScheduleFromJson(String json) {
  // Parse incoming individual slot update or full update
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, json);

  if (error) {
    Serial.println("Failed to parse incoming BLE JSON");
    return;
  }

  // Here we assume it's a single slot update as per prompt:
  // { "day":"Monday", "slot":2, "slotName":"Morning After Food",
  // "medicine":"Metformin", "dosage":"1", "time":"09:30" }
  if (doc.containsKey("day") && doc.containsKey("slot")) {
    String day = doc["day"].as<String>();
    int slotIndex = doc["slot"].as<int>() - 1; // UI is 1-6, Array is 0-5

    // We need to parse the existing full schedule to update the specific
    // day/slot
    DynamicJsonDocument fullSchedule(4096);
    deserializeJson(fullSchedule, scheduleJson);

    // Ensure day array exists
    if (!fullSchedule.containsKey(day)) {
      fullSchedule.createNestedArray(day);
    }

    JsonArray dayArray = fullSchedule[day].as<JsonArray>();

    // Find if slot exists and replace, else append
    bool found = false;
    for (JsonObject obj : dayArray) {
      if (obj["slot"] == doc["slot"]) {
        obj["time"] = doc["time"];
        obj["medicine"] = doc["medicine"];
        obj["dosage"] = doc["dosage"];
        obj["slotName"] = doc["slotName"];
        found = true;
        break;
      }
    }

    if (!found) {
      dayArray.add(doc);
    }

    String updatedJson;
    serializeJson(fullSchedule, updatedJson);
    scheduleJson = updatedJson;
    saveSchedule();

    // Setup Read Characteristic with new full json
    pReadChar->setValue(scheduleJson.c_str());

    // Notify status
    if (deviceConnected) {
      pNotifyChar->setValue("{\"status\":\"schedule_updated\"}");
      pNotifyChar->notify();
    }

    Serial.println("Schedule updated via BLE");
  }
}

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) { deviceConnected = true; };
  void onDisconnect(BLEServer *pServer) {
    deviceConnected = false;
    pServer->getAdvertising()->start();
  }
};

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    std::string rxValue = pCharacteristic->getValue();
    if (rxValue.length() > 0) {
      Serial.println("Received BLE Write:");
      String jsonStr = "";
      for (int i = 0; i < rxValue.length(); i++) {
        jsonStr += rxValue[i];
      }
      Serial.println(jsonStr);
      updateScheduleFromJson(jsonStr);
    }
  }
};

void initBLE() {
  BLEDevice::init("MedAlert");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pReadChar = pService->createCharacteristic(CHAR_READ_UUID,
                                             BLECharacteristic::PROPERTY_READ);
  pReadChar->setValue(scheduleJson.c_str());

  pWriteChar = pService->createCharacteristic(
      CHAR_WRITE_UUID, BLECharacteristic::PROPERTY_WRITE);
  pWriteChar->setCallbacks(new MyCallbacks());

  pNotifyChar = pService->createCharacteristic(
      CHAR_NOTIFY_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  pNotifyChar->addDescriptor(new BLE2902());

  pService->start();
  pServer->getAdvertising()->start();
  Serial.println("BLE Started");
}

void setup() {
  Serial.begin(115200);

  // Init Pins
  for (int i = 0; i < 3; i++) {
    pinMode(rowPins[i], OUTPUT);
    digitalWrite(rowPins[i], LOW);
  }
  for (int i = 0; i < 6; i++) {
    pinMode(colPins[i], OUTPUT);
    digitalWrite(colPins[i], LOW); // Assuming common cathode or similar setup.
                                   // If multiplexing, adjust HIGH/LOW logic.
  }
  pinMode(buzzerPin, OUTPUT);
  digitalWrite(buzzerPin, LOW);

  // Init FS
  if (!LittleFS.begin(true)) {
    Serial.println("LittleFS Mount Failed");
    return;
  }
  loadSchedule();

  // Connect WiFi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected.");
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
    lastNtpSync = 0; // Trigger sync
  }

  // Init BLE
  initBLE();
}

void syncNtp() {
  if (WiFi.status() == WL_CONNECTED) {
    unsigned long now = millis();
    if (now - lastNtpSync > NTP_SYNC_INTERVAL || lastNtpSync == 0) {
      configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
      lastNtpSync = now;
      Serial.println("NTP sync request sent");
      if (deviceConnected && pNotifyChar) {
        pNotifyChar->setValue("{\"status\":\"time_synced\"}");
        pNotifyChar->notify();
      }
    }
  }
}

int getDayIndex(String dayName) {
  if (dayName == "Monday")
    return 0;
  if (dayName == "Tuesday")
    return 1;
  if (dayName == "Wednesday")
    return 2;
  return -1;
}

String getCurrentDayName(int wday) {
  // wday: 0=Sunday, 1=Monday, ...
  if (wday == 1)
    return "Monday";
  if (wday == 2)
    return "Tuesday";
  if (wday == 3)
    return "Wednesday";
  return "Unknown";
}

void checkSchedule() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return;
  }

  char timeStr[6];
  strftime(timeStr, sizeof(timeStr), "%H:%M", &timeinfo);
  String currentHHMM = String(timeStr);

  // Reset triggers at midnight (when HH:MM is 00:00)
  static bool midnightResetDone = false;
  if (currentHHMM == "00:00") {
    if (!midnightResetDone) {
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 6; c++) {
          slotStates[r][c].triggeredToday = false;
        }
      }
      midnightResetDone = true;
      Serial.println("Reset triggers for new day.");
    }
  } else {
    midnightResetDone = false;
  }

  if (isAlerting)
    return; // Don't trigger new while already alerting

  DynamicJsonDocument doc(4096);
  if (!deserializeJson(doc, scheduleJson)) {
    String dayName = getCurrentDayName(timeinfo.tm_wday);
    if (doc.containsKey(dayName)) {
      JsonArray dayArray = doc[dayName].as<JsonArray>();
      for (JsonObject obj : dayArray) {
        String t = obj["time"].as<String>();
        int slot = obj["slot"].as<int>() - 1; // 0-based index
        int dIdx = getDayIndex(dayName);

        if (slot >= 0 && slot < 6 && dIdx >= 0 && dIdx < 3 &&
            t == currentHHMM) {
          if (!slotStates[dIdx][slot].triggeredToday) {
            // FIRE ALERT
            isAlerting = true;
            alertStartTime = millis();
            alertRow = dIdx;
            alertCol = slot;
            slotStates[dIdx][slot].triggeredToday = true;

            Serial.printf("Triggered alert for %s slot %d at %s\n",
                          dayName.c_str(), slot + 1, t.c_str());

            if (deviceConnected && pNotifyChar) {
              pNotifyChar->setValue("{\"status\":\"reminder_triggered\"}");
              pNotifyChar->notify();
            }
          }
        }
      }
    }
  }
}

void handleAlertMultiplexing() {
  if (isAlerting) {
    if (millis() - alertStartTime < 10000) { // 10 seconds duration
      // Buzzer ON
      digitalWrite(buzzerPin, HIGH);

      // Multiplexing simple implementation for a single active LED
      // For active high rows and active low cols as an example
      for (int i = 0; i < 3; i++)
        digitalWrite(rowPins[i], LOW);
      for (int i = 0; i < 6; i++)
        digitalWrite(colPins[i], HIGH);

      // Turn on specific LED
      digitalWrite(rowPins[alertRow], HIGH);
      digitalWrite(colPins[alertCol], LOW);
    } else {
      isAlerting = false;
      digitalWrite(buzzerPin, LOW);
      // Turn off all
      for (int i = 0; i < 3; i++)
        digitalWrite(rowPins[i], LOW);
      for (int i = 0; i < 6; i++)
        digitalWrite(colPins[i], LOW); // or HIGH depending on wiring
    }
  }
}

unsigned long lastSecTick = 0;

void loop() {
  unsigned long now = millis();

  if (now - lastSecTick >= 1000) {
    lastSecTick = now;
    syncNtp();
    checkSchedule();
  }

  // Fast multiplexing refresh for LED if alerting
  handleAlertMultiplexing();
}
