/*
  dispensadorV2_4.ino
  Proyecto: Dispensador de Chicha de Winapu
  Autor: Eduardo Jordy Zeballos Garcia
  Descripción: Firmware V2.4. Fusiona la lógica V2.3 con el hardware definitivo de Fase 1.
*/
#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <hd44780.h>
#include <hd44780ioClass/hd44780_I2Cexp.h>
#include "secrets.h"

// ==========================================
// 1. CONFIGURACIÓN DE RED Y FIREBASE
// ==========================================
// Si secrets.h proporciona las credenciales, se usan esas definiciones.
// En caso contrario, se usan valores por defecto.
#ifndef WIFI_SSID
  #define WIFI_SSID "TU_SSID"
#endif

#ifndef WIFI_PASSWORD
  #define WIFI_PASSWORD "azul12345"
#endif

#ifndef FIREBASE_API_KEY
  #define FIREBASE_API_KEY "AIzaSyBlEAKk8ipnVA__EStSCJQ0sZEXlQd0Mec"
#endif

#ifndef FIREBASE_PROJECT_ID
  #define FIREBASE_PROJECT_ID "chichej-2026"
#endif

#ifndef FIREBASE_DEVICE_EMAIL
  #define FIREBASE_DEVICE_EMAIL ""
#endif

#ifndef FIREBASE_DEVICE_PASSWORD
  #define FIREBASE_DEVICE_PASSWORD ""
#endif

#define API_KEY FIREBASE_API_KEY
#define PROJECT_ID FIREBASE_PROJECT_ID

// Misma instancia de Realtime Database utilizada por Flutter.
const char *RTDB_DISPENSADOR_URL =
  "https://chichej-2026-default-rtdb.firebaseio.com/dispensador/principal.json";

// ==========================================
// 2. CONFIGURACIÓN DE PINES Y TIEMPOS
// ==========================================
//wi-fi (tiempo de espera)
unsigned long ultimoIntentoConexionWiFi = 0;
const unsigned long INTERVALO_RECONEXION_WIFI = 10000;

// Bomba con relé activo en LOW.
const int PIN_BOMBA = 4;

// Dos motores mezcladores controlados mediante puente H.
const int PIN_MOTOR1_IN1 = 23;
const int PIN_MOTOR1_IN2 = 22;
const int PIN_MOTOR2_IN3 = 21;
const int PIN_MOTOR2_IN4 = 19;

// Sensor ultrasónico (diagnóstico por Serial en esta fase).
const int PIN_TRIG = 16;
const int PIN_ECHO = 17;

// Pulsadores físicos
const int PIN_BTN_1      = 34; // Opción 1: Muestra 45ml (pull-up externo 10k)
const int PIN_BTN_2      = 35; // Opción 2: 150ml (pull-up externo 10k)
const int PIN_BTN_3      = 32; // Opción 3: 250ml
const int PIN_BTN_4      = 33; // Opción 4: 500ml
const int PIN_BTN_5      = 25; // Opción 5: 750ml
const int PIN_BTN_6      = 26; // Opción 6: 1 Litro
const int PIN_BTN_CANCEL = 27; // Botón Físico de CANCELAR (Prioridad Máxima)

// Pantalla LCD I2C (4 pines: VCC, GND, SDA, SCL)
#define I2C_SDA 14
#define I2C_SCL 13
#define LCD_COLS 16
#define LCD_ROWS 2

hd44780_I2Cexp lcd; // Detección automática de dirección I2C (0x27 / 0x3F, etc.)

// Tiempos de mezcla (Temporizador automático)
const unsigned long TIEMPO_REPOSO = 10000; // 10 segundos
const unsigned long TIEMPO_MEZCLA = 5000;  // 5 segundos

// Duraciones de mensajes en pantalla
const unsigned long DURACION_GRACIAS   = 3000; // "Gracias por su compra"
const unsigned long DURACION_CANCELADO = 1500; // "Pedido cancelado"
const unsigned long DURACION_CONTEO    = 1000; // 1 segundo por número (3,2,1)
const unsigned long DURACION_CAMBIO_VASO = 6000; // tiempo para colocar el siguiente vaso

// Máximo de dispensaciones individuales dentro de un pedido.
// Ejemplo: 150ml x2 + 500ml x1 = 3 trabajos.
const int MAX_TRABAJOS_PEDIDO = 30;

// Reintento mínimo en RAM de dispensaciones físicas ya terminadas.
const int MAX_REGISTROS_FISICOS_PENDIENTES = 8;
struct RegistroFisicoPendiente {
  String id;
  int opcion;
};
RegistroFisicoPendiente registrosFisicosPendientes[MAX_REGISTROS_FISICOS_PENDIENTES];
int inicioRegistrosFisicos = 0;
int totalRegistrosFisicos = 0;
String registroFisicoActualId = "";
int opcionFisicaActual = 0;
unsigned long ultimoIntentoRegistroFisico = 0;
unsigned long secuenciaRegistroFisico = 0;
const unsigned long INTERVALO_REINTENTO_REGISTRO_FISICO = 10000;

// Activar en 'true' solo si necesitas depurar las respuestas de Firestore a detalle
const bool DEBUG_FIRESTORE_VERBOSE = false;

// Telemetría RTDB: se agrupan cambios y se reintentan sin detener la máquina.
bool bombaActivaFisica = false;
bool agitadorActivoFisico = false;
bool telemetriaPendiente = true;
bool ultimoEnvioTelemetriaFallo = false;
bool distanciaValida = false;
float ultimaDistanciaValidaCm = 0.0f;
int ultimoNivelProvisional = 0;
unsigned long ultimoIntentoTelemetria = 0;
const unsigned long INTERVALO_MINIMO_TELEMETRIA = 500;
const unsigned long INTERVALO_REINTENTO_TELEMETRIA = 5000;
const unsigned long INTERVALO_REINTENTO_AUTH = 10000;

String firebaseIdToken = "";
String firebaseRefreshToken = "";
unsigned long vencimientoTokenFirebase = 0;
unsigned long ultimoIntentoAuth = 0;
bool forzarRenovacionToken = false;

// Referencias provisionales heredadas del firmware físico de prueba.
// Deben recalibrarse cuando el sensor abandone la protoboard.
const float DISTANCIA_PROVISIONAL_LLENO_CM = 5.0f;
const float DISTANCIA_PROVISIONAL_VACIO_CM = 30.0f;

// ==========================================
// 3. MÁQUINA DE ESTADOS
// ==========================================
enum EstadoSistema {
  REPOSO,
  MEZCLANDO,
  CONTEO_REGRESIVO,
  DISPENSANDO,
  ESPERANDO_VASO,
  MOSTRANDO_GRACIAS,
  MOSTRANDO_CANCELADO
};

EstadoSistema estado = REPOSO;
unsigned long marcaTiempoEstado = 0;

// Datos de la selección en curso (usados durante el conteo y el despacho)
int opcionPendiente = 0;
unsigned long tiempoServicioPendiente = 0;
String etiquetaActual = "";
String origenActual = "";

// Pedido Firestore actualmente tomado por la máquina.
// Permite marcar "entregado" solamente cuando termina físicamente
// y "cancelado" si se interrumpe desde el botón físico.
String pedidoFirestoreActualId = "";
bool pedidoFirestoreEnCurso = false;

// Cola interna del pedido Firestore actual.
// Cada posición representa UNA dispensación física independiente.
int colaOpciones[MAX_TRABAJOS_PEDIDO];
int totalTrabajosPedido = 0;
int indiceTrabajoActual = -1;

int conteoActual = 3;
unsigned long marcaConteo = 0;

unsigned long cronometroMezcla = 0;
unsigned long tiempoFinServicio = 0;

// Control anti-rebote (Debounce)
unsigned long ultimoTiempoRebote = 0;
const unsigned long DELAY_REBOTE = 250;

// Control de reintentos de Wi-Fi y Firestore
unsigned long ultimaVerificacionWiFi = 0;
unsigned long ultimoChequeo = 0;

// Lectura prudente del sensor, sin calibración de porcentaje en esta fase.
unsigned long ultimaLecturaSensor = 0;
const unsigned long INTERVALO_SENSOR = 2000;

// Control de refresco del LCD
unsigned long ultimaActualizacionLCD = 0;
const unsigned long INTERVALO_LCD = 1000;

// Evita reescribir continuamente exactamente el mismo texto por I2C.
String ultimaLineaLCD1 = "";
String ultimaLineaLCD2 = "";

// V2.3: control fino de pantalla.
int ultimoSegundoLCD = -1;
bool forzarRefrescoLCD = true;

