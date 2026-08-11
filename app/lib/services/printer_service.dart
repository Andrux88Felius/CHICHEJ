import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// ===============================================================
/// ITEM DE PEDIDO PARA IMPRESIÓN
/// ===============================================================
///
/// Permite imprimir uno o varios productos en el mismo recibo.
/// Por ahora CHICHEJ puede enviar uno solo, pero ya queda preparado
/// para carrito/pedidos múltiples.
///
class PrinterOrderItem {
  final String productName;
  final int quantityMl;
  final double price;

  const PrinterOrderItem({
    required this.productName,
    required this.quantityMl,
    required this.price,
  });
}

/// ===============================================================
/// SERVICIO IMPRESORA MX06 - CHICHEJ
/// ===============================================================
///
/// Modelo probado:
/// MX06
///
/// BLE:
/// Servicio AE30
/// Característica AE01
/// WRITE WITHOUT RESPONSE
///
/// Ancho:
/// 384 píxeles = 48 bytes por línea.
///
class PrinterService {
  PrinterService._();

  static final PrinterService instance = PrinterService._();

  static const int printerWidth = 384;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;

  StreamSubscription<BluetoothConnectionState>?
      _connectionSubscription;

  bool _connecting = false;
  bool _printing = false;

  String _status = 'Impresora no conectada';
  String? _lastError;

  // ===============================================================
  // ESTADO PÚBLICO
  // ===============================================================

  bool get isConnected =>
      _device != null &&
      _writeCharacteristic != null;

  bool get isConnecting => _connecting;

  bool get isPrinting => _printing;

  String get status => _status;

  String? get lastError => _lastError;

  BluetoothDevice? get device => _device;

  // ===============================================================
  // PERMISOS
  // ===============================================================

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final scan =
        statuses[Permission.bluetoothScan]?.isGranted ??
            false;

    final connect =
        statuses[Permission.bluetoothConnect]?.isGranted ??
            false;

    if (scan && connect) {
      return true;
    }

    _lastError =
        'Falta permiso para dispositivos Bluetooth cercanos';

    _status = _lastError!;

