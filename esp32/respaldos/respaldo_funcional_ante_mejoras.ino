#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <hd44780.h>
#include <hd44780ioClass/hd44780_I2Cexp.h>

// ==========================================
// 1. CONFIGURACIÓN DE RED Y FIREBASE
// ==========================================
#define WIFI_SSID "Andrux"
#define WIFI_PASSWORD "azul12345"

#define API_KEY "AIzaSyBlEAKk8ipnVA__EStSCJQ0sZEXlQd0Mec"
#define PROJECT_ID "chichej-2026"

// ==========================================
// 2. CONFIGURACIÓN DE PINES Y TIEMPOS
// ==========================================
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
const unsigned long INTERVALO_LCD = 300;

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
        cambiarEstado(MOSTRANDO_GRACIAS);
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
      Serial.println("[WIFI] Conexión perdida, reintentando...");
      WiFi.reconnect();
    }
    else if (estado == REPOSO || estado == MEZCLANDO) {
      if (millis() - ultimoChequeo >= 5000) {
        ultimoChequeo = millis();
        verificarPedidosPendientes();
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

// Escribe hasta 2 líneas de 16 caracteres, rellenando con espacios
// para no dejar residuos del texto anterior en la pantalla.
void mostrarMensaje(String linea1, String linea2) {
  while (linea1.length() < LCD_COLS) linea1 += " ";
  while (linea2.length() < LCD_COLS) linea2 += " ";
  linea1 = linea1.substring(0, LCD_COLS);
  linea2 = linea2.substring(0, LCD_COLS);

  lcd.setCursor(0, 0);
  lcd.print(linea1);
  lcd.setCursor(0, 1);
  lcd.print(linea2);
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
      mostrarMensaje("Sirviendo " + etiquetaActual, "Espere: " + String(restanteSeg) + "s");
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
  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(3000);

  HTTPClient http;

  String url = "https://firestore.googleapis.com/v1/projects/"
               + String(PROJECT_ID)
               + "/databases/(default)/documents/pedidos?key="
               + String(API_KEY);

  if (!http.begin(client, url)) return;

  int httpCode = http.GET();

  if (DEBUG_FIRESTORE_VERBOSE) {
    Serial.println();
    Serial.println("========== FIRESTORE ==========");
    Serial.print("HTTP Code: ");
    Serial.println(httpCode);
  }

  if (httpCode != HTTP_CODE_OK) {
    if (httpCode != HTTP_CODE_OK) {
      Serial.print("[Firestore] Error HTTP: ");
      Serial.println(httpCode);
    }
    http.end();
    return;
  }

  String response = http.getString();
  if (DEBUG_FIRESTORE_VERBOSE) Serial.println(response);

  int inicioDoc = response.indexOf("\"name\"");

  while (inicioDoc != -1) {
    int finDoc = response.indexOf("\"updateTime\"", inicioDoc);
    String documento = response.substring(inicioDoc, finDoc);

    bool esPendiente = documento.indexOf("pendiente") != -1 &&
                        documento.indexOf("\"booleanValue\": true") == -1;

    if (esPendiente) {
      int posOpcion = documento.indexOf("\"integerValue\"");

      if (posOpcion != -1) {
        int inicioValor = documento.indexOf("\"", posOpcion + 15);
        int finValor = documento.indexOf("\"", inicioValor + 1);
        String valor = documento.substring(inicioValor + 1, finValor);
        int opcion = valor.toInt();

        int inicioID = response.indexOf("/pedidos/", inicioDoc);
        String docID = "";
        if (inicioID != -1) {
          inicioID += 9;
          int finID = response.indexOf("\"", inicioID);
          docID = response.substring(inicioID, finID);
        }

        if (opcion >= 1 && opcion <= 6 && docID != "") {
          Serial.println("[Firestore] Pedido pendiente encontrado.");
          Serial.print("  ID: ");
          Serial.print(docID);
          Serial.print(" | Opcion: ");
          Serial.println(opcion);

          procesarPedidoFirestore(opcion, docID);
          http.end();
          return; // evita procesar más de un pedido por ciclo
        }
      }
    }

    inicioDoc = response.indexOf("\"name\"", finDoc);
  }

  http.end();
}

void procesarPedidoFirestore(int opcion, String docID) {
  // Arranca el flujo normal (conteo regresivo -> despacho)
  solicitarSeleccion(opcion, "NUBE FIRESTORE");

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(3000);

  HTTPClient http;

  String url = "https://firestore.googleapis.com/v1/projects/"
               + String(PROJECT_ID)
               + "/databases/(default)/documents/pedidos/"
               + docID
               + "?updateMask.fieldPaths=estado&updateMask.fieldPaths=procesado&key="
               + String(API_KEY);

  if (!http.begin(client, url)) return;

  http.addHeader("Content-Type", "application/json");

  String payload =
    "{"
      "\"fields\":{"
        "\"estado\":{\"stringValue\":\"entregado\"},"
        "\"procesado\":{\"booleanValue\":true}"
      "}"
    "}";

  int codigo = http.PATCH(payload);

  if (codigo == 200) {
    Serial.println("[Firestore] Pedido marcado como entregado.");
  } else {
    Serial.print("[Firestore] Error al actualizar (codigo ");
    Serial.print(codigo);
    Serial.println(").");
  }

  http.end();
}