// ==========================================
// 4. DECLARACIÓN DE FUNCIONES
// ==========================================
void encenderMezclador();
void apagarMezclador();
void encenderBomba();
void apagarBomba();
void cancelarTodo(String origen);
void solicitarSeleccion(int opcion, String origen);
void procesarPedidoFirestore(int opcion, String docID);
void procesarPedidoFirestoreConItems(String documento, String docID);
bool actualizarEstadoPedidoFirestore(String docID, String nuevoEstado, bool procesado);
void finalizarPedidoFirestoreEntregado();
void finalizarUnidadFirestore();
void iniciarSiguienteTrabajoFirestore();
void limpiarColaPedidoFirestore();
bool cargarTrabajosDesdeDocumento(String documento);
int buscarCierreBalanceado(const String &texto, int inicio, char apertura, char cierre);
int extraerEnteroFirestore(const String &texto, const String &campo, int desde, int hasta, int valorDefecto);
bool extraerBooleanoFirestore(const String &texto, const String &campo, int desde, int hasta, bool valorDefecto);
String extraerTextoFirestore(const String &texto, const String &campo, int desde, int hasta, const String &valorDefecto);
double extraerDecimalFirestore(const String &texto, const String &campo, int desde, int hasta, double valorDefecto);
void verificarPedidosPendientes();
void verificarPulsadores();
void diagnosticoHardware();
void conectarWiFi();
void inicializarLCD();
void mostrarMensaje(String linea1, String linea2 = "");
void actualizarLCD();
void limpiarLCDSeguro();
void mostrarEstadoLCD();
void medirDistanciaUltrasonica();
void marcarTelemetriaPendiente();
void procesarTelemetriaPendiente();
bool enviarTelemetriaRTDB();
bool asegurarAutenticacionFirebase();
bool autenticarFirebaseEmailPassword();
bool renovarTokenFirebase();
bool guardarTokensFirebase(const String &respuesta, bool esRenovacion);
String extraerTextoJson(const String &json, const String &campo);
String escaparJson(const String &texto);
String codificarFormulario(const String &texto);
String estadoTelemetriaActual();
String productoTelemetriaActual();
int calcularNivelProvisional(float distanciaCm);
void prepararRegistroFisico(int opcion);
void descartarRegistroFisicoActual();
void encolarRegistroFisicoCompletado();
void procesarRegistrosFisicosPendientes();
bool registrarDispensacionFisicaFirestore(const RegistroFisicoPendiente &registro);
String generarIdRegistroFisico();
void cambiarEstado(EstadoSistema nuevoEstado);
String etiquetaParaOpcion(int opcion, unsigned long &tiempoServicio);

// ==========================================
// 5. SETUP
// ==========================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("================================");
  Serial.println("CHICHEJ DISPENSADOR");
  Serial.println("FIRMWARE V2.4");
  Serial.println("================================");

  pinMode(PIN_MOTOR1_IN1, OUTPUT);
  pinMode(PIN_MOTOR1_IN2, OUTPUT);
  pinMode(PIN_MOTOR2_IN3, OUTPUT);
  pinMode(PIN_MOTOR2_IN4, OUTPUT);
  pinMode(PIN_BOMBA, OUTPUT);

  // Los actuadores quedan apagados antes de inicializar LCD, Wi-Fi o Firestore.
  digitalWrite(PIN_BOMBA, HIGH);
  digitalWrite(PIN_MOTOR1_IN1, LOW);
  digitalWrite(PIN_MOTOR1_IN2, LOW);
  digitalWrite(PIN_MOTOR2_IN3, LOW);
  digitalWrite(PIN_MOTOR2_IN4, LOW);

  pinMode(PIN_TRIG, OUTPUT);
  digitalWrite(PIN_TRIG, LOW);
  pinMode(PIN_ECHO, INPUT);

  pinMode(PIN_BTN_1, INPUT);
  pinMode(PIN_BTN_2, INPUT);
  pinMode(PIN_BTN_3, INPUT_PULLUP);
  pinMode(PIN_BTN_4, INPUT_PULLUP);
  pinMode(PIN_BTN_5, INPUT_PULLUP);
  pinMode(PIN_BTN_6, INPUT_PULLUP);
  pinMode(PIN_BTN_CANCEL, INPUT_PULLUP);

  cronometroMezcla = millis();

  diagnosticoHardware();
  inicializarLCD();
  conectarWiFi();

  Serial.println("\nSistema listo.");
  Serial.println("------------------------------------------------------------------");
}

// ==========================================
// 6. LOOP PRINCIPAL
// ==========================================
void loop() {
  unsigned long tiempoActual = millis();

  // --- 1. LECTURA DE PULSADORES (Cancelar tiene prioridad máxima) ---
  verificarPulsadores();

  // --- 2. LÓGICA SEGÚN EL ESTADO ACTUAL ---
  switch (estado) {

    case REPOSO:
      if (tiempoActual - cronometroMezcla >= TIEMPO_REPOSO) {
        encenderMezclador();
        cronometroMezcla = tiempoActual;
        cambiarEstado(MEZCLANDO);
      }
      break;

    case MEZCLANDO:
      if (tiempoActual - cronometroMezcla >= TIEMPO_MEZCLA) {
        apagarMezclador();
        cronometroMezcla = tiempoActual;
        cambiarEstado(REPOSO);
      }
      break;

    case CONTEO_REGRESIVO:
      if (tiempoActual - marcaConteo >= DURACION_CONTEO) {
        marcaConteo = tiempoActual;
        conteoActual--;

        if (conteoActual <= 0) {
          // Termina el conteo: arranca el despacho de verdad
          encenderBomba();
          tiempoFinServicio = millis() + tiempoServicioPendiente;
          ultimoTiempoRebote = millis();
          cambiarEstado(DISPENSANDO);
        } else {
          forzarRefrescoLCD = true;
          mostrarEstadoLCD();
        }
      }
      break;

    case DISPENSANDO:
      if (tiempoActual >= tiempoFinServicio) {
        apagarBomba();

        if (pedidoFirestoreEnCurso) {
          // En pedidos con varias unidades, terminar una bomba NO
          // significa terminar todo el pedido.
          finalizarUnidadFirestore();
        } else {
          encolarRegistroFisicoCompletado();
          cambiarEstado(MOSTRANDO_GRACIAS);
        }
      }
      break;

    case ESPERANDO_VASO:
      if (tiempoActual - marcaTiempoEstado >= DURACION_CAMBIO_VASO) {
        iniciarSiguienteTrabajoFirestore();
      }
      break;

    case MOSTRANDO_GRACIAS:
      if (tiempoActual - marcaTiempoEstado >= DURACION_GRACIAS) {
        cronometroMezcla = tiempoActual;
        cambiarEstado(REPOSO);
      }
      break;

    case MOSTRANDO_CANCELADO:
      if (tiempoActual - marcaTiempoEstado >= DURACION_CANCELADO) {
        cronometroMezcla = tiempoActual;
        cambiarEstado(REPOSO);
      }
      break;
  }

  // --- 3. RECONEXIÓN AUTOMÁTICA Y CONSULTA REST FIRESTORE ---
  if (tiempoActual - ultimaVerificacionWiFi >= 4000) {
    ultimaVerificacionWiFi = tiempoActual;

    if (WiFi.status() != WL_CONNECTED) {

      if (tiempoActual - ultimoIntentoConexionWiFi >=
          INTERVALO_RECONEXION_WIFI) {

        ultimoIntentoConexionWiFi = tiempoActual;

        Serial.println(
          "[WIFI] Sin conexion. Iniciando nuevo intento..."
        );

        WiFi.disconnect(false);
        delay(50);

        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      }
    }
    else {
      if (estado == REPOSO || estado == MEZCLANDO) {
      
        if (millis() - ultimoChequeo >= 5000) {
          ultimoChequeo = millis();
          verificarPedidosPendientes();
        }
      }
    }
  }

  // --- 4. CONTROL MANUAL POR PUERTO SERIAL ---
  if (Serial.available() > 0) {
    char comando = Serial.read();
    if (comando == '\n' || comando == '\r') return;

    if (comando == 'C' || comando == 'c') {
      cancelarTodo("TECLADO SERIAL");
    }
    else if (comando >= '1' && comando <= '6') {
      if (estado != REPOSO && estado != MEZCLANDO) {
        Serial.println("[SERIAL] Error: Sistema ocupado.");
      } else {
        solicitarSeleccion(comando - '0', "TECLADO SERIAL");
      }
    }
  }

  // --- 5. REFRESCO CONTROLADO DEL LCD ---
  // Solo DISPENSANDO necesita refresco periódico por el contador de segundos.
  if (estado == DISPENSANDO &&
      tiempoActual - ultimaActualizacionLCD >= INTERVALO_LCD) {
    ultimaActualizacionLCD = tiempoActual;
    actualizarLCD();
  }

  if (forzarRefrescoLCD) {
    mostrarEstadoLCD();
  }

  // --- 6. SENSOR ULTRASÓNICO (solo en reposo, máximo cada 2 segundos) ---
  if (estado == REPOSO &&
      tiempoActual - ultimaLecturaSensor >= INTERVALO_SENSOR) {
    ultimaLecturaSensor = tiempoActual;
    medirDistanciaUltrasonica();
  }

  // --- 7. TELEMETRÍA RTDB (solo si hay cambios pendientes) ---
  procesarTelemetriaPendiente();

  // --- 8. REGISTROS FÍSICOS (solo en reposo, después de terminar la bomba) ---
  if (estado == REPOSO) {
    procesarRegistrosFisicosPendientes();
  }
}

