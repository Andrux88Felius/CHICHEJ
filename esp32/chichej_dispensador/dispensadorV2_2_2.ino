/*
  chichej_dispensador.ino
  Proyecto: Dispensador de Chicha de Winapu
  Autor: Eduardo Jordy Zeballos Garcia
  Descripción: Firmware V2.2.2. Controla pedidos Firestore por items[], cantidades, relés, pulsadores y LCD I2C.
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

#define API_KEY FIREBASE_API_KEY
#define PROJECT_ID FIREBASE_PROJECT_ID

// ==========================================
// 2. CONFIGURACIÓN DE PINES Y TIEMPOS
// ==========================================
//wi-fi (tiempo de espera)
unsigned long ultimoIntentoConexionWiFi = 0;
const unsigned long INTERVALO_RECONEXION_WIFI = 10000;

// Relés
const int PIN_MEZCLADOR = 33; // Canal 1 del Relé (Mezclador)
const int PIN_BOMBA     = 26; // Canal 2 del Relé (Bomba de despacho)

// Pulsadores físicos
const int PIN_BTN_1      = 21; // Opción 1: Muestra 45ml
const int PIN_BTN_2      = 19; // Opción 2: 150ml
const int PIN_BTN_3      = 18; // Opción 3: 250ml
const int PIN_BTN_4      = 17; // Opción 4: 500ml
const int PIN_BTN_5      = 16; // Opción 5: 750ml
const int PIN_BTN_6      = 4;  // Opción 6: 1 Litro
const int PIN_BTN_CANCEL = 5;  // Botón Físico de CANCELAR (Prioridad Máxima)

// Pantalla LCD I2C (4 pines: VCC, GND, SDA, SCL)
#define I2C_SDA 23
#define I2C_SCL 22
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

// Activar en 'true' solo si necesitas depurar las respuestas de Firestore a detalle
const bool DEBUG_FIRESTORE_VERBOSE = false;

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

// Control de refresco del LCD
unsigned long ultimaActualizacionLCD = 0;
const unsigned long INTERVALO_LCD = 250;

// Evita reescribir continuamente exactamente el mismo texto por I2C.
String ultimaLineaLCD1 = "";
String ultimaLineaLCD2 = "";

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
void verificarPedidosPendientes();
void verificarPulsadores();
void diagnosticoHardware();
void conectarWiFi();
void inicializarLCD();
void mostrarMensaje(String linea1, String linea2 = "");
void actualizarLCD();
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
  Serial.println("FIRMWARE V2.2.2");
  Serial.println("================================");

  pinMode(PIN_MEZCLADOR, OUTPUT);
  pinMode(PIN_BOMBA, OUTPUT);
  digitalWrite(PIN_MEZCLADOR, HIGH); // HIGH = apagado
  digitalWrite(PIN_BOMBA, HIGH);

  pinMode(PIN_BTN_1, INPUT_PULLUP);
  pinMode(PIN_BTN_2, INPUT_PULLUP);
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
          mostrarMensaje("Dispensando en:", String(conteoActual) + "...");
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

  // --- 5. REFRESCO PERIÓDICO DEL LCD (no bloqueante) ---
  // Nota: durante CONTEO_REGRESIVO el mensaje ya se actualiza en su propio bloque,
  // así que aquí lo excluimos para no pisar el número que se está mostrando.
  if (estado != CONTEO_REGRESIVO && tiempoActual - ultimaActualizacionLCD >= INTERVALO_LCD) {
    ultimaActualizacionLCD = tiempoActual;
    actualizarLCD();
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

// ==========================================
// 8. DIAGNÓSTICO Y LECTURA DE PULSADORES
// ==========================================
void diagnosticoHardware() {
  Serial.println("\n========= CHEQUEO DE HARDWARE =========");
  Serial.println("[OK] Rele Mezclador  -> GPIO33");
  Serial.println("[OK] Rele Bomba      -> GPIO26");
  Serial.println("[OK] Boton Opcion 1  -> GPIO21 (45ml)");
  Serial.println("[OK] Boton Opcion 2  -> GPIO19 (150ml)");
  Serial.println("[OK] Boton Opcion 3  -> GPIO18 (250ml)");
  Serial.println("[OK] Boton Opcion 4  -> GPIO17 (500ml)");
  Serial.println("[OK] Boton Opcion 5  -> GPIO16 (750ml)");
  Serial.println("[OK] Boton Opcion 6  -> GPIO4  (1 Litro)");
  Serial.println("[OK] Boton CANCELAR  -> GPIO5");
  Serial.println("[OK] LCD I2C         -> SDA:23 / SCL:22");
  Serial.println("========================================\n");
}

void verificarPulsadores() {
  if (millis() - ultimoTiempoRebote < DELAY_REBOTE) return;

  // 1. CANCELAR: máxima prioridad, funciona en cualquier estado excepto REPOSO/MEZCLANDO sin nada que cancelar
  if (digitalRead(PIN_BTN_CANCEL) == LOW) {
    delay(40);
    if (digitalRead(PIN_BTN_CANCEL) == LOW) {
      ultimoTiempoRebote = millis();
      if (estado == DISPENSANDO || estado == CONTEO_REGRESIVO) {
        cancelarTodo("BOTON FISICO (GPIO 5)");
      }
      return;
    }
  }

  // 2. Si el sistema no está libre (REPOSO/MEZCLANDO), no acepta nuevas selecciones
  if (estado != REPOSO && estado != MEZCLANDO) return;

  // 3. Botones de despacho
  if (digitalRead(PIN_BTN_1) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_1) == LOW) { ultimoTiempoRebote = millis(); solicitarSeleccion(1, "PULSADOR FISICO (GPIO21)"); }
  }
  else if (digitalRead(PIN_BTN_2) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_2) == LOW) { ultimoTiempoRebote = millis(); solicitarSeleccion(2, "PULSADOR FISICO (GPIO19)"); }
  }
  else if (digitalRead(PIN_BTN_3) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_3) == LOW) { ultimoTiempoRebote = millis(); solicitarSeleccion(3, "PULSADOR FISICO (GPIO18)"); }
  }
  else if (digitalRead(PIN_BTN_4) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_4) == LOW) { ultimoTiempoRebote = millis(); solicitarSeleccion(4, "PULSADOR FISICO (GPIO17)"); }
  }
  else if (digitalRead(PIN_BTN_5) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_5) == LOW) { ultimoTiempoRebote = millis(); solicitarSeleccion(5, "PULSADOR FISICO (GPIO16)"); }
  }
  else if (digitalRead(PIN_BTN_6) == LOW) {
    delay(20);
    if (digitalRead(PIN_BTN_6) == LOW) { ultimoTiempoRebote = millis(); solicitarSeleccion(6, "PULSADOR FISICO (GPIO4)"); }
  }
}

// ==========================================
// 9. CONTROL DE RELÉS Y ESTADOS
// ==========================================
void encenderMezclador() {
  digitalWrite(PIN_MEZCLADOR, LOW);
  Serial.println("[MOTOR] Mezclador ACTIVADO.");
}

void apagarMezclador() {
  digitalWrite(PIN_MEZCLADOR, HIGH);
  Serial.println("[MOTOR] Mezclador DESACTIVADO.");
}

void encenderBomba() {
  digitalWrite(PIN_BOMBA, LOW);
  Serial.println("[BOMBA] Despachando chicha...");
}

void apagarBomba() {
  digitalWrite(PIN_BOMBA, HIGH);
  Serial.println("[BOMBA] Servido completado.");
}

void cambiarEstado(EstadoSistema nuevoEstado) {
  estado = nuevoEstado;
  marcaTiempoEstado = millis();

  if (nuevoEstado == MOSTRANDO_GRACIAS) {
    mostrarMensaje("Gracias por su", "compra!");
  }
  else if (nuevoEstado == MOSTRANDO_CANCELADO) {
    mostrarMensaje("Pedido cancelado", "Sistema en reposo");
  }
}

void cancelarTodo(String origen) {
  Serial.print("\n[!!!] CANCELACION SOLICITADA DESDE: ");
  Serial.println(origen);

  // Apaga físicamente sin importar en qué sub-estado estábamos
  digitalWrite(PIN_BOMBA, HIGH);
  digitalWrite(PIN_MEZCLADOR, HIGH);

  etiquetaActual = "";
  opcionPendiente = 0;

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
  mostrarMensaje("Dispensando en:", String(conteoActual) + "...");
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
  mostrarMensaje("Chicha de Winapu", "Iniciando...");
}

// Escribe hasta 2 líneas de 16 caracteres.
// V2.2: solo escribe por I2C cuando el contenido realmente cambia.
// Esto evita "sobre-escrituras" y reduce tráfico innecesario al LCD.
void mostrarMensaje(String linea1, String linea2) {
  while (linea1.length() < LCD_COLS) linea1 += " ";
  while (linea2.length() < LCD_COLS) linea2 += " ";

  linea1 = linea1.substring(0, LCD_COLS);
  linea2 = linea2.substring(0, LCD_COLS);

  if (linea1 == ultimaLineaLCD1 && linea2 == ultimaLineaLCD2) {
    return;
  }

  lcd.setCursor(0, 0);
  lcd.print(linea1);
  lcd.setCursor(0, 1);
  lcd.print(linea2);

  ultimaLineaLCD1 = linea1;
  ultimaLineaLCD2 = linea2;
}

// Refresco periódico para los estados de reposo/mezclando/despachando.
// (El conteo regresivo se maneja aparte, en su propio bloque del loop).
void actualizarLCD() {
  switch (estado) {
    case REPOSO:
      mostrarMensaje("Chicha de Winapu", "Bebida artesanal");
      break;

    case MEZCLANDO:
      mostrarMensaje("Chicha de Winapu", "Preparando...");
      break;

    case DISPENSANDO: {
      long restanteMs = (long)(tiempoFinServicio - millis());
      if (restanteMs < 0) restanteMs = 0;
      int restanteSeg = restanteMs / 1000 + 1;
      mostrarMensaje(
        "Sirviendo " + etiquetaActual,
        "Espere: " + String(restanteSeg) + "s"
      );
      break;
    }

    case ESPERANDO_VASO: {
      int siguienteIndice = indiceTrabajoActual + 1;
      String siguiente = "";

      if (siguienteIndice >= 0 && siguienteIndice < totalTrabajosPedido) {
        unsigned long tiempoDummy = 0;
        siguiente = etiquetaParaOpcion(
          colaOpciones[siguienteIndice],
          tiempoDummy
        );
      }

      mostrarMensaje("Cambie el vaso", "Sig: " + siguiente);
      break;
    }

    default:
      break; // MOSTRANDO_GRACIAS y MOSTRANDO_CANCELADO ya fijaron su mensaje en cambiarEstado()
  }
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

    mostrarMensaje(
      "Cambie el vaso",
      "Sig: " + siguiente
    );

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

