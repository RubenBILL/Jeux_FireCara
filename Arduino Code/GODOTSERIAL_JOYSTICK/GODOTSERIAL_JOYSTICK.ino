// Arduino UNO <-> Godot : bouton + joystick
const int LED_PIN = 13;
const int BOUTON_PIN = 2;
const int JOY_X_PIN = A0;   // fil relié à VRx
const int JOY_Y_PIN = A1;   // fil relié à VRy
int centreX = 512, centreY = 512;

bool appaire = false;
bool boutonAvant = false;

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  pinMode(BOUTON_PIN, INPUT_PULLUP);
  centreX = analogRead(JOY_X_PIN);   // ne touche pas au joystick au démarrage
  centreY = analogRead(JOY_Y_PIN);
}

void loop() {
  if (Serial.available() > 0) {
    String message = Serial.readStringUntil('\n');
    message.trim();
    if (message == "DISCOVER") {
      Serial.println("GDSERIAL_ACK:arduino_uno");
      appaire = true;
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
      Serial.print(analogRead(JOY_X_PIN) - centreX);
      Serial.print(",");
      Serial.println(analogRead(JOY_Y_PIN) - centreY);
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
  }
}