// ==========================================
// 7. GESTIÓN DE WI-FI
// ==========================================
void conectarWiFi() {
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.setSleep(false);

  Serial.print("Conectando a Wi-Fi: ");
  Serial.println(WIFI_SSID);
  mostrarMensaje("Conectando WiFi", WIFI_SSID);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int intentosWiFi = 0;
  while (WiFi.status() != WL_CONNECTED && intentosWiFi < 20) {
    delay(500);
    Serial.print(".");
    intentosWiFi++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n¡Wi-Fi Conectado exitosamente!");
    Serial.print("IP asignada: ");
    Serial.println(WiFi.localIP());
    mostrarMensaje("WiFi conectado", WiFi.localIP().toString());
    delay(1200);
  } else {
    Serial.println("\n[AVISO] No se pudo conectar de inmediato. Reintentará en segundo plano.");
    mostrarMensaje("WiFi no disp.", "Reintentando...");
    delay(1200);
  }
}

void marcarTelemetriaPendiente() {
  telemetriaPendiente = true;
  ultimoEnvioTelemetriaFallo = false;
}

String extraerTextoJson(const String &json, const String &campo) {
  String clave = "\"" + campo + "\"";
  int posicion = json.indexOf(clave);
  if (posicion < 0) return "";

  posicion = json.indexOf(':', posicion + clave.length());
  if (posicion < 0) return "";

  posicion++;
  while (posicion < (int)json.length() &&
         (json[posicion] == ' ' || json[posicion] == '\r' ||
          json[posicion] == '\n' || json[posicion] == '\t')) {
    posicion++;
  }

  if (posicion >= (int)json.length() || json[posicion] != '"') {
    return "";
  }

  int inicio = ++posicion;
  bool escapado = false;
  while (posicion < (int)json.length()) {
    char actual = json[posicion];
    if (actual == '"' && !escapado) {
      return json.substring(inicio, posicion);
    }
    escapado = actual == '\\' && !escapado;
    if (actual != '\\') escapado = false;
    posicion++;
  }

  return "";
}

String escaparJson(const String &texto) {
  String resultado;
  resultado.reserve(texto.length() + 8);

  for (unsigned int i = 0; i < texto.length(); i++) {
    char caracter = texto[i];
    if (caracter == '"' || caracter == '\\') resultado += '\\';
    resultado += caracter;
  }

  return resultado;
}

String codificarFormulario(const String &texto) {
  const char hex[] = "0123456789ABCDEF";
  String resultado;
  resultado.reserve(texto.length() + 16);

  for (unsigned int i = 0; i < texto.length(); i++) {
    unsigned char caracter = (unsigned char)texto[i];
    if ((caracter >= 'a' && caracter <= 'z') ||
        (caracter >= 'A' && caracter <= 'Z') ||
        (caracter >= '0' && caracter <= '9') ||
        caracter == '-' || caracter == '_' ||
        caracter == '.' || caracter == '~') {
      resultado += (char)caracter;
    } else {
      resultado += '%';
      resultado += hex[(caracter >> 4) & 0x0F];
      resultado += hex[caracter & 0x0F];
    }
  }

  return resultado;
}

bool guardarTokensFirebase(const String &respuesta, bool esRenovacion) {
  String nuevoIdToken = extraerTextoJson(
    respuesta,
    esRenovacion ? "id_token" : "idToken"
  );
  String nuevoRefreshToken = extraerTextoJson(
    respuesta,
    esRenovacion ? "refresh_token" : "refreshToken"
  );
  String expiracionTexto = extraerTextoJson(
    respuesta,
    esRenovacion ? "expires_in" : "expiresIn"
  );

  if (nuevoIdToken == "" || nuevoRefreshToken == "") {
    return false;
  }

  unsigned long segundos = (unsigned long)expiracionTexto.toInt();
  if (segundos < 300) segundos = 3600;

  firebaseIdToken = nuevoIdToken;
  firebaseRefreshToken = nuevoRefreshToken;
  vencimientoTokenFirebase = millis() + segundos * 1000UL;
  forzarRenovacionToken = false;
  return true;
}

bool autenticarFirebaseEmailPassword() {
  if (String(FIREBASE_DEVICE_EMAIL).length() == 0 ||
      String(FIREBASE_DEVICE_PASSWORD).length() == 0) {
    Serial.println("[AUTH] Faltan credenciales del dispositivo en secrets.h.");
    return false;
  }

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(3000);

  HTTPClient http;
  http.setTimeout(3000);

  String url =
    "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" +
    String(API_KEY);

  if (!http.begin(client, url)) {
    Serial.println("[AUTH] No se pudo iniciar Firebase Authentication.");
    return false;
  }

  http.addHeader("Content-Type", "application/json");
  String payload = "{\"email\":\"" +
    escaparJson(String(FIREBASE_DEVICE_EMAIL)) +
    "\",\"password\":\"" +
    escaparJson(String(FIREBASE_DEVICE_PASSWORD)) +
    "\",\"returnSecureToken\":true}";

  int codigo = http.POST(payload);
  String respuesta = http.getString();
  http.end();

  if (codigo >= 200 && codigo < 300 &&
      guardarTokensFirebase(respuesta, false)) {
    Serial.println("[AUTH] Firebase autenticado.");
    return true;
  }

  Serial.print("[AUTH] No se pudo autenticar. HTTP ");
  Serial.println(codigo);
  return false;
}

bool renovarTokenFirebase() {
  if (firebaseRefreshToken == "") return false;

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(3000);

  HTTPClient http;
  http.setTimeout(3000);

  String url = "https://securetoken.googleapis.com/v1/token?key=" +
    String(API_KEY);

  if (!http.begin(client, url)) {
    Serial.println("[AUTH] No se pudo iniciar la renovacion del token.");
    return false;
  }

  http.addHeader("Content-Type", "application/x-www-form-urlencoded");
  String payload = "grant_type=refresh_token&refresh_token=" +
    codificarFormulario(firebaseRefreshToken);

  int codigo = http.POST(payload);
  String respuesta = http.getString();
  http.end();

  if (codigo >= 200 && codigo < 300 &&
      guardarTokensFirebase(respuesta, true)) {
    Serial.println("[AUTH] Token Firebase renovado.");
    return true;
  }

  if (codigo >= 400 && codigo < 500) {
    firebaseRefreshToken = "";
  }

  Serial.print("[AUTH] No se pudo renovar el token. HTTP ");
  Serial.println(codigo);
  return false;
}

bool asegurarAutenticacionFirebase() {
  if (WiFi.status() != WL_CONNECTED) return false;

  long tiempoRestante = (long)(vencimientoTokenFirebase - millis());
  if (!forzarRenovacionToken &&
      firebaseIdToken != "" &&
      tiempoRestante > 60000L) {
    return true;
  }

  unsigned long ahora = millis();
  if (ultimoIntentoAuth != 0 &&
      ahora - ultimoIntentoAuth < INTERVALO_REINTENTO_AUTH) {
    return false;
  }

  ultimoIntentoAuth = ahora;

  if (firebaseRefreshToken != "") {
    return renovarTokenFirebase();
  }

  return autenticarFirebaseEmailPassword();
}

String estadoTelemetriaActual() {
  switch (estado) {
    case REPOSO: return "libre";
    case MEZCLANDO: return "mezclando";
    case CONTEO_REGRESIVO: return "conteo_regresivo";
    case DISPENSANDO: return "dispensando";
    case ESPERANDO_VASO: return "esperando_vaso";
    case MOSTRANDO_GRACIAS: return "finalizando";
    case MOSTRANDO_CANCELADO: return "cancelado";
    default: return "libre";
  }
}

String productoTelemetriaActual() {
  if (etiquetaActual != "" &&
      estado != REPOSO &&
      estado != MEZCLANDO) {
    return "Chicha " + etiquetaActual;
  }

  return "Chicha";
}

void procesarTelemetriaPendiente() {
  if (!telemetriaPendiente || WiFi.status() != WL_CONNECTED) {
    return;
  }

  unsigned long ahora = millis();
  unsigned long intervalo = ultimoEnvioTelemetriaFallo
    ? INTERVALO_REINTENTO_TELEMETRIA
    : INTERVALO_MINIMO_TELEMETRIA;

  if (ahora - ultimoIntentoTelemetria < intervalo) {
    return;
  }

  ultimoIntentoTelemetria = ahora;
  bool enviado = enviarTelemetriaRTDB();
  telemetriaPendiente = !enviado;
  ultimoEnvioTelemetriaFallo = !enviado;
}

