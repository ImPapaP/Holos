/*
  Gabay Sensor - ESP32 gas/smoke + temperature sensor over Bluetooth LE.

  Parts:
    - ESP32 DevKit (any ESP32 with BLE)
    - MQ-2 gas/smoke sensor  -> analog out to GPIO 34 (use a voltage divider: MQ-2 outputs up to 5V)
    - LM35 temperature sensor -> analog out to GPIO 35
  Sends text "gas,tempC" (example: "412,36.5") once per second.
  The Gabay app connects to the device named "Gabay-Sensor".

  Arduino IDE: install "esp32" boards by Espressif, select your ESP32 board, upload.
  Let the MQ-2 warm up ~2 minutes before trusting readings, then calibrate gasLimit in the app.
*/
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define DATA_UUID    "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

const int GAS_PIN = 34;
const int TEMP_PIN = 35;

BLECharacteristic *dataChar;
bool connected = false;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *s) override { connected = true; }
  void onDisconnect(BLEServer *s) override {
    connected = false;
    s->getAdvertising()->start();  // allow reconnect
  }
};

void setup() {
  Serial.begin(115200);
  analogReadResolution(12);

  BLEDevice::init("Gabay-Sensor");
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  BLEService *service = server->createService(SERVICE_UUID);
  dataChar = service->createCharacteristic(DATA_UUID, BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ);
  dataChar->addDescriptor(new BLE2902());
  service->start();

  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("Gabay-Sensor advertising");
}

void loop() {
  int gas = analogRead(GAS_PIN);                        // 0..4095 raw
  float volts = analogRead(TEMP_PIN) * 3.3 / 4095.0;
  float tempC = volts * 100.0;                          // LM35: 10 mV per °C

  char msg[24];
  snprintf(msg, sizeof(msg), "%d,%.1f", gas, tempC);
  Serial.println(msg);

  if (connected) {
    dataChar->setValue((uint8_t *)msg, strlen(msg));
    dataChar->notify();
  }
  delay(1000);
}