    return false;
  }

  // ===============================================================
  // BUSCAR Y CONECTAR MX06
  // ===============================================================

  Future<bool> connectMx06({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (isConnected) {
      _status = 'MX06 ya está conectada';
      return true;
    }

    if (_connecting) {
      return false;
    }

    _connecting = true;
    _lastError = null;

    try {
      final permissionOk =
          await _requestPermissions();

      if (!permissionOk) {
        return false;
      }

      final adapterState =
          await FlutterBluePlus.adapterState.first;

      if (adapterState !=
          BluetoothAdapterState.on) {
        _lastError =
            'Bluetooth está desactivado';

        _status = _lastError!;

        return false;
      }

      _status = 'Buscando MX06...';

      ScanResult? mx06Result;

      final completer =
          Completer<ScanResult?>();

      late StreamSubscription<
          List<ScanResult>> subscription;

      subscription =
          FlutterBluePlus.scanResults.listen(
        (results) {
          for (final result in results) {
            final name =
                _deviceName(result).toUpperCase();

            if (name.contains('MX06')) {
              mx06Result = result;

              if (!completer.isCompleted) {
                completer.complete(result);
              }

              break;
            }
          }
        },
      );

      await FlutterBluePlus.startScan(
        timeout: timeout,
      );

      final result =
          await Future.any<ScanResult?>([
        completer.future,
        Future<ScanResult?>.delayed(
          timeout,
          () => null,
        ),
      ]);

      await FlutterBluePlus.stopScan();

      await subscription.cancel();

      mx06Result ??= result;

      if (mx06Result == null) {
        _lastError =
            'No se encontró la impresora MX06';

        _status = _lastError!;

        return false;
      }

      _status = 'Conectando a MX06...';

      final device =
          mx06Result!.device;

      await _connectionSubscription?.cancel();

      _connectionSubscription =
          device.connectionState.listen(
        (state) {
          if (state ==
              BluetoothConnectionState.disconnected) {
            _device = null;
            _writeCharacteristic = null;

            _status =
                'MX06 desconectada';
          }
        },
      );

      await device.connect(
        timeout: const Duration(seconds: 15),
        license: License.nonprofit,
      );

      _device = device;

      _status =
          'Descubriendo servicios MX06...';

      final services =
          await device.discoverServices();

      BluetoothCharacteristic?
          printerCharacteristic;

      for (final service in services) {
        final serviceUuid =
            service.uuid
                .toString()
                .toLowerCase();

        if (!serviceUuid.contains('ae30')) {
          continue;
        }

        for (final characteristic
            in service.characteristics) {
          final characteristicUuid =
              characteristic.uuid
                  .toString()
                  .toLowerCase();

          if (characteristicUuid
                  .contains('ae01') &&
              characteristic
                  .properties
                  .writeWithoutResponse) {
            printerCharacteristic =
                characteristic;

            break;
          }
        }
      }

      if (printerCharacteristic == null) {
        await device.disconnect();

        _device = null;

        _lastError =
            'MX06 conectada, pero no se encontró AE01';

        _status = _lastError!;

        return false;
      }

      _writeCharacteristic =
          printerCharacteristic;

      _status =
          'MX06 lista para imprimir';

      return true;
    } catch (e) {
      _lastError =
          'Error conectando MX06: $e';

      _status = _lastError!;

      debugPrint(
        '[PrinterService] $_lastError',
      );

      return false;
    } finally {
      _connecting = false;
    }
  }

  // ===============================================================
  // DESCONECTAR
  // ===============================================================

  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } catch (e) {
      debugPrint(
        '[PrinterService] Error desconectando: $e',
      );
    }

    _device = null;
    _writeCharacteristic = null;

    _status =
        'Impresora desconectada';
  }

  // ===============================================================
  // CRC8 MX06
  // ===============================================================

  int _crc8(List<int> data) {
    int crc = 0;

    for (final byte in data) {
      crc ^= byte;

      for (int i = 0; i < 8; i++) {
        if ((crc & 0x80) != 0) {
          crc =
              ((crc << 1) ^ 0x07) &
                  0xFF;
        } else {
          crc =
              (crc << 1) &
                  0xFF;
        }
      }
    }

    return crc;
  }

  // ===============================================================
  // CREAR PAQUETE MX06
  // ===============================================================

  List<int> _packet(
    int command,
    List<int> data,
  ) {
    final length = data.length;

    return [
      0x51,
      0x78,
      command,
      0x00,
      length & 0xFF,
      (length >> 8) & 0xFF,
      ...data,
      _crc8(data),
      0xFF,
    ];
  }

  // ===============================================================
  // ENVIAR PAQUETE BLE
  // ===============================================================

  Future<void> _send(
    List<int> packet,
  ) async {
    final characteristic =
        _writeCharacteristic;

    if (characteristic == null) {
      throw Exception(
        'MX06 no está conectada',
      );
    }

    await characteristic.write(
      packet,
      withoutResponse: true,
    );

    // La pausa de 3 ms ya funcionó correctamente
    // durante nuestra prueba completa.
    await Future.delayed(
      const Duration(milliseconds: 3),
    );
  }

  // ===============================================================
  // CREAR TICKET CHICHEJ
  // ===============================================================

  Future<ui.Image> _createTicketImage({
    required String customerName,
    required String orderId,
    required List<PrinterOrderItem> items,
    required DateTime dateTime,
  }) async {
    const width = printerWidth;

    // Altura dinámica.
    //
    // Con un producto ronda 460 px.
    // Cada producto adicional añade espacio.
    final height =
        460 +
        ((items.length - 1)
                .clamp(0, 20) *
            70);

    final recorder =
        ui.PictureRecorder();

    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(
        0,
        0,
        width.toDouble(),
        height.toDouble(),
      ),
    );

    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        width.toDouble(),
        height.toDouble(),
      ),
      Paint()
        ..color =
            Colors.white,
    );

    double y = 10;

    // ===========================================================
    // CHICHEJ
    // ===========================================================

    y = _paintCenteredText(
      canvas: canvas,
      text: 'CHICHEJ',
      y: y,
      fontSize: 42,
      fontWeight: FontWeight.bold,
    );

    y += 2;

    y = _paintCenteredText(
      canvas: canvas,
      text:
          'DISPENSADOR INTELIGENTE',
      y: y,
      fontSize: 19,
      fontWeight: FontWeight.bold,
    );

    y += 10;

    _drawDivider(
      canvas,
      y,
    );

    y += 12;

    // ===========================================================
    // PEDIDO
    // ===========================================================

    y = _paintCenteredText(
      canvas: canvas,
      text: 'PEDIDO $orderId',
      y: y,
      fontSize: 25,
      fontWeight: FontWeight.bold,
    );

    y += 12;

    y = _paintLeftText(
      canvas: canvas,
      text: 'Cliente:',
      y: y,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );

    y = _paintLeftText(
      canvas: canvas,
      text: customerName.trim().isEmpty
          ? 'Invitado'
          : customerName,
      y: y,
      fontSize: 22,
      fontWeight: FontWeight.w600,
    );

    y += 10;

    _drawDivider(
      canvas,
      y,
    );

    y += 12;

    // ===========================================================
    // PRODUCTOS
    // ===========================================================

    double total = 0;

    for (int i = 0;
        i < items.length;
        i++) {
      final item = items[i];

      total += item.price;

      y = _paintLeftText(
        canvas: canvas,
        text: item.productName,
        y: y,
        fontSize: 21,
        fontWeight: FontWeight.bold,
      );

      y = _paintLeftText(
        canvas: canvas,
        text:
            '${item.quantityMl} ml   -   Bs ${item.price.toStringAsFixed(2)}',
        y: y,
        fontSize: 19,
        fontWeight: FontWeight.w500,
      );

      if (i < items.length - 1) {
        y += 7;
      }
    }

    y += 10;

    _drawDivider(
      canvas,
      y,
    );

    y += 10;

    // ===========================================================
    // TOTAL
    // ===========================================================

    y = _paintCenteredText(
      canvas: canvas,
      text:
          'TOTAL  Bs ${total.toStringAsFixed(2)}',
      y: y,
      fontSize: 25,
      fontWeight: FontWeight.bold,
    );

    y += 10;

    // ===========================================================
    // FECHA / HORA
    // ===========================================================

    final date =
        '${_twoDigits(dateTime.day)}/'
        '${_twoDigits(dateTime.month)}/'
        '${dateTime.year}';

    final time =
        '${_twoDigits(dateTime.hour)}:'
        '${_twoDigits(dateTime.minute)}';

    y = _paintCenteredText(
      canvas: canvas,
      text: '$date  -  $time',
      y: y,
      fontSize: 18,
      fontWeight: FontWeight.w500,
    );

    y += 12;

    _drawDivider(
      canvas,
      y,
    );

    y += 13;

    // ===========================================================
    // AGRADECIMIENTO
    // ===========================================================

    y = _paintCenteredText(
      canvas: canvas,
      text:
          '¡GRACIAS POR COMPRAR CHICHEJ!',
      y: y,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );

    y += 8;

    y = _paintCenteredText(
      canvas: canvas,
      text:
          '13va Expo Feria Chelito Quiroga 2026',
      y: y,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    );

    y += 5;

    _paintCenteredText(
      canvas: canvas,
      text:
          'Tecnología y tradición',
      y: y,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );

    final picture =
        recorder.endRecording();

    return picture.toImage(
      width,
      height,
    );
  }

  // ===============================================================
  // HELPERS PARA DIBUJAR TEXTO
  // ===============================================================

  double _paintCenteredText({
    required Canvas canvas,
    required String text,
    required double y,
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    final painter =
        TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.1,
        ),
      ),
      textDirection:
          TextDirection.ltr,
      textAlign:
          TextAlign.center,
      maxLines: null,
    );

    painter.layout(
      maxWidth: 350,
    );

    painter.paint(
      canvas,
      Offset(
        (printerWidth -
                painter.width) /
            2,
        y,
      ),
    );

    return y +
        painter.height;
  }

  double _paintLeftText({
    required Canvas canvas,
    required String text,
    required double y,
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    final painter =
        TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.1,
        ),
      ),
      textDirection:
          TextDirection.ltr,
      maxLines: null,
    );

    painter.layout(
      maxWidth: 330,
    );

    painter.paint(
      canvas,
      Offset(
        27,
        y,
      ),
    );

    return y +
        painter.height;
  }

  void _drawDivider(
    Canvas canvas,
    double y,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(
        25,
        y,
        334,
        2,
      ),
      Paint()
        ..color =
            Colors.black,
    );
  }

  // ===============================================================
  // BITMAP -> FILAS DE 48 BYTES
  // ===============================================================

  Future<List<List<int>>> _imageToRows(
    ui.Image image,
  ) async {
    final byteData =
        await image.toByteData(
      format:
          ui.ImageByteFormat.rawRgba,
    );

    if (byteData == null) {
      throw Exception(
        'No se pudo rasterizar el ticket',
      );
    }

    final bytes =
        byteData.buffer.asUint8List();

    final rows =
        <List<int>>[];

    for (int y = 0;
        y < image.height;
        y++) {
      final row =
          List<int>.filled(
        printerWidth ~/ 8,
        0,
      );

      for (int x = 0;
          x < printerWidth;
          x++) {
        final pixelIndex =
            ((y * printerWidth) + x) *
                4;

        final red =
            bytes[pixelIndex];

        final green =
            bytes[pixelIndex + 1];

        final blue =
            bytes[pixelIndex + 2];

        final luminance =
            (red * 0.299) +
            (green * 0.587) +
            (blue * 0.114);

        //
        // Umbral ligeramente más alto.
        //
        // Esto ayuda a engrosar visualmente algunos
        // píxeles sin aumentar excesivamente la energía
        // térmica del cabezal.
        //
        if (luminance < 165) {
          final byteIndex =
              x ~/ 8;

          final bitIndex =
              x % 8;

          row[byteIndex] |=
              (1 << bitIndex);
        }
      }

      rows.add(row);
    }

    return rows;
  }

  // ===============================================================
  // IMPRIMIR PEDIDO REAL
  // ===============================================================

  Future<bool> printOrder({
    required String customerName,
    required String orderId,
    required List<PrinterOrderItem> items,
    DateTime? dateTime,
  }) async {
    if (_printing) {
      _lastError =
          'La impresora ya está procesando otro ticket';

      return false;
    }

    if (items.isEmpty) {
      _lastError =
          'El pedido no contiene productos';

      return false;
    }

    _printing = true;
    _lastError = null;

    try {
      // Si todavía no está conectada,
      // intentamos conectarla automáticamente.
      if (!isConnected) {
        final connected =
            await connectMx06();

        if (!connected) {
          return false;
        }
      }

      _status =
          'Preparando ticket CHICHEJ...';

      final image =
          await _createTicketImage(
        customerName: customerName,
        orderId: orderId,
        items: items,
        dateTime:
            dateTime ??
                DateTime.now(),
      );

      final rows =
          await _imageToRows(
        image,
      );

      // =========================================================
      // CALIDAD
      // =========================================================

      await _send(
        _packet(
          0xA4,
          [
            0x32,
          ],
        ),
      );

      // =========================================================
      // INTENSIDAD
      //
      // 0x3F fue probada físicamente.
      // No la subimos más por ahora.
      // =========================================================

      await _send(
        _packet(
          0xAF,
          [
            0x3F,
            0x00,
          ],
        ),
      );

      // =========================================================
      // ENERGÍA
      // =========================================================

      await _send(
        _packet(
          0xBE,
          [
            0x01,
          ],
        ),
      );

      // =========================================================
      // LATTICE START
      // =========================================================

      const latticeStart = [
        0x51,
        0x78,
        0xA6,
        0x00,
        0x0B,
        0x00,
        0xAA,
        0x55,
        0x17,
        0x38,
        0x44,
        0x5F,
        0x5F,
        0x5F,
        0x44,
        0x38,
        0x2C,
        0xA1,
        0xFF,
      ];

      await _send(
        latticeStart,
      );

      // =========================================================
      // IMPRIMIR FILAS
      // =========================================================

      for (int i = 0;
          i < rows.length;
          i++) {
        if (i % 50 == 0) {
          final percent =
              ((i /
                          rows.length) *
                      100)
                  .round();

          _status =
              'Imprimiendo pedido... $percent%';
        }

        await _send(
          _packet(
            0xA2,
            rows[i],
          ),
        );
      }

      // =========================================================
      // LATTICE END
      // =========================================================

      const latticeEnd = [
        0x51,
        0x78,
        0xA6,
        0x00,
        0x0B,
        0x00,
        0xAA,
        0x55,
        0x17,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x17,
        0x11,
        0xFF,
      ];

      await _send(
        latticeEnd,
      );

      // =========================================================
      // AVANCE FINAL CORTO
      //
      // Dejamos solamente un pequeño margen para cortar,
      // evitando desperdiciar demasiado papel.
      // =========================================================

      await Future.delayed(
        const Duration(
          milliseconds: 200,
        ),
      );

      await _send(
        _packet(
          0xA1,
          [
            0x30,
            0x00,
          ],
        ),
      );

      _status =
          'Pedido impreso correctamente';

      return true;
    } catch (e, stackTrace) {
      _lastError =
          'Error imprimiendo pedido: $e';

      _status =
          _lastError!;

      debugPrint(
        '[PrinterService] $_lastError',
      );

      debugPrint(
        '$stackTrace',
      );

      return false;
    } finally {
      _printing = false;
    }
  }

  // ===============================================================
  // PRUEBA REAL DEL SERVICIO
  // ===============================================================

  Future<bool> printDemoTicket() async {
    return printOrder(
      customerName:
          'Eduardo Jordy',
      orderId:
          'CH-0001',
      items: const [
        PrinterOrderItem(
          productName:
              'Chicha de Wiñapu',
          quantityMl:
              250,
          price:
              5.00,
        ),
      ],
      dateTime:
          DateTime.now(),
    );
  }

  // ===============================================================
  // NOMBRE BLE
  // ===============================================================

  String _deviceName(
    ScanResult result,
  ) {
    final advertised =
        result
            .advertisementData
            .advName
            .trim();

    if (advertised.isNotEmpty) {
      return advertised;
    }

    final platform =
        result
            .device
            .platformName
            .trim();

    if (platform.isNotEmpty) {
      return platform;
    }

    return 'Dispositivo BLE';
  }

  String _twoDigits(
    int number,
  ) {
    return number
        .toString()
        .padLeft(
          2,
          '0',
        );
  }

  // ===============================================================
  // CERRAR SERVICIO
  // ===============================================================

  Future<void> dispose() async {
    await _connectionSubscription?.cancel();

    await disconnect();
  }
}