bool enviarTelemetriaRTDB() {
  if (!asegurarAutenticacionFirebase()) {
    return false;
  }

  // Se consulta el nivel lógico de las salidas para publicar el estado físico
  // comandado, incluso si una transición futura no pasa por los auxiliares.
  bombaActivaFisica = digitalRead(PIN_BOMBA) == LOW;
  agitadorActivoFisico =
    digitalRead(PIN_MOTOR1_IN1) == HIGH &&
    digitalRead(PIN_MOTOR1_IN2) == LOW &&
    digitalRead(PIN_MOTOR2_IN3) == HIGH &&
    digitalRead(PIN_MOTOR2_IN4) == LOW;

  String payload = "{\"estado\":\"" + estadoTelemetriaActual() +
    "\",\"bomba\":" + (bombaActivaFisica ? "true" : "false") +
    ",\"agitador\":" + (agitadorActivoFisico ? "true" : "false") +
    ",\"productoactual\":\"" + productoTelemetriaActual() + "\"";

  // Sin una medición válida se preservan distancia/nivel previos en RTDB.
  if (distanciaValida) {
    payload += ",\"distanciaCm\":" + String(ultimaDistanciaValidaCm, 2) +
      ",\"nivelliquido\":" + String(ultimoNivelProvisional);
  }

  payload += "}";

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(1500);

  HTTPClient http;
  http.setTimeout(1500);

  String urlAutenticada = String(RTDB_DISPENSADOR_URL) +
    "?auth=" + firebaseIdToken;

  if (!http.begin(client, urlAutenticada)) {
    Serial.println("[RTDB] No se pudo iniciar la telemetria.");
    return false;
  }

  http.addHeader("Content-Type", "application/json");
  int codigo = http.PATCH(payload);
  http.end();

  if (codigo >= 200 && codigo < 300) {
    Serial.print("[RTDB] Telemetria actualizada. HTTP ");
    Serial.println(codigo);
    return true;
  }

  if (codigo == 401) {
    firebaseIdToken = "";
    vencimientoTokenFirebase = 0;
    forzarRenovacionToken = true;
    ultimoIntentoAuth = 0;
    Serial.println("[AUTH] Token rechazado; se renovara antes del reintento.");
  }

  Serial.print("[RTDB] Telemetria pendiente. HTTP ");
  Serial.println(codigo);
  return false;
}

// ==========================================
// 8. DIAGNÓSTICO Y LECTURA DE PULSADORES
// ==========================================
void diagnosticoHardware() {
  Serial.println("\n========= CHEQUEO DE HARDWARE =========");
  Serial.println("[OK] Motor 1         -> GPIO23 / GPIO22");
  Serial.println("[OK] Motor 2         -> GPIO21 / GPIO19");
  Serial.println("[OK] Rele Bomba      -> GPIO4 (activo LOW)");
  Serial.println("[OK] Sensor HC-SR04  -> TRIG:16 / ECHO:17");
  Serial.println("[OK] Boton Opcion 1  -> GPIO34 (45ml, pull-up externo)");
  Serial.println("[OK] Boton Opcion 2  -> GPIO35 (150ml, pull-up externo)");
  Serial.println("[OK] Boton Opcion 3  -> GPIO32 (250ml)");
  Serial.println("[OK] Boton Opcion 4  -> GPIO33 (500ml)");
  Serial.println("[OK] Boton Opcion 5  -> GPIO25 (750ml)");
  Serial.println("[OK] Boton Opcion 6  -> GPIO26 (1 Litro)");
  Serial.println("[OK] Boton CANCELAR  -> GPIO27");
  Serial.println("[OK] LCD I2C         -> SDA:14 / SCL:13");
  Serial.println("========================================\n");
}

void medirDistanciaUltrasonica() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);

  unsigned long duracion = pulseIn(PIN_ECHO, HIGH, 30000);
  if (duracion == 0) {
    Serial.println("[SENSOR] Sin eco dentro del tiempo limite.");
    return;
  }

  float distanciaCm = (duracion * 0.0343f) / 2.0f;
  Serial.print("[SENSOR] Distancia: ");
  Serial.print(distanciaCm, 2);
  Serial.println(" cm");

  ultimaDistanciaValidaCm = distanciaCm;
  ultimoNivelProvisional = calcularNivelProvisional(distanciaCm);
  distanciaValida = true;
  marcarTelemetriaPendiente();
}

int calcularNivelProvisional(float distanciaCm) {
  float porcentaje =
    (DISTANCIA_PROVISIONAL_VACIO_CM - distanciaCm) /
    (DISTANCIA_PROVISIONAL_VACIO_CM - DISTANCIA_PROVISIONAL_LLENO_CM) *
    100.0f;

  if (porcentaje < 0.0f) porcentaje = 0.0f;
  if (porcentaje > 100.0f) porcentaje = 100.0f;

  return (int)(porcentaje + 0.5f);
}

void verificarPulsadores() {
  if (millis() - ultimoTiempoRebote < DELAY_REBOTE) return;

  // 1. CANCELAR: máxima prioridad, funciona en cualquier estado excepto REPOSO/MEZCLANDO sin nada que cancelar
  if (digitalRead(PIN_BTN_CANCEL) == LOW) {
    delay(40);
    if (digitalRead(PIN_BTN_CANCEL) == LOW) {
      ultimoTiempoRebote = millis();
      if (estado == DISPENSANDO || estado == CONTEO_REGRESIVO) {
        cancelarTodo("BOTON FISICO (GPIO27)");
      }
      return;
    }
  }

  // 2. Si el sistema no está libre (REPOSO/MEZCLANDO), no acepta nuevas selecciones
  if (estado != REPOSO && estado != MEZCLANDO) return;

  // 3. Botones de despacho
  if (digitalRead(PIN_BTN_1) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_1) == LOW) { ultimoTiempoRebote = millis(); prepararRegistroFisico(1); solicitarSeleccion(1, "PULSADOR FISICO (GPIO34)"); }
  }
  else if (digitalRead(PIN_BTN_2) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_2) == LOW) { ultimoTiempoRebote = millis(); prepararRegistroFisico(2); solicitarSeleccion(2, "PULSADOR FISICO (GPIO35)"); }
  }
  else if (digitalRead(PIN_BTN_3) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_3) == LOW) { ultimoTiempoRebote = millis(); prepararRegistroFisico(3); solicitarSeleccion(3, "PULSADOR FISICO (GPIO32)"); }
  }
  else if (digitalRead(PIN_BTN_4) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_4) == LOW) { ultimoTiempoRebote = millis(); prepararRegistroFisico(4); solicitarSeleccion(4, "PULSADOR FISICO (GPIO33)"); }
  }
  else if (digitalRead(PIN_BTN_5) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_5) == LOW) { ultimoTiempoRebote = millis(); prepararRegistroFisico(5); solicitarSeleccion(5, "PULSADOR FISICO (GPIO25)"); }
  }
  else if (digitalRead(PIN_BTN_6) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_6) == LOW) { ultimoTiempoRebote = millis(); prepararRegistroFisico(6); solicitarSeleccion(6, "PULSADOR FISICO (GPIO26)"); }
  }
}

// ==========================================
// 9. CONTROL DE RELÉS Y ESTADOS
// ==========================================
void encenderMezclador() {
  digitalWrite(PIN_MOTOR1_IN1, HIGH);
  digitalWrite(PIN_MOTOR1_IN2, LOW);
  digitalWrite(PIN_MOTOR2_IN3, HIGH);
  digitalWrite(PIN_MOTOR2_IN4, LOW);
  agitadorActivoFisico = true;
  marcarTelemetriaPendiente();
  Serial.println("[MOTOR] Mezcladores ACTIVADOS.");
}

void apagarMezclador() {
  digitalWrite(PIN_MOTOR1_IN1, LOW);
  digitalWrite(PIN_MOTOR1_IN2, LOW);
  digitalWrite(PIN_MOTOR2_IN3, LOW);
  digitalWrite(PIN_MOTOR2_IN4, LOW);
  agitadorActivoFisico = false;
  marcarTelemetriaPendiente();
  Serial.println("[MOTOR] Mezcladores DESACTIVADOS.");
}

void encenderBomba() {
  digitalWrite(PIN_BOMBA, LOW);
  bombaActivaFisica = true;
  marcarTelemetriaPendiente();
  Serial.println("[BOMBA] Despachando chicha...");
}

void apagarBomba() {
  digitalWrite(PIN_BOMBA, HIGH);
  bombaActivaFisica = false;
  marcarTelemetriaPendiente();
  Serial.println("[BOMBA] Servido completado.");
}

void cambiarEstado(EstadoSistema nuevoEstado) {
  estado = nuevoEstado;
  marcaTiempoEstado = millis();
  marcarTelemetriaPendiente();

  forzarRefrescoLCD = true;
  ultimoSegundoLCD = -1;
  mostrarEstadoLCD();
}

