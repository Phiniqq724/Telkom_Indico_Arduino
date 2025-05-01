#include <Sensirion.h>        // http://playground.arduino.cc/Code/Sensirion
#include <SensirionSHT.h>     // https://github.com/sekdiy/SensirionSHT

// create an instance of SensirionSHT on pins 4 and 5
SensirionSHT Sensor = SensirionSHT(20, 21);

// set delay to one second
long delayTime = 1;

void setup() {
  // setup serial communication
  Serial.begin(9600);
}

void loop() {
  // update measurement
  Sensor.tick(delayTime);

  // new values should occur every three seconds
  Serial.println(Sensor.getTemperature());
  Serial.print("current humidity: ");
  Serial.print(Sensor.getHumidity());
  Serial.print("%, ");
  /*
   * any other code can go here
   */

  // delay expects milliseconds
  delay(delayTime * 1000);
}
