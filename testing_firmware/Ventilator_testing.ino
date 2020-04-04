/*
Testing sketch for Breezy app for Arduino Nano
*/


float volume = 450;
float flow = 120;
float pressure = 50;
float ppeak = 50;
float peep = 65;
float pmean= 35;
float RR=85;
float Ti=25;
float Ttot=20;
float O2conc=35;
float VTo=1254.21;
float VTi=1245;
float MVo=1100;
float MV2=1005;
 
void setup() {
  Serial.begin(115200);
  Serial.println("Breezy app testing sketch");

}
void loop() {
  Serial.print("breezy,1,");
  Serial.print(millis(), 1);
  Serial.print(","); 
  Serial.print(volume, 1);
  Serial.print(","); 
  Serial.print(flow, 1);
  Serial.print(","); 
  Serial.print(pressure, 1);
  Serial.print(","); 
  Serial.print(ppeak, 1);
  Serial.print(","); 
  Serial.print(peep, 1);
  Serial.print(","); 
  Serial.print(pmean, 1);
  Serial.print(","); 
  Serial.print(RR, 1);
  Serial.print(","); 
  Serial.print(Ti, 1);
  Serial.print(","); 
  Serial.print(Ttot, 1);
  Serial.print(","); 
  Serial.print(O2conc, 1);
  Serial.print(","); 
  Serial.print(VTo, 1);
  Serial.print(","); 
  Serial.print(VTi, 1);
  Serial.print(","); 
  Serial.print(MVo, 1);
  Serial.print(",");
  Serial.print(MV2, 1);
  Serial.print(",");
  Serial.print("-1"); 
  Serial.println();
  delay(50);
    
}