void cancelarTodo(String origen) {
  Serial.print("\n[!!!] CANCELACION SOLICITADA DESDE: ");
  Serial.println(origen);

  // Apaga físicamente sin importar en qué sub-estado estábamos
  digitalWrite(PIN_BOMBA, HIGH);
  digitalWrite(PIN_MOTOR1_IN1, LOW);
  digitalWrite(PIN_MOTOR1_IN2, LOW);
  digitalWrite(PIN_MOTOR2_IN3, LOW);
  digitalWrite(PIN_MOTOR2_IN4, LOW);
  bombaActivaFisica = false;
  agitadorActivoFisico = false;
  marcarTelemetriaPendiente();

  etiquetaActual = "";
  opcionPendiente = 0;
  descartarRegistroFisicoActual();

  // Si la operación provenía de Firestore, la cancelación también
  // debe quedar reflejada en la nube.
  if (pedidoFirestoreEnCurso && pedidoFirestoreActualId != "") {
    Serial.println("[Firestore] Marcando pedido como cancelado...");

    bool actualizado = actualizarEstadoPedidoFirestore(
      pedidoFirestoreActualId,
      "cancelado",
      true
    );

    if (actualizado) {
      Serial.println("[Firestore] Pedido cancelado correctamente.");
    } else {
      Serial.println("[Firestore] AVISO: no se pudo registrar la cancelacion.");
    }

    pedidoFirestoreActualId = "";
    pedidoFirestoreEnCurso = false;
    limpiarColaPedidoFirestore();
  }

  Serial.println("[SISTEMA] Operacion cancelada. Sistema en reposo.");
  cambiarEstado(MOSTRANDO_CANCELADO);
}

// Traduce el número de opción a su tiempo de servicio y etiqueta legible
String etiquetaParaOpcion(int opcion, unsigned long &tiempoServicio) {
  switch (opcion) {
    case 1: tiempoServicio = 5000;  return "45ml";
    case 2: tiempoServicio = 13700; return "150ml";
    case 3: tiempoServicio = 18000; return "250ml";
    case 4: tiempoServicio = 39000; return "500ml";
    case 5: tiempoServicio = 60000; return "750ml";
    case 6: tiempoServicio = 81000; return "1 Litro";
    default: tiempoServicio = 0;    return "";
  }
}

// Inicia el flujo: valida la opción, detiene el mezclador si estaba activo,
// y arranca el conteo regresivo 3,2,1 antes de dispensar de verdad.
void solicitarSeleccion(int opcion, String origen) {
  unsigned long tiempoServicio = 0;
  String etiqueta = etiquetaParaOpcion(opcion, tiempoServicio);
  if (etiqueta == "") return; // opción inválida

  Serial.print("\n>>> SELECCION RECIBIDA DESDE: ");
  Serial.print(origen);
  Serial.print(" | Opcion: ");
  Serial.println(etiqueta);

  if (estado == MEZCLANDO) {
    apagarMezclador();
  }

  opcionPendiente = opcion;
  tiempoServicioPendiente = tiempoServicio;
  etiquetaActual = etiqueta;
  origenActual = origen;

  conteoActual = 3;
  marcaConteo = millis();
  cambiarEstado(CONTEO_REGRESIVO);
}

String generarIdRegistroFisico() {
  uint64_t chip = ESP.getEfuseMac();
  secuenciaRegistroFisico++;
  return "fisico_" + String((uint32_t)(chip >> 32), HEX) +
    String((uint32_t)chip, HEX) + "_" + String(millis()) +
    "_" + String(secuenciaRegistroFisico);
}

void prepararRegistroFisico(int opcion) {
  registroFisicoActualId = generarIdRegistroFisico();
  opcionFisicaActual = opcion;
}

void descartarRegistroFisicoActual() {
  registroFisicoActualId = "";
  opcionFisicaActual = 0;
}

void encolarRegistroFisicoCompletado() {
  if (registroFisicoActualId == "" || opcionFisicaActual < 1 ||
      opcionFisicaActual > 6) {
    return;
  }

  if (totalRegistrosFisicos >= MAX_REGISTROS_FISICOS_PENDIENTES) {
    Serial.println("[FISICO] Cola de registros llena; operacion no sincronizada.");
    descartarRegistroFisicoActual();
    return;
  }

  int posicion =
    (inicioRegistrosFisicos + totalRegistrosFisicos) %
    MAX_REGISTROS_FISICOS_PENDIENTES;
  registrosFisicosPendientes[posicion].id = registroFisicoActualId;
  registrosFisicosPendientes[posicion].opcion = opcionFisicaActual;
  totalRegistrosFisicos++;

  Serial.print("[FISICO] Dispensacion terminada; registro pendiente: ");
  Serial.println(registroFisicoActualId);
  descartarRegistroFisicoActual();
}

void procesarRegistrosFisicosPendientes() {
  if (totalRegistrosFisicos <= 0 || WiFi.status() != WL_CONNECTED) return;

  unsigned long ahora = millis();
  if (ultimoIntentoRegistroFisico != 0 &&
      ahora - ultimoIntentoRegistroFisico <
        INTERVALO_REINTENTO_REGISTRO_FISICO) {
    return;
  }

  ultimoIntentoRegistroFisico = ahora;
  RegistroFisicoPendiente &registro =
    registrosFisicosPendientes[inicioRegistrosFisicos];

  if (!registrarDispensacionFisicaFirestore(registro)) return;

  Serial.print("[FISICO] Registro confirmado: ");
  Serial.println(registro.id);
  registro.id = "";
  registro.opcion = 0;
  inicioRegistrosFisicos =
    (inicioRegistrosFisicos + 1) % MAX_REGISTROS_FISICOS_PENDIENTES;
  totalRegistrosFisicos--;
  ultimoIntentoRegistroFisico = 0;
}

bool registrarDispensacionFisicaFirestore(
  const RegistroFisicoPendiente &registro
) {
  if (!asegurarAutenticacionFirebase()) return false;

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(2000);
  HTTPClient http;
  http.setTimeout(2000);

  String queryUrl = "https://firestore.googleapis.com/v1/projects/" +
    String(PROJECT_ID) +
    "/databases/(default)/documents:runQuery?key=" + String(API_KEY);

  if (!http.begin(client, queryUrl)) return false;
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " + firebaseIdToken);

  String query =
    "{\"structuredQuery\":{\"from\":[{\"collectionId\":\"productos\"}],"
    "\"where\":{\"fieldFilter\":{\"field\":{\"fieldPath\":\"opcion\"},"
    "\"op\":\"EQUAL\",\"value\":{\"integerValue\":\"" +
    String(registro.opcion) + "\"}}},\"limit\":1}}";

  int codigoProducto = http.POST(query);
  String respuestaProducto = http.getString();
  http.end();

  if (codigoProducto == 401) {
    firebaseIdToken = "";
    vencimientoTokenFirebase = 0;
    forzarRenovacionToken = true;
    ultimoIntentoAuth = 0;
    return false;
  }

  if (codigoProducto < 200 || codigoProducto >= 300 ||
      respuestaProducto.indexOf("\"document\"") < 0) {
    Serial.print("[FISICO] No se pudo consultar producto. HTTP ");
    Serial.println(codigoProducto);
    return false;
  }

  int limite = respuestaProducto.length();
  String nombreDocumento = extraerTextoJson(respuestaProducto, "name");
  String productoId = nombreDocumento.substring(nombreDocumento.lastIndexOf('/') + 1);
  String bebidaId = extraerTextoFirestore(
    respuestaProducto, "bebidaId", 0, limite, "chicha_tradicional");
  String tipoBebida = extraerTextoFirestore(
    respuestaProducto, "tipoBebida", 0, limite, "chicha");
  String nombre = extraerTextoFirestore(
    respuestaProducto, "nombre", 0, limite, "Chicha");
  int cantidadMl = extraerEnteroFirestore(
    respuestaProducto, "cantidadMl", 0, limite, 0);
  double precio = extraerDecimalFirestore(
    respuestaProducto, "precio", 0, limite, 0.0);
  bool esGratis = extraerBooleanoFirestore(
    respuestaProducto, "esGratis", 0, limite, false);

  if (productoId == "" || cantidadMl <= 0 || precio < 0) {
    Serial.println("[FISICO] Producto incompleto; registro pospuesto.");
    return false;
  }

  String nombrePedido = "projects/" + String(PROJECT_ID) +
    "/databases/(default)/documents/pedidos/" + registro.id;
  String precioTexto = String(precio, 2);
  String camposItem =
    "\"productoId\":{\"stringValue\":\"" + escaparJson(productoId) + "\"},"
    "\"bebidaId\":{\"stringValue\":\"" + escaparJson(bebidaId) + "\"},"
    "\"tipoBebida\":{\"stringValue\":\"" + escaparJson(tipoBebida) + "\"},"
    "\"nombre\":{\"stringValue\":\"" + escaparJson(nombre) + "\"},"
    "\"cantidadMl\":{\"integerValue\":\"" + String(cantidadMl) + "\"},"
    "\"opcion\":{\"integerValue\":\"" + String(registro.opcion) + "\"},"
    "\"precioUnitario\":{\"doubleValue\":" + precioTexto + "},"
    "\"cantidad\":{\"integerValue\":\"1\"},"
    "\"subtotal\":{\"doubleValue\":" + precioTexto + "},"
    "\"esGratis\":{\"booleanValue\":" + (esGratis ? "true" : "false") + "}";

  String campos =
    "\"pedidoId\":{\"stringValue\":\"" + registro.id + "\"},"
    "\"tipoUsuario\":{\"stringValue\":\"fisico\"},"
    "\"usuarioId\":{\"nullValue\":null},"
    "\"sesionInvitadoId\":{\"nullValue\":null},"
    "\"nombreUsuario\":{\"stringValue\":\"Venta fisica\"},"
    "\"email\":{\"stringValue\":\"\"},"
    "\"origenPedido\":{\"stringValue\":\"pulsador\"},"
    "\"items\":{\"arrayValue\":{\"values\":[{\"mapValue\":{\"fields\":{" +
      camposItem + "}}}]}},"
    "\"cantidadItems\":{\"integerValue\":\"1\"},"
    "\"cantidadTotalMl\":{\"integerValue\":\"" + String(cantidadMl) + "\"},"
    "\"subtotal\":{\"doubleValue\":" + precioTexto + "},"
    "\"total\":{\"doubleValue\":" + precioTexto + "},"
    "\"metodoPago\":{\"stringValue\":\"efectivo\"},"
    "\"estadoPago\":{\"stringValue\":\"aprobado\"},"
    "\"estado\":{\"stringValue\":\"entregado\"},"
    "\"procesado\":{\"booleanValue\":true},"
    "\"ticketImpreso\":{\"booleanValue\":false},"
    "\"fechaImpresion\":{\"nullValue\":null},"
    "\"intentosImpresion\":{\"integerValue\":\"0\"}";

  String commit = "{\"writes\":[{\"update\":{\"name\":\"" +
    nombrePedido + "\",\"fields\":{" + campos + "}},"
    "\"updateTransforms\":["
    "{\"fieldPath\":\"fechaCreacion\",\"setToServerValue\":\"REQUEST_TIME\"},"
    "{\"fieldPath\":\"fechaProcesado\",\"setToServerValue\":\"REQUEST_TIME\"},"
    "{\"fieldPath\":\"fechaEntregado\",\"setToServerValue\":\"REQUEST_TIME\"}]}]}";

  String commitUrl = "https://firestore.googleapis.com/v1/projects/" +
    String(PROJECT_ID) +
    "/databases/(default)/documents:commit?key=" + String(API_KEY);

  if (!http.begin(client, commitUrl)) return false;
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " + firebaseIdToken);
  int codigoCommit = http.POST(commit);
  http.end();

  if (codigoCommit == 401) {
    firebaseIdToken = "";
    vencimientoTokenFirebase = 0;
    forzarRenovacionToken = true;
    ultimoIntentoAuth = 0;
    return false;
  }

  if (codigoCommit < 200 || codigoCommit >= 300) {
    Serial.print("[FISICO] Registro pendiente. HTTP ");
    Serial.println(codigoCommit);
    return false;
  }

  return true;
}

