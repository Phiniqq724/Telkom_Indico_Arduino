#include <LoRa.h>
#include <ModbusMaster.h>
#include "EasyNextionLibrary.h"
#include <Sensirion.h>
#include <SensirionSHT.h>
#include <SoftwareSerial.h>

// create an instance of SensirionSHT on pins 4 and 5
SensirionSHT Sensor = SensirionSHT(20, 21);

// set delay to one second
long delayTime = 1;

SoftwareSerial CO2Serial(10, 11); // RX, TX

EasyNex myNex(Serial2);
int currentPage = -1;

ModbusMaster CO2;
ModbusMaster NH3;
ModbusMaster WIND;

#define SS_PIN 53
#define RST_PIN 9
#define DIO0_PIN 2  

String device_id = "1";
String kandang_id = "1_1_3";
unsigned long lastSendTime = 0;
unsigned long sendInterval = 1000;
unsigned long timeElapse = 0;

float nh3ppm = 0;
float co2ppm = 0;
float windSpeed = 0;

void updateNextionDisplay(float temperature, float humidity, float co2, float nh3, float wind, int currentPage)
{
  String tempStr = String(temperature, 1) + " C";
  String humStr = String(humidity, 1) + "%";
  String tempHumStr = tempStr + " / " + humStr;
  String co2Str = String((int)co2) + " ppm";
  String nh3Str = String(nh3, 1) + " ppm";
  String windStr = String(wind, 1) + " m/s";

  Serial.println(tempHumStr);

  switch (currentPage)
  {
  case 0:
    myNex.writeStr("t4.txt", windStr);
    myNex.writeStr("t1.txt", nh3Str);
    myNex.writeStr("t2.txt", tempHumStr);
    myNex.writeStr("t3.txt", co2Str);
    break;

  case 1:
    myNex.writeStr("t1.txt", windStr);
    break;

  case 2:
    myNex.writeStr("t1.txt", nh3Str);
    break;

  case 3:
    myNex.writeStr("t1.txt", tempStr);
    break;

  case 4:
    myNex.writeStr("t1.txt", humStr);
    break;

  case 5:
    myNex.writeStr("t1.txt", co2Str);
    break;

  case 6:
    myNex.writeStr("t4.txt", windStr);
    myNex.writeStr("t2.txt", tempStr);
    myNex.writeStr("t1.txt", nh3Str);
    myNex.writeStr("t3.txt", co2Str);
    break;
  }
}

void setup()
{
  Serial.begin(9600);
  // NEXTION
  pinMode(8, OUTPUT); // DE/RE pin
  digitalWrite(8, 0); // Mulai dalam mode RX
  myNex.begin(9600);
  delay(500);
  CO2Serial.begin(4800);
  Serial1.begin(4800);
  Serial3.begin(4800);
  CO2.begin(1, CO2Serial);
  NH3.begin(1, Serial3);
  WIND.begin(1, Serial1);

  LoRa.setPins(SS_PIN, RST_PIN, DIO0_PIN);
  if (!LoRa.begin(433E6))
  {
    Serial.println("LoRa init failed");
    while (1)
      ;
  }

  LoRa.setSpreadingFactor(7);
  LoRa.setSignalBandwidth(125E3);
  LoRa.setCodingRate4(5);
  LoRa.setSyncWord(0x12);
  LoRa.enableCrc();
}

int checkCurrentPage()
{
  int page = myNex.readNumber("dp"); // Baca halaman saat ini dari Nextion
  Serial.println(page);
  if (page != currentPage)
  {
    currentPage = page;
    Serial.print("Current Page: ");
    Serial.println(currentPage);
  }
  // Serial.print("NIGGA: ");
  // Serial.println(currentPage);
  return currentPage;
}

void loop()
{
  Sensor.tick(delayTime);
  // put your main code here, to run repeatedly:
  float temperature = Sensor.getTemperature();
  float humidity = Sensor.getHumidity();
  myNex.NextionListen();
  if (millis() - lastSendTime >= sendInterval)
  {
    lastSendTime = millis();
    uint8_t resultco = CO2.readHoldingRegisters(0x00, 3);
    uint8_t resultnh = NH3.readHoldingRegisters(0x02, 1);
    uint8_t resultwd = WIND.readHoldingRegisters(0x00, 1);

    if (resultco == CO2.ku8MBSuccess)
    {
      co2ppm = CO2.getResponseBuffer(0);
    }

    if (resultnh == NH3.ku8MBSuccess)
    {
      nh3ppm = NH3.getResponseBuffer(0);
    }
    if (resultwd == WIND.ku8MBSuccess)
    {
      // Handle wind data if needed
      windSpeed = WIND.getResponseBuffer(0);
    }

    String payload = "{\"client_id\":\"" + device_id +
                     "\",\"kandang_id\":\"" + kandang_id +
                     "3\",\"suhu\":" + temperature +
                     ",\"kelembaban\":" + humidity +
                     ",\"co2\":" + co2ppm +
                     ",\"ammonia\":" + nh3ppm +
                     ",\"wind\":" + windSpeed + "}";

    // Send data
    LoRa.beginPacket();
    LoRa.print(payload);
    LoRa.endPacket();

    Serial.println(payload);
  }
  int realCurrentPage = checkCurrentPage();
  updateNextionDisplay(temperature, humidity, co2ppm, nh3ppm, windSpeed, realCurrentPage);
}
