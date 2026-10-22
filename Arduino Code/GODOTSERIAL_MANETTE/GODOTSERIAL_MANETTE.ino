// Arduino UNO <-> Godot : bouton + joystick + potentiomètre + gyroscope (BMI160) + servo
#include <Wire.h>
#include <Servo.h>

const int LED_PIN = 13;
const int BOUTON_PIN = 2;   // bouton du joystick (SW)
const int JOY_X_PIN = A0;   // fil relié à VRx
const int JOY_Y_PIN = A1;   // fil relié à VRy
const int POT_PIN = A2;     // signal du potentiomètre
const int SERVO_PIN = 9;    // fil de signal du servo
const byte BMI_ADDR = 0x68; // SA0 relié à GND (0x69 si SA0 est relié au 3,3V)
int centreX = 512, centreY = 512;

bool appaire = false;
bool boutonAvant = false;

bool bmiOk = false;
Servo servo;
float roll = 0, pitch = 0;   // inclinaison lissée, en degrés

// ── BMI160 : même méthode que le sketch de test qui fonctionne ──
bool lireRegistre(byte reg, byte* dest, byte n) {
  Wire.beginTransmission(BMI_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(BMI_ADDR, n) != n) return false;
  for (byte i = 0; i < n; i++) dest[i] = Wire.read();
  return true;
}

bool bmiInit() {
  Wire.begin();
  Wire.setWireTimeout(3000, true);   // si le bus I2C se bloque : abandon après 3 ms au lieu de figer la carte
  byte id = 0;
  if (!lireRegistre(0x00, &id, 1)) return false;
  if (id != 0xD1) return false;      // 0xD1 = BMI160
  Wire.beginTransmission(BMI_ADDR);
  Wire.write(0x7E);
  Wire.write(0x11);                  // active l'accéléromètre
  if (Wire.endTransmission() != 0) return false;
  delay(60);
  return true;
}

void lireInclinaison() {
  byte d[6];
  if (!lireRegistre(0x12, d, 6)) return;   // lecture ratée : on garde les dernières valeurs
  int16_t ax = (int16_t)((d[1] << 8) | d[0]);
  int16_t ay = (int16_t)((d[3] << 8) | d[2]);
  int16_t az = (int16_t)((d[5] << 8) | d[4]);
  float r = atan2(-ay, -az) * 180.0 / PI;   // module monté à l'envers : Z est négatif au repos
  float p = atan2(-ax, sqrt((float)ay * ay + (float)az * az)) * 180.0 / PI;
  roll  = 0.8 * roll  + 0.2 * r;    // lissage pour éviter les tremblements
  pitch = 0.8 * pitch + 0.2 * p;
}

int lireMoyenne(int pin) {
  long somme = 0;
  for (int i = 0; i < 8; i++) somme += analogRead(pin);
  return somme / 8;
}

void setup() {
  Serial.begin(115200);
  Serial.setTimeout(20);
  Serial.println("boot:debut");
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  pinMode(BOUTON_PIN, INPUT_PULLUP);
  centreX = lireMoyenne(JOY_X_PIN);   // ne touche pas au joystick au démarrage
  centreY = lireMoyenne(JOY_Y_PIN);
  Serial.println("boot:avant_gyro");
  bmiOk = bmiInit();                  // gyroscope réactivé
  Serial.println(bmiOk ? "boot:gyro_ok" : "boot:gyro_absent");
}

void loop() {
  if (Serial.available() > 0) {
    String message = Serial.readStringUntil('\n');
    message.trim();
    if (message == "DISCOVER") {
      Serial.println("GDSERIAL_ACK:arduino_uno");
      appaire = true;
      digitalWrite(LED_PIN, HIGH);    // LED 13 allumée = appairée
    } else if (appaire) {
      traiter(message);
    }
  }

  if (appaire) {
    bool appuye = (digitalRead(BOUTON_PIN) == LOW);
    if (appuye != boutonAvant) {
      boutonAvant = appuye;
      Serial.println(appuye ? "button:1" : "button:0");
    }

    static unsigned long dernier = 0;
    if (millis() - dernier >= 20) {
      dernier = millis();

      Serial.print("joy:");
      Serial.print(lireMoyenne(JOY_X_PIN) - centreX);
      Serial.print(",");
      Serial.println(lireMoyenne(JOY_Y_PIN) - centreY);

      analogRead(POT_PIN);                 // première lecture jetée : l'ADC change de voie
      Serial.print("pot:");
      Serial.println(lireMoyenne(POT_PIN));

      if (bmiOk) {
        lireInclinaison();
        Serial.print("tilt:");
        Serial.print((int)roll);
        Serial.print(",");
        Serial.println((int)pitch);
      }
    }
  }
}

void traiter(const String& message) {
  int deuxPoints = message.indexOf(':');
  if (deuxPoints == -1) return;
  String cle = message.substring(0, deuxPoints);
  String valeur = message.substring(deuxPoints + 1);

  if (cle == "led") {
    digitalWrite(LED_PIN, valeur == "1" ? HIGH : LOW);
    Serial.println("ack:led:" + valeur);
  } else if (cle == "ping") {
    Serial.println("pong:" + valeur);
  } else if (cle == "servo") {
    int angle = constrain(valeur.toInt(), 0, 180);
    if (!servo.attached()) servo.attach(SERVO_PIN);   // attaché au premier ordre : pas de saut au démarrage
    servo.write(angle);
  }
}