// ==========================================
// 10. PANTALLA LCD I2C
// ==========================================
void inicializarLCD() {
  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setClock(100000);

  int status = lcd.begin(LCD_COLS, LCD_ROWS);
  if (status) {
    // No se pudo inicializar el LCD: imprime el código de error en el Monitor Serial
    Serial.print("[LCD] ERROR al inicializar, codigo: ");
    Serial.println(status);
    hd44780::fatalError(status); // parpadea el LED integrado para señalar el fallo
    return;
  }

  lcd.backlight();
  lcd.clear();
  delay(20);

  ultimaLineaLCD1 = "";
  ultimaLineaLCD2 = "";
  forzarRefrescoLCD = true;

  mostrarMensaje("CHICHEJ", "Iniciando...");
}

// Escribe exactamente 16 caracteres por línea.
// Solo escribe cuando el contenido realmente cambia.
void mostrarMensaje(String linea1, String linea2) {
  while (linea1.length() < LCD_COLS) linea1 += " ";
  while (linea2.length() < LCD_COLS) linea2 += " ";

  linea1 = linea1.substring(0, LCD_COLS);
  linea2 = linea2.substring(0, LCD_COLS);

  if (!forzarRefrescoLCD &&
      linea1 == ultimaLineaLCD1 &&
      linea2 == ultimaLineaLCD2) {
    return;
  }

  lcd.setCursor(0, 0);
  lcd.print(linea1);
  lcd.setCursor(0, 1);
  lcd.print(linea2);

  ultimaLineaLCD1 = linea1;
  ultimaLineaLCD2 = linea2;
  forzarRefrescoLCD = false;
}


// Limpieza excepcional; no se usa continuamente.
void limpiarLCDSeguro() {
  lcd.clear();
  delay(20);

  ultimaLineaLCD1 = "";
  ultimaLineaLCD2 = "";
  ultimoSegundoLCD = -1;
  forzarRefrescoLCD = true;
}


// Una sola función es dueña de lo que muestra el LCD.
void mostrarEstadoLCD() {
  switch (estado) {
    case REPOSO:
      mostrarMensaje(
        "CHICHEJ LISTO",
        WiFi.status() == WL_CONNECTED
          ? "Esperando pedido"
          : "WiFi sin conexion"
      );
      break;

    case MEZCLANDO:
      mostrarMensaje("Mezclando...", "Chicha");
      break;

    case CONTEO_REGRESIVO:
      mostrarMensaje(
        "Dispensa en:",
        String(conteoActual) + "..."
      );
      break;

    case DISPENSANDO: {
      long restanteMs = (long)(tiempoFinServicio - millis());
      if (restanteMs < 0) restanteMs = 0;

      int restanteSeg = restanteMs / 1000;
      if (restanteMs > 0) restanteSeg++;

      if (!forzarRefrescoLCD &&
          restanteSeg == ultimoSegundoLCD) {
        return;
      }

      ultimoSegundoLCD = restanteSeg;

      String linea1;
      if (pedidoFirestoreEnCurso &&
          totalTrabajosPedido > 1 &&
          indiceTrabajoActual >= 0) {
        linea1 =
          "P" + String(indiceTrabajoActual + 1) +
          "/" + String(totalTrabajosPedido) +
          " " + etiquetaActual;
      } else {
        linea1 = "Sirviendo " + etiquetaActual;
      }

      mostrarMensaje(
        linea1,
        "Restan " + String(restanteSeg) + "s"
      );
      break;
    }

    case ESPERANDO_VASO: {
      int siguienteIndice = indiceTrabajoActual + 1;
      String siguiente = "";

      if (siguienteIndice >= 0 &&
          siguienteIndice < totalTrabajosPedido) {
        unsigned long tiempoDummy = 0;
        siguiente = etiquetaParaOpcion(
          colaOpciones[siguienteIndice],
          tiempoDummy
        );
      }

      mostrarMensaje(
        "Cambie el vaso",
        "Sig: " + siguiente
      );
      break;
    }

    case MOSTRANDO_GRACIAS:
      mostrarMensaje("Pedido completo", "Gracias :)");
      break;

    case MOSTRANDO_CANCELADO:
      mostrarMensaje("Pedido cancelado", "Sistema listo");
      break;
  }
}


// Compatibilidad con la estructura anterior.
void actualizarLCD() {
  mostrarEstadoLCD();
}


// ==========================================
// 11. CONSULTA Y ACTUALIZACIÓN EN FIRESTORE
// ==========================================
void verificarPedidosPendientes() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(4000);

  HTTPClient http;

  // V2.2.1:
  // Ya no listamos toda la colección /pedidos.
  // Firestore devuelve directamente SOLO documentos con estado = pendiente.
  // Esto evita que un pedido nuevo quede fuera de la primera página cuando
  // la colección ya contiene muchos pedidos de pruebas anteriores.
  String url =
    "https://firestore.googleapis.com/v1/projects/"
    + String(PROJECT_ID)
    + "/databases/(default)/documents:runQuery?key="
    + String(API_KEY);

  if (!http.begin(client, url)) {
    Serial.println("[Firestore] No se pudo iniciar consulta runQuery.");
    return;
  }

  http.addHeader("Content-Type", "application/json");

  String payload =
    "{"
      "\"structuredQuery\":{"
        "\"from\":[{\"collectionId\":\"pedidos\"}],"
        "\"where\":{"
          "\"fieldFilter\":{"
            "\"field\":{\"fieldPath\":\"estado\"},"
            "\"op\":\"EQUAL\","
            "\"value\":{\"stringValue\":\"pendiente\"}"
          "}"
        "}"
      "}"
    "}";

  int httpCode = http.POST(payload);

  if (DEBUG_FIRESTORE_VERBOSE) {
    Serial.println();
    Serial.println("========== FIRESTORE RUNQUERY ==========");
    Serial.print("HTTP Code: ");
    Serial.println(httpCode);
  }

  if (httpCode != HTTP_CODE_OK) {
    Serial.print("[Firestore] Error HTTP runQuery: ");
    Serial.println(httpCode);

    String errorBody = http.getString();

    if (errorBody.length() > 0) {
      Serial.println(errorBody);
    }

    http.end();
    return;
  }

  String response = http.getString();

  if (DEBUG_FIRESTORE_VERBOSE) {
    Serial.println(response);
  }

  // Si no aparece ningún document/name, no hay pendientes.
  int inicioDoc = response.indexOf("\"name\"");

  if (inicioDoc == -1) {
    http.end();
    return;
  }

  while (inicioDoc != -1) {
    int siguienteDoc = response.indexOf("\"name\"", inicioDoc + 6);
    int finDoc = siguienteDoc != -1
      ? siguienteDoc
      : response.length();

    String documento = response.substring(
      inicioDoc,
      finDoc
    );

    // La consulta ya garantiza estado=pendiente.
    // IMPORTANTE V2.2.2:
    // Se lee específicamente el booleano del campo "procesado".
    // Antes se buscaba cualquier booleanValue=true del documento.
    // Eso hacía que la muestra gratis (esGratis=true) pareciera
    // erróneamente un pedido ya procesado.
    bool yaProcesado = extraerBooleanoFirestore(
      documento,
      "procesado",
      0,
      documento.length(),
      false
    );

    if (!yaProcesado) {
      int inicioID = documento.indexOf("/pedidos/");
      String docID = "";

      if (inicioID != -1) {
        inicioID += 9;

        int finID = documento.indexOf(
          "\"",
          inicioID
        );

        if (finID != -1) {
          docID = documento.substring(
            inicioID,
            finID
          );
        }
      }

      if (docID != "") {
        Serial.println();
        Serial.println(
          "[Firestore] Pedido pendiente encontrado."
        );
        Serial.print("  ID: ");
        Serial.println(docID);

        procesarPedidoFirestoreConItems(
          documento,
          docID
        );

        http.end();
        return;
      }
    }

    inicioDoc = siguienteDoc;
  }

  http.end();
}


