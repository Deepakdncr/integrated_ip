/**
 * CareSoul ESP32 – Unified Multi-Module Reminder System
 * ======================================================
 * Handles: Medicine | Voice | Habit | Music
 * Priority: Medicine(1) > Voice(2) > Habit(3) > Music(4)
 *
 * Hardware:
 *   - ESP32 (any variant)
 *   - DS3231 RTC Module (SDA=GPIO21, SCL=GPIO22)
 *   - MAX98357A I2S amplifier:
 *       BCLK  → GPIO 27
 *       LRC   → GPIO 26
 *       DIN   → GPIO 25
 *   - MicroSD Card Module (default VSPI bus):
 *       MOSI  → GPIO 23
 *       MISO  → GPIO 19
 *       SCK   → GPIO 18
 *       CS    → GPIO  5
 *       VCC   → 5V (most modules need 5V, NOT 3.3V)
 *       GND   → GND
 *   - SOS System:
 *       Push Button → GPIO 33 (pulled up internally, press = GND)
 *       Active Buzzer → GPIO 32
 *   - Speaker
 *
 * SD Card:
 *   - Format: FAT32 (recommended)
 *   - Size: Any (8GB+ recommended for music caching)
 *   - Files are stored in the root "/" directory of the SD card
 *
 * Libraries required (install via Arduino Library Manager):
 *   - ArduinoJson (by Benoit Blanchon)
 *   - ESP32-audioI2S (by schreibfaul1)
 *   - RTClib (by Adafruit)
 *   - SD (built-in Arduino/ESP32 core)
 *   - SPI (built-in Arduino/ESP32 core)
 *
 * Partition Scheme: Default 4MB with SPIFFS or "Huge APP" (no SPIFFS needed)
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "Audio.h"
#include <Wire.h>
#include "RTClib.h"
#include <Preferences.h>
#include <SD.h>
#include <SPI.h>
#include "time.h"

// ──────────────────────────────────────────────
// CONFIGURE THESE
// ──────────────────────────────────────────────
const char* WIFI_SSID     = "OnePlus Nord";
const char* WIFI_PASSWORD = "11111111";
const char* SERVER_IP     = "10.223.245.17";
const int   SERVER_PORT   = 8000;
const char* DEVICE_ID     = "ESP32-001";

// Poll backend every 30 seconds
const unsigned long POLL_INTERVAL_MS = 30000;

// I2S pins for MAX98357A
#define I2S_BCLK  27
#define I2S_LRC   26
#define I2S_DOUT  25

// MAX98357A Shutdown/Enable pin  (active HIGH = enabled, LOW = muted/shutdown)
// Connect the SD pin of MAX98357A to this GPIO.
// If you haven't wired SD pin, set this to -1 and the amp stays always-on.
#define AMP_ENABLE_PIN  2

// SD Card – default VSPI pins (most widely tested, most compatible)
#define SD_CS     5
// VSPI default: MOSI=23, MISO=19, SCK=18 (no need to define, Arduino default)

// SOS Emergency System
#define SOS_BUTTON_PIN  33   // Push button (internal pull-up, press = LOW)
#define BUZZER_PIN      32   // Active buzzer
#define SOS_LED_PIN     4    // Red LED for visual indication
// ──────────────────────────────────────────────

Audio audio;
RTC_DS3231 rtc;
Preferences preferences;

bool sdCardReady = false;

// SOS state
volatile bool sosActive = false;
volatile bool pendingSOSStartNotify = false;
volatile bool pendingSOSStopNotify = false;
unsigned long lastButtonPress = 0;
const unsigned long DEBOUNCE_MS = 300;

unsigned long lastPollTime = 0;
int lastCheckedMinute = -1;
int lastCheckedHour   = -1;

// Forward declarations
void notifySOS(bool triggered);
bool checkSOSRemoteStop();

// ── Anti-pop helpers ──────────────────────────
// Mute the amplifier BEFORE I2S transients occur, then unmute AFTER I2S is stable.
void ampEnable(bool on) {
  if (AMP_ENABLE_PIN < 0) return;          // not wired – skip
  digitalWrite(AMP_ENABLE_PIN, on ? HIGH : LOW);
  if (on) delay(50);   // 50ms settling time after power-up
}

// Play a short burst of digital silence so the I2S DMA buffer
// contains only zeros when the decoder first starts sending real data.
// This prevents the amp from amplifying stale buffer garbage as a pop.
void flushI2Silence() {
  audio.setVolume(0);      // digital mute
  delay(60);               // let ~3+ DMA frames of zeros flow out
}

void sosNetworkTask(void * pvParameters) {
  unsigned long lastRemoteStopCheck = 0;
  for(;;) {
    if (pendingSOSStartNotify) {
      pendingSOSStartNotify = false;
      notifySOS(true);
    }
    if (pendingSOSStopNotify) {
      pendingSOSStopNotify = false;
      notifySOS(false);
    }
    
    // Remote stop checking 
    if (sosActive && WiFi.status() == WL_CONNECTED) {
      if (millis() - lastRemoteStopCheck > 5000) {
        lastRemoteStopCheck = millis();
        if (checkSOSRemoteStop()) {
          sosActive = false;
          digitalWrite(BUZZER_PIN, LOW);
          digitalWrite(SOS_LED_PIN, LOW);
          Serial.println("[SOS] ** STOPPED remotely from app **");
        }
      }
    }
    vTaskDelay(100 / portTICK_PERIOD_MS);
  }
}

// ──────────────────────────────────────────────
// SETUP
// ──────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(2000);  // Wait 2s so Serial Monitor can connect and show boot messages
  Serial.println("\n\n[CareSoul] Booting Unified System v3.2 (SOS Edition)...");
  Serial.println("[Boot] Initializing hardware...");

  // Init AMP enable/shutdown pin (mute amp during boot transients)
  if (AMP_ENABLE_PIN >= 0) {
    pinMode(AMP_ENABLE_PIN, OUTPUT);
    digitalWrite(AMP_ENABLE_PIN, LOW);  // amp OFF during setup
  }

  // Init SOS hardware
  pinMode(SOS_BUTTON_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(SOS_LED_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(SOS_LED_PIN, LOW);
  Serial.println("[SOS] Button=GPIO33, Buzzer=GPIO32, LED=GPIO4 – ready.");

  // Init RTC
  if (!rtc.begin()) {
    Serial.println("[RTC] DS3231 not found! Check wiring.");
  } else {
    if (rtc.lostPower()) {
      Serial.println("[RTC] Lost power – will sync from NTP.");
    } else {
      DateTime now = rtc.now();
      Serial.printf("[RTC] Current Time: %02d:%02d\n", now.hour(), now.minute());
    }
  }

  // Init NVS for settings (volume, schedule cache)
  preferences.begin("caresoul", false);

  // Init SD Card – default VSPI bus (most compatible)
  pinMode(SD_CS, OUTPUT);
  digitalWrite(SD_CS, HIGH);
  delay(200);  // Let SD card power up

  sdCardReady = false;
  // 16MHz was too fast for the physical wiring, dropping back to default (4MHz)
  for (int attempt = 1; attempt <= 3; attempt++) {
    Serial.printf("[SD] Init attempt %d of 3...\n", attempt);
    if (SD.begin(SD_CS)) {
      sdCardReady = true;
      break;
    }
    Serial.printf("[SD] Attempt %d failed.\n", attempt);
    delay(1000);  // 1 second between retries
  }

  if (!sdCardReady) {
    Serial.println("[SD] *** SD CARD MOUNT FAILED ***");
    Serial.println("[SD] Fix checklist:");
    Serial.println("     1. VCC → 5V (NOT 3.3V! Most modules need 5V)");
    Serial.println("     2. GND → GND");
    Serial.println("     3. MOSI → GPIO 23");
    Serial.println("     4. MISO → GPIO 19");
    Serial.println("     5. SCK  → GPIO 18");
    Serial.println("     6. CS   → GPIO 5");
    Serial.println("     7. SD card must be FAT32 (not exFAT)");
    Serial.println("     8. Try a different SD card if possible");
    Serial.println("[SD] System will stream audio directly (no caching).");
  } else {
    uint8_t cardType = SD.cardType();
    const char* typeStr = "UNKNOWN";
    if (cardType == CARD_MMC)  typeStr = "MMC";
    if (cardType == CARD_SD)   typeStr = "SD";
    if (cardType == CARD_SDHC) typeStr = "SDHC";
    Serial.printf("[SD] Card Type: %s\n", typeStr);
    uint64_t totalBytes = SD.totalBytes();
    uint64_t usedBytes  = SD.usedBytes();
    uint64_t freeBytes  = totalBytes - usedBytes;
    Serial.printf("[SD] Total: %llu MB | Used: %llu MB | Free: %llu MB\n",
                  totalBytes / (1024 * 1024),
                  usedBytes  / (1024 * 1024),
                  freeBytes  / (1024 * 1024));
    if (!SD.exists("/cache")) {
      SD.mkdir("/cache");
      Serial.println("[SD] Created /cache directory.");
    }
    Serial.println("[SD] Ready!");
  }

  // Init I2S audio
  audio.setPinout(I2S_BCLK, I2S_LRC, I2S_DOUT);
  // 40960 → library uses ~38KB usable RAM buffer (no PSRAM on this board).
  // Larger buffer = fewer SD read stalls = no INDATA_UNDERFLOW pops.
  audio.setBufsize(40960, 0);
  audio.setVolume(0);  // Start muted – will ramp up when actually playing

  // Enable amp now that I2S is configured and outputting silence
  delay(100);  // let DMA fill with zeros
  ampEnable(true);
  Serial.println("[Audio] I2S initialized, amp enabled.");

  // Connect WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("[WiFi] Connecting");
  int wifi_attempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifi_attempts < 15) {
    delay(500);
    Serial.print(".");
    wifi_attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    configTime(19800, 0, "pool.ntp.org", "time.nist.gov");  // IST = GMT+5:30
    syncRTCfromNTP();
    pollSchedule();
    lastPollTime = millis();
  } else {
    Serial.println("\n[WiFi] Offline – using cached schedule.");
  }

  // Start SOS network task on Core 0 (background) so main loop never blocks
  xTaskCreatePinnedToCore(
    sosNetworkTask, "SOS_Net_Task", 8192, NULL, 1, NULL, 0
  );
}

// ──────────────────────────────────────────────
// MAIN LOOP
// ──────────────────────────────────────────────
void loop() {
  audio.loop();

  // Periodic background sync
  if (millis() - lastPollTime >= POLL_INTERVAL_MS) {
    lastPollTime = millis();
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] Disconnected – reconnecting...");
      WiFi.disconnect();
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      int attempts = 0;
      while (WiFi.status() != WL_CONNECTED && attempts < 10) {
        delay(500);
        attempts++;
      }
    }
    // Auto-retry SD card if it failed at boot
    if (!sdCardReady) {
      Serial.println("[SD] Retrying SD card init...");
      if (SD.begin(SD_CS)) {
        sdCardReady = true;
        Serial.println("[SD] *** SD CARD MOUNTED ON RETRY! ***");
        uint64_t totalBytes = SD.totalBytes();
        uint64_t usedBytes  = SD.usedBytes();
        Serial.printf("[SD] Total: %llu MB | Free: %llu MB\n",
                      totalBytes / (1024*1024), (totalBytes-usedBytes) / (1024*1024));
        if (!SD.exists("/cache")) {
          SD.mkdir("/cache");
          Serial.println("[SD] Created /cache directory.");
        }
      } else {
        Serial.println("[SD] Still not ready. Check wiring: MOSI=13, MISO=4, SCK=14, CS=15");
      }
    }

    if (WiFi.status() == WL_CONNECTED) {
      pollSchedule();
      syncRTCfromNTP();
    } else {
      Serial.println("[WiFi] Still offline – using cache.");
    }
  }

  // RTC-based trigger (fires once per minute)
  DateTime now = rtc.now();
  if (now.minute() != lastCheckedMinute || now.hour() != lastCheckedHour) {
    lastCheckedMinute = now.minute();
    lastCheckedHour   = now.hour();
    Serial.printf("[Tick] New minute: %02d:%02d\n", now.hour(), now.minute());
    checkAndPlaySchedule(now.hour(), now.minute());
  }

  // ── SOS Button Check ──
  checkSOSButton();

  // ── SOS Buzzer Pattern (Ambulance/Fire Alarm Cadence) ──
  static unsigned long lastBuzzerToggle = 0;
  static bool buzzerState = false;
  
  if (sosActive) {
    // Non-blocking rapid alternating tone (300ms ON / 300ms OFF)
    if (millis() - lastBuzzerToggle > 300) {
      lastBuzzerToggle = millis();
      buzzerState = !buzzerState;
      digitalWrite(BUZZER_PIN, buzzerState ? HIGH : LOW);
      digitalWrite(SOS_LED_PIN, buzzerState ? HIGH : LOW);
    }
  } else {
    // Ensure it's cleanly off when not active
    if (buzzerState) {
      buzzerState = false;
      digitalWrite(BUZZER_PIN, LOW);
      digitalWrite(SOS_LED_PIN, LOW);
    }
  }
}

// Helper: get a safe cache filepath on the SD card
String getSafeFilename(String type, String url) {
  int lastSlash = url.lastIndexOf('/');
  String basename = (lastSlash != -1) ? url.substring(lastSlash + 1) : "audio.mp3";
  int queryIdx = basename.indexOf('?');
  if (queryIdx != -1) basename = basename.substring(0, queryIdx);
  return "/cache/" + type + "_" + basename;
}

// ──────────────────────────────────────────────
// BACKEND SYNC
// ──────────────────────────────────────────────
void pollSchedule() {
  String url = String("http://") + SERVER_IP + ":" + SERVER_PORT + "/device/pending/" + DEVICE_ID;
  Serial.printf("[Sync] Fetching: %s\n", url.c_str());

  HTTPClient http;
  http.begin(url);
  http.setTimeout(10000);
  int httpCode = http.GET();

  if (httpCode != HTTP_CODE_OK) {
    Serial.printf("[Sync] HTTP Error: %d\n", httpCode);
    http.end();
    return;
  }

  String payload = http.getString();
  http.end();

  Serial.printf("[Sync] Received %d bytes\n", payload.length());

  DynamicJsonDocument doc(16384);
  DeserializationError err = deserializeJson(doc, payload);
  if (err) {
    Serial.printf("[Sync] JSON parse error: %s\n", err.c_str());
    return;
  }

  // Save schedule to NVS for offline use
  String scheduleJson;
  serializeJson(doc, scheduleJson);
  preferences.putString("schedule", scheduleJson);
  preferences.end();
  preferences.begin("caresoul", false);
  Serial.println("[Sync] Schedule saved to NVS.");

  // --- Update Audio Settings (Volume/Language) ---
  if (doc.containsKey("settings")) {
    const char* volStr = doc["settings"]["volume"] | "medium";
    int volLevel = 20;
    if (strcmp(volStr, "low") == 0)       volLevel = 15;
    else if (strcmp(volStr, "high") == 0) volLevel = 25;

    preferences.putInt("volume", volLevel);
    audio.setVolume(volLevel);
    Serial.printf("[Sync] Volume updated to: %s (%d)\n", volStr, volLevel);
  }

  JsonArray actions = doc["actions"];
  Serial.printf("[Sync] Total actions: %d\n", actions.size());

  if (!sdCardReady) {
    Serial.println("[Sync] SD card not ready – skipping file cache/purge.");
    return;
  }

  // --- Pre-cache audio files ---
  std::vector<String> filesInSchedule;
  for (JsonObject action : actions) {
    const char* type = action["type"] | "medicine";
    JsonObject data  = action["data"];
    String audioUrl  = data["audio_url"] | "";
    String filename  = "";

    if (strcmp(type, "medicine") == 0) {
      const char* medicine = data["medicine_name"] | action["medicine_name"] | "Unknown";
      const char* dosage   = data["dosage"]        | action["dosage"]        | "";
      String safeName = String(medicine) + "_" + String(dosage);
      safeName.replace(" ", "_"); safeName.replace("/", "_");
      filename = "/cache/med_" + safeName + ".mp3";
      if (!SD.exists(filename)) {
        String msg = String("Time to take ") + medicine;
        if (strlen(dosage) > 0) msg += String(", ") + dosage;
        downloadTTStoFile(msg, filename);
      }
    } else if (strcmp(type, "habit") == 0) {
      const char* msg = data["message"] | "";
      if (strlen(msg) == 0) msg = data["title"] | "routine";
      String safeMsg = String(msg);
      safeMsg.replace(" ", "_"); safeMsg.replace("/", "_");
      filename = "/cache/habit_" + safeMsg.substring(0, min((int)safeMsg.length(), 25)) + ".mp3";
      if (!SD.exists(filename)) downloadTTStoFile(String(msg), filename);
    } else if (audioUrl.length() > 0) {
      filename = getSafeFilename(String(type), audioUrl);
      // Check existence AND size – a 0-byte file from a failed previous
      // download must be re-fetched, not silently skipped.
      bool needsDL = !SD.exists(filename);
      if (!needsDL) {
        File chk = SD.open(filename);
        if (chk && chk.size() < 1024) { needsDL = true; }
        if (chk) chk.close();
      }
      if (needsDL) {
        Serial.printf("[Cache] Downloading %s: %s\n", type, filename.c_str());
        downloadAudioFile(audioUrl, filename);
      } else {
        Serial.printf("[Cache] Already cached: %s\n", filename.c_str());
      }
    }
    if (filename.length() > 0) filesInSchedule.push_back(filename);
  }

  // --- Automatic Purge: delete SD cache files not in current schedule ---
  File root = SD.open("/cache");
  if (root) {
    File file = root.openNextFile();
    while (file) {
      String fname = "/cache/" + String(file.name());
      file.close();

      bool found = false;
      for (const String& s : filesInSchedule) {
        if (fname.equals(s)) { found = true; break; }
      }
      if (!found) {
        Serial.printf("[Sync] PURGE: Deleting unlisted cache file: %s\n", fname.c_str());
        SD.remove(fname);
      }
      file = root.openNextFile();
    }
    root.close();
  }

  // Report SD card free space after sync
  uint64_t freeAfter = SD.totalBytes() - SD.usedBytes();
  Serial.printf("[SD] Free after sync: %llu MB\n", freeAfter / (1024 * 1024));
}

// ──────────────────────────────────────────────
// TRIGGER LOGIC (called every minute)
// ──────────────────────────────────────────────
void checkAndPlaySchedule(int currentHour, int currentMinute) {
  String payload = preferences.getString("schedule", "{}");

  DynamicJsonDocument doc(16384);
  if (deserializeJson(doc, payload)) {
    Serial.println("[Trigger] Failed to parse cached schedule.");
    return;
  }

  Serial.printf("[Trigger] Checking actions at %02d:%02d\n", currentHour, currentMinute);

  JsonArray actions = doc["actions"];

  struct MatchedAction {
    String type;
    int    priority;
    String filename;
    String ttsText;
  };

  MatchedAction matched[10];
  int matchCount = 0;

  for (JsonObject action : actions) {
    if (matchCount >= 10) break;

    const char* timeStr = action["time"] | action["time_of_day"] | "";
    if (strlen(timeStr) < 5) continue;

    int h = String(timeStr).substring(0, 2).toInt();
    int m = String(timeStr).substring(3, 5).toInt();

    if (h != currentHour || m != currentMinute) continue;

    const char* type = action["type"] | "medicine";
    int priority     = action["priority"] | 1;

    Serial.printf("[Trigger] Match found – type=%s priority=%d\n", type, priority);

    if (strcmp(type, "medicine") == 0) {
      JsonObject data = action["data"];
      const char* medicine = data["medicine_name"] | action["medicine_name"] | "Unknown";
      const char* dosage   = data["dosage"]        | action["dosage"]        | "";

      String safeName = String(medicine) + "_" + String(dosage);
      safeName.replace(" ", "_"); safeName.replace("/", "_");
      String filename = "/cache/med_" + safeName + ".mp3";

      matched[matchCount].type     = "medicine";
      matched[matchCount].priority = priority;
      matched[matchCount].filename = filename;
      matched[matchCount].ttsText  = String("Time to take ") + medicine +
                                     (strlen(dosage) > 0 ? String(", ") + dosage : "") + ".";
      matchCount++;

    } else if (strcmp(type, "voice") == 0) {
      JsonObject data = action["data"];
      const char* urlStr = data["audio_url"] | "";
      String filename    = getSafeFilename("voice", String(urlStr));

      matched[matchCount].type     = "voice";
      matched[matchCount].priority = priority;
      matched[matchCount].filename = filename;
      matched[matchCount].ttsText  = String(urlStr);
      matchCount++;

    } else if (strcmp(type, "habit") == 0) {
      JsonObject data = action["data"];
      const char* msg = data["message"] | "";
      const char* ttl = data["title"]   | "your routine";
      String message  = (strlen(msg) > 0) ? String(msg) : String("Time for ") + ttl;

      String safeMsg = message;
      safeMsg.replace(" ", "_"); safeMsg.replace("/", "_");
      String filename = "/cache/habit_" + safeMsg.substring(0, min((int)safeMsg.length(), 30)) + ".mp3";

      matched[matchCount].type     = "habit";
      matched[matchCount].priority = priority;
      matched[matchCount].filename = filename;
      matched[matchCount].ttsText  = message;
      matchCount++;

    } else if (strcmp(type, "music") == 0) {
      JsonObject data = action["data"];
      const char* urlStr = data["audio_url"] | "";
      String filename    = getSafeFilename("music", String(urlStr));

      matched[matchCount].type     = "music";
      matched[matchCount].priority = priority;
      matched[matchCount].filename = filename;
      matched[matchCount].ttsText  = String(urlStr);
      matchCount++;
    }
  }

  if (matchCount == 0) {
    Serial.println("[Trigger] No actions match this minute.");
    return;
  }

  // Sort by priority (bubble sort – small array)
  for (int i = 0; i < matchCount - 1; i++) {
    for (int j = 0; j < matchCount - i - 1; j++) {
      if (matched[j].priority > matched[j + 1].priority) {
        MatchedAction tmp = matched[j];
        matched[j]        = matched[j + 1];
        matched[j + 1]    = tmp;
      }
    }
  }

  // Play each matched action in priority order
  for (int i = 0; i < matchCount; i++) {
    Serial.printf("[Play] %s (priority %d): %s\n",
                  matched[i].type.c_str(), matched[i].priority,
                  matched[i].filename.c_str());

    // Play from SD cache if available
    if (sdCardReady && SD.exists(matched[i].filename)) {
      // ── Guard: reject corrupt / incomplete cached files (<10 KB) ──
      File testF = SD.open(matched[i].filename);
      size_t fileSize = testF ? testF.size() : 0;
      if (testF) testF.close();

      if (fileSize < 10240) {
        Serial.printf("[Play] WARN: Cached file too small (%u bytes).\n", fileSize);
        SD.remove(matched[i].filename);
        // ── Fallback: stream directly from server instead of blocking download ──
        // downloadAudioFile() would block here for up to 30s. Instead we stream
        // via connecttohost() which plays immediately without saving to SD.
        if (WiFi.status() == WL_CONNECTED && matched[i].ttsText.length() > 0) {
          Serial.printf("[Play] Streaming fallback: %s\n", matched[i].ttsText.c_str());
          int vol = preferences.getInt("volume", 18);
          ampEnable(false);
          audio.setVolume(0);
          audio.connecttohost(matched[i].ttsText.c_str());
          delay(80);
          ampEnable(true);
          // Soft ramp up
          for (int v = 1; v <= 10; v++) {
            audio.setVolume((vol * v) / 10);
            unsigned long rampEnd = millis() + 20;
            while (millis() < rampEnd) { audio.loop(); }
          }
          unsigned long startWait = millis();
          bool started = false;
          while (millis() - startWait < 12000) {
            audio.loop();
            checkSOSButton();
            if (sosActive) { ampEnable(false); audio.stopSong(); ampEnable(true); return; }
            if (audio.isRunning()) { started = true; break; }
          }
          if (!started) Serial.println("[Play] Stream fallback failed to start.");
          while (audio.isRunning()) {
            audio.loop();
            checkSOSButton();
            if (sosActive) { ampEnable(false); audio.stopSong(); ampEnable(true); return; }
          }
          // Ramp down on stop
          for (int v = 9; v >= 0; v--) { audio.setVolume((vol * v) / 10); delay(15); }
          ampEnable(false); delay(30); ampEnable(true);
        } else {
          Serial.println("[Play] Offline + no valid cache – skipping.");
        }
        // File is bad and we've handled it – move to next action
        continue;
      }

      Serial.printf("[Play] Found in SD cache: %s (%u bytes)\n", matched[i].filename.c_str(), fileSize);
      int repeatCount = (matched[i].type == "medicine" || matched[i].type == "habit" || matched[i].type == "voice") ? 2 : 1;
      int targetVol = preferences.getInt("volume", 18);

      // ── Warm up the I2S/DMA pipeline on first use ──
      // The very first connecttoSD() after a cold start can fail because the I2S
      // peripheral hasn't fully initialised its DMA descriptors yet.
      // We do a silent "dummy" open + immediate close to warm it up.
      static bool i2sWarmedUp = false;
      if (!i2sWarmedUp) {
        audio.setVolume(0);
        audio.connecttoSD(matched[i].filename.c_str());
        delay(200);   // give decoder time to open + DMA to spin up
        audio.stopSong();
        delay(100);
        i2sWarmedUp = true;
        Serial.println("[Play] I2S warm-up done.");
      }

      for (int r = 0; r < repeatCount; r++) {
        Serial.printf("[Play] Volume: %d, Iteration: %d\n", targetVol, r + 1);

        bool started = false;
        // ── Retry up to 3 times – first call can silently fail on some ESP32 variants ──
        for (int attempt = 0; attempt < 3 && !started; attempt++) {
          if (attempt > 0) {
            Serial.printf("[Play] Retry attempt %d...\n", attempt + 1);
            audio.stopSong();
            delay(200);   // let I2S fully idle before next open
          }

          // Anti-pop: mute amp → start decoder → 150ms settle → unmute amp
          ampEnable(false);
          audio.setVolume(0);
          audio.connecttoSD(matched[i].filename.c_str());
          delay(150);          // ← increased from 80ms – gives DMA + decoder time to settle
          ampEnable(true);

          // Soft volume ramp: 0 → target over ~200ms
          for (int v = 1; v <= 10; v++) {
            audio.setVolume((targetVol * v) / 10);
            unsigned long rampEnd = millis() + 20;
            while (millis() < rampEnd) { audio.loop(); }
          }

          unsigned long startWait = millis();
          while (millis() - startWait < 4000) {
            audio.loop();
            checkSOSButton();
            if (sosActive) { ampEnable(false); audio.stopSong(); ampEnable(true); return; }
            if (audio.isRunning()) { started = true; break; }
          }
        }

        if (!started) {
          Serial.println("[Play] ERROR: Audio failed to start after 3 attempts.");
        }
        while (audio.isRunning()) {
          audio.loop();
          checkSOSButton();
          if (sosActive) { ampEnable(false); audio.stopSong(); ampEnable(true); return; }
        }

        // ── Anti-pop on stop: ramp volume down → mute amp briefly ──
        for (int v = 9; v >= 0; v--) {
          audio.setVolume((targetVol * v) / 10);
          delay(15);
        }
        ampEnable(false);
        delay(30);
        ampEnable(true);

        if (r < repeatCount - 1) {
          for (int d = 0; d < 150; d++) {
            delay(10); checkSOSButton();
            if (sosActive) { audio.stopSong(); return; }
          }
        }
      }
    } else if (WiFi.status() == WL_CONNECTED) {
      // Cache miss – stream from server
      Serial.printf("[Play] Cache miss – streaming: %s\n", matched[i].ttsText.c_str());
      int vol = preferences.getInt("volume", 18);
      if (matched[i].type == "medicine" || matched[i].type == "habit") {
        String encoded = urlEncode(matched[i].ttsText);
        String ttsUrl  = String("http://") + SERVER_IP + ":" + SERVER_PORT +
                         "/device/tts?text=" + encoded;
        for (int r = 0; r < 2; r++) {
          ampEnable(false);
          audio.setVolume(0);
          audio.connecttohost(ttsUrl.c_str());
          delay(80);
          ampEnable(true);
          for (int v = 1; v <= 10; v++) {
            audio.setVolume((vol * v) / 10);
            unsigned long re = millis() + 20;
            while (millis() < re) { audio.loop(); }
          }
          unsigned long startWait = millis();
          while (!audio.isRunning() && (millis() - startWait < 8000)) {
            audio.loop();
            checkSOSButton();
            if (sosActive) { ampEnable(false); audio.stopSong(); ampEnable(true); return; }
          }
          while (audio.isRunning()) {
            audio.loop();
            checkSOSButton();
            if (sosActive) { ampEnable(false); audio.stopSong(); ampEnable(true); return; }
          }
          for (int v = 9; v >= 0; v--) { audio.setVolume((vol * v) / 10); delay(15); }
          ampEnable(false); delay(30); ampEnable(true);
          if (r == 0) {
            for (int d = 0; d < 300; d++) {
              delay(10); checkSOSButton();
              if (sosActive) { audio.stopSong(); return; }
            }
          }
        }
      } else {
        Serial.printf("[Play] Streaming URL: %s\n", matched[i].ttsText.c_str());
        ampEnable(false);
        audio.setVolume(0);
        audio.connecttohost(matched[i].ttsText.c_str());
        delay(80);
        ampEnable(true);
        for (int v = 1; v <= 10; v++) {
          audio.setVolume((vol * v) / 10);
          unsigned long re = millis() + 20;
          while (millis() < re) { audio.loop(); }
        }
        unsigned long startWait = millis();
        bool started = false;
        while ((millis() - startWait < 12000)) {
          audio.loop();
          checkSOSButton();
          if (sosActive) { ampEnable(false); audio.stopSong(); ampEnable(true); return; }
          if (audio.isRunning()) { started = true; break; }
        }
        if (!started) Serial.println("[Play] ERROR: Stream failed to start.");
        while (audio.isRunning()) {
          audio.loop();
          checkSOSButton();
          if (sosActive) { ampEnable(false); audio.stopSong(); ampEnable(true); return; }
        }
        for (int v = 9; v >= 0; v--) { audio.setVolume((vol * v) / 10); delay(15); }
        ampEnable(false); delay(30); ampEnable(true);
      }
    } else {
      Serial.printf("[Play] ERROR: Audio not cached and offline – skipping.\n");
    }

    for (int d = 0; d < 100; d++) {
      delay(10); checkSOSButton();
      if (sosActive) { audio.stopSong(); return; }
    }
  }
}

// ──────────────────────────────────────────────
// DOWNLOAD HELPERS
// ──────────────────────────────────────────────

// Download TTS audio from backend and save to SD card
void downloadTTStoFile(String text, String filename) {
  String encoded = urlEncode(text);
  String ttsUrl  = String("http://") + SERVER_IP + ":" + SERVER_PORT + "/device/tts?text=" + encoded;
  downloadAudioFile(ttsUrl, filename);
}

// Generic HTTP file downloader → SD card
void downloadAudioFile(String url, String filename) {
  if (!sdCardReady) {
    Serial.println("[Cache] SD not ready – skipping download.");
    return;
  }

  // Log free space before download
  uint64_t freeBytes = SD.totalBytes() - SD.usedBytes();
  Serial.printf("[SD] Free space before download: %llu MB\n", freeBytes / (1024 * 1024));

  // If less than 50MB free, warn (SD cards have plenty of space vs LittleFS)
  if (freeBytes < 50ULL * 1024 * 1024) {
    Serial.println("[SD] WARNING: Low free space (<50MB). Consider clearing old files.");
    // For music files, skip if less than 50MB
    if (filename.startsWith("/cache/music_") && freeBytes < 50ULL * 1024 * 1024) {
      Serial.println("[SD] SKIP: Music download skipped due to low space.");
      return;
    }
  }

  HTTPClient http;
  Serial.printf("[Cache] Downloading: %s\n", url.c_str());
  http.begin(url);
  http.setTimeout(30000);   // 30s connect/response timeout
  int httpCode = http.GET();
  if (httpCode != HTTP_CODE_OK) {
    Serial.printf("[Cache] HTTP %d – download failed.\n", httpCode);
    http.end();
    return;
  }

  // Open file on SD card for writing
  File f = SD.open(filename, FILE_WRITE);
  if (!f) {
    Serial.printf("[Cache] ERROR: Cannot open SD file for writing: %s\n", filename.c_str());
    http.end();
    return;
  }

  int totalBytes = http.getSize();   // -1 if server sends no Content-Length
  Serial.printf("[Cache] Content-Length: %d\n", totalBytes);

  WiFiClient * stream = http.getStreamPtr();
  int bytesRead = 0;
  uint8_t buff[4096];                // 4KB buffer — 4× faster SD writes

  const unsigned long OVERALL_TIMEOUT_MS = 60000;  // 60s max for entire download
  const unsigned long STALL_TIMEOUT_MS   = 10000;  // 10s with zero bytes = abort
  unsigned long downloadStart  = millis();
  unsigned long lastDataTime   = millis();
  int lastProgressLog = 0;

  while (http.connected()) {
    // ── Overall timeout ──
    if (millis() - downloadStart > OVERALL_TIMEOUT_MS) {
      Serial.println("[Cache] ABORT: Overall 60s timeout reached.");
      break;
    }

    // ── Stall timeout (no data for 10s) ──
    if (millis() - lastDataTime > STALL_TIMEOUT_MS) {
      Serial.printf("[Cache] ABORT: No data for %lus. Stall detected.\n",
                    STALL_TIMEOUT_MS / 1000);
      break;
    }

    // ── Known length: done when all bytes received ──
    if (totalBytes > 0 && bytesRead >= totalBytes) {
      break;
    }

    size_t avail = stream->available();
    if (avail) {
      int toRead = min(avail, sizeof(buff));
      int c = stream->readBytes(buff, toRead);
      if (c > 0) {
        f.write(buff, c);
        bytesRead += c;
        lastDataTime = millis();

        // Log progress every ~50KB
        if (bytesRead / (50 * 1024) > lastProgressLog) {
          lastProgressLog = bytesRead / (50 * 1024);
          Serial.printf("[Cache] Progress: %d / %d bytes\n", bytesRead, totalBytes);
        }
      }
    } else {
      delay(5);   // brief yield when no data available yet
    }
  }

  f.close();
  http.end();

  unsigned long elapsed = millis() - downloadStart;
  if (bytesRead < 1024) {
    Serial.printf("[Cache] FAILED: File too small (%d bytes, %lums). Deleting.\n",
                  bytesRead, elapsed);
    SD.remove(filename);
  } else {
    Serial.printf("[Cache] Saved to SD: %s (%d bytes in %lums)\n",
                  filename.c_str(), bytesRead, elapsed);
  }
}

// Simple URL encoder
String urlEncode(String text) {
  String encoded = "";
  for (unsigned int i = 0; i < text.length(); i++) {
    char c = text[i];
    if (c == ' ')       encoded += "%20";
    else if (c == ',')  encoded += "%2C";
    else if (c == '.')  encoded += "%2E";
    else if (c == '\'') encoded += "%27";
    else if (c == '!')  encoded += "%21";
    else                encoded += c;
  }
  return encoded;
}

// Sync RTC from NTP
void syncRTCfromNTP() {
  struct tm timeinfo;
  if (getLocalTime(&timeinfo, 5000)) {
    rtc.adjust(DateTime(timeinfo.tm_year + 1900, timeinfo.tm_mon + 1,
                        timeinfo.tm_mday, timeinfo.tm_hour,
                        timeinfo.tm_min,  timeinfo.tm_sec));
    Serial.printf("[RTC] Synced from NTP: %02d:%02d\n",
                  timeinfo.tm_hour, timeinfo.tm_min);
  } else {
    Serial.println("[RTC] NTP sync failed.");
  }
}

// ──────────────────────────────────────────────
// SOS EMERGENCY SYSTEM
// ──────────────────────────────────────────────

// Check the physical SOS button state
void checkSOSButton() {
  if (digitalRead(SOS_BUTTON_PIN) == LOW && (millis() - lastButtonPress > DEBOUNCE_MS)) {
    lastButtonPress = millis();
    delay(50);  // Quick debounce
    if (digitalRead(SOS_BUTTON_PIN) == LOW) {
      if (sosActive) {
        // Stop SOS instantly
        sosActive = false;
        digitalWrite(BUZZER_PIN, LOW);
        digitalWrite(SOS_LED_PIN, LOW);
        Serial.println("[SOS] ** STOPPED by button press **");
        pendingSOSStopNotify = true; // Tell background task to notify
      } else {
        // Trigger SOS instantly
        sosActive = true;
        
        // INSTANT FEEDBACK
        digitalWrite(BUZZER_PIN, HIGH);
        digitalWrite(SOS_LED_PIN, HIGH);
        Serial.println("[SOS] !! EMERGENCY TRIGGERED !!");
        
        pendingSOSStartNotify = true; // Tell background task to notify
      }
      // Wait for release
      while (digitalRead(SOS_BUTTON_PIN) == LOW) {
        delay(10);
      }
      // Reset debounce timer exactly at release
      lastButtonPress = millis();
    }
  }
}

// (smartDelay and playSOSPattern functions removed. Buzzer uses non-blocking millis() in loop())

// Notify backend of SOS trigger or stop
void notifySOS(bool triggered) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[SOS] Offline – notification queued for next sync.");
    return;
  }

  HTTPClient http;
  if (triggered) {
    String url = String("http://") + SERVER_IP + ":" + SERVER_PORT + "/sos/trigger";
    http.begin(url);
    http.addHeader("Content-Type", "application/json");
    String body = "{\"device_id\":\"" + String(DEVICE_ID) + "\"}";
    int code = http.POST(body);
    Serial.printf("[SOS] Trigger notification sent – HTTP %d\n", code);
  } else {
    String url = String("http://") + SERVER_IP + ":" + SERVER_PORT + "/sos/stop/" + DEVICE_ID;
    http.begin(url);
    int code = http.sendRequest("DELETE");
    Serial.printf("[SOS] Stop notification sent – HTTP %d\n", code);
  }
  http.end();
}

// Check if app remotely stopped the SOS
bool checkSOSRemoteStop() {
  HTTPClient http;
  String url = String("http://") + SERVER_IP + ":" + SERVER_PORT + "/sos/status/" + DEVICE_ID;
  http.begin(url);
  http.setTimeout(800);  // Very short timeout so audio doesn't stutter
  int code = http.GET();
  if (code == 200) {
    String payload = http.getString();
    http.end();
    // If backend says SOS is NOT active, it was stopped from app
    if (payload.indexOf("\"active\":false") >= 0 || payload.indexOf("\"active\": false") >= 0) {
      return true;  // SOS was stopped remotely
    }
  } else {
    http.end();
  }
  return false;
}

// ──────────────────────────────────────────────
// AUDIO CALLBACKS
// ──────────────────────────────────────────────
void audio_info(const char* info) {
  Serial.printf("[Audio] %s\n", info);
}
void audio_eof_mp3(const char* info) {
  Serial.println("[Audio] Finished playing.");
}
