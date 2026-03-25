/**
 * CareSoul ESP32 – Medicine Reminder with Offline RTC Support
 * ============================================================
 * 1. Hybrid WiFi/Offline mode.
 * 2. Uses DS3231 RTC to keep time reliably without internet.
 * 3. Uses LittleFS to locally cache TTS MP3s downloaded from backend.
 * 4. Uses Preferences to persistently save the reminder schedule.
 * 5. Plays TTS perfectly on time, completely offline!
 *
 * Hardware:
 *   - ESP32 (any variant)
 *   - DS3231 RTC Module (SDA to GPIO 21, SCL to GPIO 22 on standard ESP32)
 *   - MAX98357A I2S amplifier:
 *       BCLK  → GPIO 27
 *       LRC   → GPIO 26
 *       DIN   → GPIO 25
 *   - Speaker
 *
 * Libraries required:
 *   - ArduinoJson
 *   - ESP32-audioI2S
 *   - RTClib (by Adafruit)
 *
 * IMPORTANT: In Arduino IDE -> Tools -> Partition Scheme:
 * Choose "Default 4MB with spiffs (1.2MB APP/1.5MB SPIFFS)" so LittleFS has space.
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "Audio.h"
#include <Wire.h>
#include "RTClib.h"
#include <Preferences.h>
#include <LittleFS.h>
#include "time.h"

// ──────────────────────────────────────────────
// CONFIGURE THESE
// ──────────────────────────────────────────────
const char* WIFI_SSID     = "OnePlus Nord";
const char* WIFI_PASSWORD = "11111111";
const char* SERVER_IP     = "10.152.144.17";
const int   SERVER_PORT   = 8000;
const char* DEVICE_ID     = "ESP32-001";

// How often to poll the backend and sync (milliseconds)
const unsigned long POLL_INTERVAL_MS = 60000;  // 60 seconds

// I2S pins for MAX98357A (User physically wired to 27, 26, 25)
#define I2S_BCLK  27
#define I2S_LRC   26
#define I2S_DOUT  25
// ──────────────────────────────────────────────

Audio audio;
RTC_DS3231 rtc;
Preferences preferences;

unsigned long lastPollTime = 0;
int lastPlayedMinute = -1;

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n\n[CareSoul] Booting Hybrid Offline Mode...");

  // Init RTC (DS3231)
  if (!rtc.begin()) {
    Serial.println("[RTC] Couldn't find DS3231 RTC!");
  } else {
    if (rtc.lostPower()) {
      Serial.println("[RTC] Lost power, let's wait for NTP sync to set time!");
    } else {
      DateTime now = rtc.now();
      Serial.printf("[RTC] Current Time: %02d:%02d\n", now.hour(), now.minute());
    }
  }

  // Init Storage
  preferences.begin("caresoul", false);
  if (!LittleFS.begin(true)) {
    Serial.println("[Storage] LittleFS Mount Failed! (Check Partition Scheme)");
  } else {
    Serial.println("[Storage] LittleFS Mount Successful.");
  }

  // Init I2S audio
  audio.setPinout(I2S_BCLK, I2S_LRC, I2S_DOUT);
  // Lowered the volume from 15 to 5 to prevent Brownout Resets on chargers
  audio.setVolume(15);  // 0..21

  // Connect WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("[WiFi] Connecting");
  int wifi_attempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifi_attempts < 10) {
    delay(500);
    Serial.print(".");
    wifi_attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    
    // Sync NTP time (IST = GMT+5:30 = 19800 seconds)
    configTime(19800, 0, "pool.ntp.org", "time.nist.gov");
    syncRTCfromNTP();

    // Poll schedule immediately
    pollReminders();
    lastPollTime = millis();
  } else {
    Serial.println("\n[WiFi] Failed to connect. Operating completely OFFLINE!");
  }
}

void loop() {
  audio.loop();

  // Background WiFi sync routine
  if (millis() - lastPollTime >= POLL_INTERVAL_MS) {
    lastPollTime = millis();
    
    // If WiFi is disconnected, try to reconnect first!
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] Disconnected. Attempting to reconnect...");
      WiFi.disconnect();
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      
      // Wait briefly for connection
      int attempts = 0;
      while (WiFi.status() != WL_CONNECTED && attempts < 10) {
        delay(500);
        attempts++;
      }
    }

    // Only poll backend if we successfully connected
    if (WiFi.status() == WL_CONNECTED) {
      pollReminders();
      syncRTCfromNTP(); // keep RTC accurate
    } else {
      Serial.println("[WiFi] Still offline. using cached schedule.");
    }
  }

  // Precise RTC Offline Trigger Logic
  DateTime now = rtc.now();
  if (now.minute() != lastPlayedMinute) {
    // A new minute has rolled over, check if a reminder is due!
    checkAndPlayReminders(now.hour(), now.minute());
    lastPlayedMinute = now.minute();
  }
}

// ──────────────────────────────────────────────
// BACKEND SYNC AND MP3 CACHING (WIFI ONLY)
// ──────────────────────────────────────────────
void pollReminders() {
  String url = String("http://") + SERVER_IP + ":" + SERVER_PORT + "/device/pending/" + DEVICE_ID;
  Serial.printf("[Sync] Fetching schedule from: %s\n", url.c_str());

  HTTPClient http;
  http.begin(url);
  int httpCode = http.GET();

  if (httpCode != HTTP_CODE_OK) {
    Serial.printf("[Sync] Error: %d\n", httpCode);
    http.end();
    return;
  }

  String payload = http.getString();
  http.end();
  
  // Save full schedule to persistent storage for offline use
  preferences.putString("schedule", payload);
  Serial.println("[Sync] Saved schedule to NVS.");

  // Parse JSON to download missing MP3s to LittleFS
  StaticJsonDocument<2048> doc;
  DeserializationError err = deserializeJson(doc, payload);
  if (err) return;

  JsonArray actions = doc["actions"];
  for (JsonObject action : actions) {
    const char* medicine = action["medicine_name"] | "Unknown";
    const char* dosage   = action["dosage"]        | "";
    
    // Format filename safe for LittleFS (include dosage to prevent old cache playing)
    String safeName = String(medicine) + "_" + String(dosage);
    safeName.replace(" ", "_");
    String filename = "/" + safeName + ".mp3";

    // If MP3 isn't cached locally yet, download it!
    if (!LittleFS.exists(filename)) {
      String sentence = String("Time to take ") + medicine;
      if (strlen(dosage) > 0) {
        sentence += String(", ") + dosage;
      }
      sentence += ".";

      Serial.printf("[Cache] Downloading TTS for: %s\n", medicine);
      downloadTTS(sentence, filename);
    }
  }
}

void downloadTTS(String text, String filename) {
  String encoded = "";
  for (int i = 0; i < text.length(); i++) {
    char c = text[i];
    if (c == ' ') encoded += "%20";
    else if (c == ',') encoded += "%2C";
    else if (c == '.') encoded += "%2E";
    else encoded += c;
  }

  String ttsUrl = String("http://") + SERVER_IP + ":" + SERVER_PORT + "/device/tts?text=" + encoded;
  
  HTTPClient http;
  http.begin(ttsUrl);
  int httpCode = http.GET();
  if (httpCode == HTTP_CODE_OK) {
    File f = LittleFS.open(filename, "w");
    if (f) {
      http.writeToStream(&f);
      f.close();
      Serial.printf("[Cache] Successfully saved %s\n", filename.c_str());
    } else {
      Serial.println("[Cache] File open failed!");
    }
  } else {
    Serial.printf("[Cache] HTTP Error %d on TTS download\n", httpCode);
  }
  http.end();
}

void syncRTCfromNTP() {
  struct tm timeinfo;
  if (getLocalTime(&timeinfo, 5000)) {
    rtc.adjust(DateTime(timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
                        timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec));
    Serial.printf("[RTC] Synced from NTP: %02d:%02d\n", timeinfo.tm_hour, timeinfo.tm_min);
  }
}

// ──────────────────────────────────────────────
// OFFLINE TRIGGER LOGIC
// ──────────────────────────────────────────────
void checkAndPlayReminders(int currentHour, int currentMinute) {
  // Read offline schedule from persistent storage
  String payload = preferences.getString("schedule", "{}");
  Serial.printf("[RTC] Clock tick %02d:%02d. Checking saved schedule: %s\n", currentHour, currentMinute, payload.c_str());

  StaticJsonDocument<2048> doc;
  if (deserializeJson(doc, payload)) {
    Serial.println("[Trigger] Failed to parse schedule JSON.");
    return;
  }

  JsonArray actions = doc["actions"];
  for (JsonObject action : actions) {
    const char* time_of_day = action["time_of_day"] | "";
    if (strlen(time_of_day) == 0) continue;

    // Parse "HH:MM" e.g. "08:00"
    int h = String(time_of_day).substring(0, 2).toInt();
    int m = String(time_of_day).substring(3, 5).toInt();
    
    Serial.printf("[Trigger] Evaluating %s. Scheduled %02d:%02d vs Current %02d:%02d\n", 
                  (const char*)(action["medicine_name"]|"Unknown"), h, m, currentHour, currentMinute);

    // Trigger exactly if hour and minute match!
    if (h == currentHour && m == currentMinute) {
      const char* medicine = action["medicine_name"] | "Unknown";
      const char* dosage = action["dosage"] | "";
      String safeName = String(medicine) + "_" + String(dosage);
      safeName.replace(" ", "_");
      String filename = "/" + safeName + ".mp3";

      if (LittleFS.exists(filename)) {
        Serial.printf("[Trigger] Play time! Medicine: %s\n", medicine);
        
        // Play the cached MP3 EXACTLY twice, as requested.
        for (int i = 0; i < 2; i++) {
          audio.connecttoFS(LittleFS, filename.c_str());
          
          unsigned long start_wait = millis();
          while (!audio.isRunning() && (millis() - start_wait < 5000)) {
            audio.loop();
          }
          
          // Play until finished
          while (audio.isRunning()) {
            audio.loop();
          }
          delay(2000); // 2 second gap between repeats
        }
      } else {
        Serial.printf("[Trigger] ERROR: MP3 %s missing from LittleFS!\n", filename.c_str());
      }
    }
  }
}

// ──────────────────────────────────────────────
// AUDIO CALLBACKS
// ──────────────────────────────────────────────
void audio_info(const char* info) {
  // Serial.printf("[Audio] %s\n", info);
}
void audio_eof_mp3(const char* info) {
  Serial.printf("[Audio] Finished playing cached MP3.\n");
}