// ============================================================
// LECTURA SEGURA DE BOOLEANOS FIRESTORE
// ============================================================
bool extraerBooleanoFirestore(
  const String &texto,
  const String &campo,
  int desde,
  int hasta,
  bool valorDefecto
) {
  String llave = "\"" + campo + "\"";
  int posCampo = texto.indexOf(llave, desde);

  if (posCampo == -1 || posCampo >= hasta) {
    return valorDefecto;
  }

  int posTipo = texto.indexOf("\"booleanValue\"", posCampo);

  if (posTipo == -1 || posTipo >= hasta) {
    return valorDefecto;
  }

  // Para evitar tomar el booleano de otro campo posterior,
  // limitamos la búsqueda a una ventana corta después de "procesado".
  int limiteCampo = posTipo + 80;
  if (limiteCampo > hasta) {
    limiteCampo = hasta;
  }

  int posTrue = texto.indexOf("true", posTipo);
  int posFalse = texto.indexOf("false", posTipo);

  if (
    posTrue != -1 &&
    posTrue < limiteCampo &&
    (posFalse == -1 || posTrue < posFalse)
  ) {
    return true;
  }

  if (posFalse != -1 && posFalse < limiteCampo) {
    return false;
  }

  return valorDefecto;
}


// ============================================================
// PARSER ESPECIFICO DE items[] DE FIRESTORE
// ============================================================
int buscarCierreBalanceado(
  const String &texto,
  int inicio,
  char apertura,
  char cierre
) {
  if (inicio < 0 || inicio >= (int)texto.length()) {
    return -1;
  }

  int profundidad = 0;
  bool dentroCadena = false;
  bool escape = false;

  for (int i = inicio; i < (int)texto.length(); i++) {
    char c = texto.charAt(i);

    if (dentroCadena) {
      if (escape) {
        escape = false;
      } else if (c == '\\') {
        escape = true;
      } else if (c == '"') {
        dentroCadena = false;
      }
      continue;
    }

    if (c == '"') {
      dentroCadena = true;
      continue;
    }

    if (c == apertura) {
      profundidad++;
    } else if (c == cierre) {
      profundidad--;

      if (profundidad == 0) {
        return i;
      }
    }
  }

  return -1;
}


int extraerEnteroFirestore(
  const String &texto,
  const String &campo,
  int desde,
  int hasta,
  int valorDefecto
) {
  String llave = "\"" + campo + "\"";
  int posCampo = texto.indexOf(llave, desde);

  if (posCampo == -1 || posCampo >= hasta) {
    return valorDefecto;
  }

  int posTipo = texto.indexOf("\"integerValue\"", posCampo);

  if (posTipo == -1 || posTipo >= hasta) {
    return valorDefecto;
  }

  int dosPuntos = texto.indexOf(":", posTipo);

  if (dosPuntos == -1 || dosPuntos >= hasta) {
    return valorDefecto;
  }

  int inicioValor = dosPuntos + 1;

  while (
    inicioValor < hasta &&
    (
      texto.charAt(inicioValor) == ' ' ||
      texto.charAt(inicioValor) == '\n' ||
      texto.charAt(inicioValor) == '\r' ||
      texto.charAt(inicioValor) == '\t' ||
      texto.charAt(inicioValor) == '"'
    )
  ) {
    inicioValor++;
  }

  int finValor = inicioValor;

  while (
    finValor < hasta &&
    (
      isDigit(texto.charAt(finValor)) ||
      texto.charAt(finValor) == '-'
    )
  ) {
    finValor++;
  }

  if (finValor <= inicioValor) {
    return valorDefecto;
  }

  return texto.substring(inicioValor, finValor).toInt();
}

String extraerTextoFirestore(
  const String &texto,
  const String &campo,
  int desde,
  int hasta,
  const String &valorDefecto
) {
  int posCampo = texto.indexOf("\"" + campo + "\"", desde);
  if (posCampo < 0 || posCampo >= hasta) return valorDefecto;

  int posTipo = texto.indexOf("\"stringValue\"", posCampo);
  if (posTipo < 0 || posTipo >= hasta) return valorDefecto;

  int dosPuntos = texto.indexOf(':', posTipo);
  int primeraComilla = texto.indexOf('"', dosPuntos + 1);
  if (dosPuntos < 0 || primeraComilla < 0 || primeraComilla >= hasta) {
    return valorDefecto;
  }

  int fin = primeraComilla + 1;
  bool escapado = false;
  while (fin < hasta) {
    char actual = texto.charAt(fin);
    if (actual == '"' && !escapado) {
      return texto.substring(primeraComilla + 1, fin);
    }
    escapado = actual == '\\' && !escapado;
    if (actual != '\\') escapado = false;
    fin++;
  }

  return valorDefecto;
}

double extraerDecimalFirestore(
  const String &texto,
  const String &campo,
  int desde,
  int hasta,
  double valorDefecto
) {
  int posCampo = texto.indexOf("\"" + campo + "\"", desde);
  if (posCampo < 0 || posCampo >= hasta) return valorDefecto;

  int posDouble = texto.indexOf("\"doubleValue\"", posCampo);
  int posInteger = texto.indexOf("\"integerValue\"", posCampo);
  int posTipo;
  if (posDouble >= 0 && posDouble < hasta &&
      (posInteger < 0 || posDouble < posInteger)) {
    posTipo = posDouble;
  } else if (posInteger >= 0 && posInteger < hasta) {
    posTipo = posInteger;
  } else {
    return valorDefecto;
  }

  int inicio = texto.indexOf(':', posTipo);
  if (inicio < 0 || inicio >= hasta) return valorDefecto;
  inicio++;
  while (inicio < hasta &&
         (texto.charAt(inicio) == ' ' || texto.charAt(inicio) == '"')) {
    inicio++;
  }

  int fin = inicio;
  while (fin < hasta &&
         (isDigit(texto.charAt(fin)) || texto.charAt(fin) == '-' ||
          texto.charAt(fin) == '+' || texto.charAt(fin) == '.' ||
          texto.charAt(fin) == 'e' || texto.charAt(fin) == 'E')) {
    fin++;
  }

  if (fin <= inicio) return valorDefecto;
  return texto.substring(inicio, fin).toDouble();
}


void limpiarColaPedidoFirestore() {
  totalTrabajosPedido = 0;
  indiceTrabajoActual = -1;

  for (int i = 0; i < MAX_TRABAJOS_PEDIDO; i++) {
    colaOpciones[i] = 0;
  }
}


bool cargarTrabajosDesdeDocumento(String documento) {
  limpiarColaPedidoFirestore();

  int posItems = documento.indexOf("\"items\"");

  if (posItems == -1) {
    Serial.println("[Firestore] ERROR: el pedido no contiene items[].");
    return false;
  }

  int posValues = documento.indexOf("\"values\"", posItems);

  if (posValues == -1) {
    Serial.println("[Firestore] ERROR: items no contiene values.");
    return false;
  }

  int inicioArray = documento.indexOf("[", posValues);

  if (inicioArray == -1) {
    Serial.println("[Firestore] ERROR: no se encontro array de items.");
    return false;
  }

  int finArray = buscarCierreBalanceado(
    documento,
    inicioArray,
    '[',
    ']'
  );

  if (finArray == -1) {
    Serial.println("[Firestore] ERROR: array items incompleto.");
    return false;
  }

  int cursor = inicioArray + 1;

  while (cursor < finArray) {
    int posMapValue = documento.indexOf("\"mapValue\"", cursor);

    if (posMapValue == -1 || posMapValue >= finArray) {
      break;
    }

    int inicioObjeto = documento.indexOf("{", posMapValue);

    if (inicioObjeto == -1 || inicioObjeto >= finArray) {
      break;
    }

    int finObjeto = buscarCierreBalanceado(
      documento,
      inicioObjeto,
      '{',
      '}'
    );

    if (finObjeto == -1 || finObjeto > finArray) {
      break;
    }

    int opcion = extraerEnteroFirestore(
      documento,
      "opcion",
      inicioObjeto,
      finObjeto,
      0
    );

    int cantidad = extraerEnteroFirestore(
      documento,
      "cantidad",
      inicioObjeto,
      finObjeto,
      1
    );

    if (cantidad < 1) {
      cantidad = 1;
    }

    if (opcion >= 1 && opcion <= 6) {
      for (int unidad = 0; unidad < cantidad; unidad++) {
        if (totalTrabajosPedido >= MAX_TRABAJOS_PEDIDO) {
          Serial.println(
            "[Firestore] AVISO: pedido supera el limite interno de trabajos."
          );
          return totalTrabajosPedido > 0;
        }

        colaOpciones[totalTrabajosPedido] = opcion;
        totalTrabajosPedido++;
      }
    } else {
      Serial.print("[Firestore] AVISO: item con opcion invalida: ");
      Serial.println(opcion);
    }

    cursor = finObjeto + 1;
  }

  Serial.print("[Firestore] Dispensaciones individuales cargadas: ");
  Serial.println(totalTrabajosPedido);

  for (int i = 0; i < totalTrabajosPedido; i++) {
    unsigned long tiempoDummy = 0;
    String etiqueta = etiquetaParaOpcion(
      colaOpciones[i],
      tiempoDummy
    );

    Serial.print("  Trabajo ");
    Serial.print(i + 1);
    Serial.print("/");
    Serial.print(totalTrabajosPedido);
    Serial.print(": opcion ");
    Serial.print(colaOpciones[i]);
    Serial.print(" -> ");
    Serial.println(etiqueta);
  }

  return totalTrabajosPedido > 0;
}


void procesarPedidoFirestoreConItems(
  String documento,
  String docID
) {
  if (!cargarTrabajosDesdeDocumento(documento)) {
    Serial.println(
      "[Firestore] Pedido ignorado: no se pudieron leer items validos."
    );
    return;
  }

  bool reclamado = actualizarEstadoPedidoFirestore(
    docID,
    "procesando",
    false
  );

  if (!reclamado) {
    Serial.println(
      "[Firestore] No se pudo reclamar el pedido. No se dispensara."
    );
    limpiarColaPedidoFirestore();
    return;
  }

  pedidoFirestoreActualId = docID;
  pedidoFirestoreEnCurso = true;
  indiceTrabajoActual = 0;

  Serial.print("[Firestore] Pedido en proceso: ");
  Serial.println(docID);

  unsigned long tiempoDummy = 0;
  String etiqueta = etiquetaParaOpcion(
    colaOpciones[indiceTrabajoActual],
    tiempoDummy
  );

  Serial.print("[Firestore] Iniciando unidad ");
  Serial.print(indiceTrabajoActual + 1);
  Serial.print("/");
  Serial.print(totalTrabajosPedido);
  Serial.print(" -> ");
  Serial.println(etiqueta);

  solicitarSeleccion(
    colaOpciones[indiceTrabajoActual],
    "NUBE FIRESTORE"
  );
}


void finalizarUnidadFirestore() {
  if (!pedidoFirestoreEnCurso) {
    cambiarEstado(MOSTRANDO_GRACIAS);
    return;
  }

  Serial.print("[Firestore] Unidad terminada: ");
  Serial.print(indiceTrabajoActual + 1);
  Serial.print("/");
  Serial.println(totalTrabajosPedido);

  if (indiceTrabajoActual + 1 < totalTrabajosPedido) {
    cambiarEstado(ESPERANDO_VASO);

    int siguienteIndice = indiceTrabajoActual + 1;
    unsigned long tiempoDummy = 0;
    String siguiente = etiquetaParaOpcion(
      colaOpciones[siguienteIndice],
      tiempoDummy
    );

    Serial.print("[Firestore] Cambie el vaso. Siguiente: ");
    Serial.println(siguiente);

    return;
  }

  // Solo aquí terminó TODO el pedido.
  finalizarPedidoFirestoreEntregado();
  limpiarColaPedidoFirestore();
  cambiarEstado(MOSTRANDO_GRACIAS);
}


void iniciarSiguienteTrabajoFirestore() {
  if (
    !pedidoFirestoreEnCurso ||
    pedidoFirestoreActualId == "" ||
    totalTrabajosPedido <= 0
  ) {
    limpiarColaPedidoFirestore();
    cambiarEstado(REPOSO);
    return;
  }

  indiceTrabajoActual++;

  if (indiceTrabajoActual >= totalTrabajosPedido) {
    finalizarPedidoFirestoreEntregado();
    limpiarColaPedidoFirestore();
    cambiarEstado(MOSTRANDO_GRACIAS);
    return;
  }

  unsigned long tiempoDummy = 0;
  String etiqueta = etiquetaParaOpcion(
    colaOpciones[indiceTrabajoActual],
    tiempoDummy
  );

  Serial.print("[Firestore] Iniciando unidad ");
  Serial.print(indiceTrabajoActual + 1);
  Serial.print("/");
  Serial.print(totalTrabajosPedido);
  Serial.print(" -> ");
  Serial.println(etiqueta);

  solicitarSeleccion(
    colaOpciones[indiceTrabajoActual],
    "NUBE FIRESTORE"
  );
}


void procesarPedidoFirestore(int opcion, String docID) {
  // Compatibilidad con pruebas antiguas de un solo item.
  // Los pedidos nuevos usan procesarPedidoFirestoreConItems().
  limpiarColaPedidoFirestore();

  if (opcion < 1 || opcion > 6 || docID == "") {
    return;
  }

  colaOpciones[0] = opcion;
  totalTrabajosPedido = 1;
  indiceTrabajoActual = 0;

  bool reclamado = actualizarEstadoPedidoFirestore(
    docID,
    "procesando",
    false
  );

  if (!reclamado) {
    limpiarColaPedidoFirestore();
    return;
  }

  pedidoFirestoreActualId = docID;
  pedidoFirestoreEnCurso = true;

  solicitarSeleccion(opcion, "NUBE FIRESTORE");
}


// ============================================================
// ACTUALIZA SOLO ESTADO/PROCESADO DE UN PEDIDO
// ============================================================
bool actualizarEstadoPedidoFirestore(
  String docID,
  String nuevoEstado,
  bool procesado
) {
  if (WiFi.status() != WL_CONNECTED || docID == "") {
    return false;
  }

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(3000);

  HTTPClient http;

  String url = "https://firestore.googleapis.com/v1/projects/"
               + String(PROJECT_ID)
               + "/databases/(default)/documents/pedidos/"
               + docID
               + "?updateMask.fieldPaths=estado"
               + "&updateMask.fieldPaths=procesado"
               + "&key="
               + String(API_KEY);

  if (!http.begin(client, url)) {
    return false;
  }

  http.addHeader("Content-Type", "application/json");

  String procesadoTexto = procesado ? "true" : "false";

  String payload = "{";
  payload += "\"fields\":{";
  payload += "\"estado\":{\"stringValue\":\"" + nuevoEstado + "\"},";
  payload += "\"procesado\":{\"booleanValue\":" + procesadoTexto + "}";
  payload += "}}";


  int codigo = http.PATCH(payload);

  if (DEBUG_FIRESTORE_VERBOSE) {
    Serial.print("[Firestore] PATCH estado -> ");
    Serial.print(nuevoEstado);
    Serial.print(" | HTTP ");
    Serial.println(codigo);
  }

  bool ok = (codigo == HTTP_CODE_OK);

  if (!ok) {
    Serial.print("[Firestore] Error al cambiar estado a ");
    Serial.print(nuevoEstado);
    Serial.print(" (HTTP ");
    Serial.print(codigo);
    Serial.println(").");
  }

  http.end();
  return ok;
}


// ============================================================
// FINALIZA PEDIDO DE NUBE DESPUES DE TERMINAR LA BOMBA
// ============================================================
void finalizarPedidoFirestoreEntregado() {
  if (!pedidoFirestoreEnCurso || pedidoFirestoreActualId == "") {
    return;
  }

  Serial.println("[Firestore] Dispensa fisica terminada.");
  Serial.println("[Firestore] Marcando pedido como entregado...");

  bool actualizado = actualizarEstadoPedidoFirestore(
    pedidoFirestoreActualId,
    "entregado",
    true
  );

  if (actualizado) {
    Serial.println("[Firestore] Pedido marcado como entregado.");
  } else {
    Serial.println(
      "[Firestore] AVISO: la bebida fue dispensada, pero no se pudo confirmar entregado en la nube."
    );
  }

  pedidoFirestoreActualId = "";
  pedidoFirestoreEnCurso = false;
}
