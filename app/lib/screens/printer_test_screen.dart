import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/printer_service.dart';

class PrinterTestScreen extends StatefulWidget {
  const PrinterTestScreen({super.key});

  @override
  State<PrinterTestScreen> createState() => _PrinterTestScreenState();
}

class _PrinterTestScreenState extends State<PrinterTestScreen> {
  final List<ScanResult> _devices = [];

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _printerWriteCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  bool _scanning = false;
  bool _connecting = false;
  bool _printing = false;

  String _status = 'Listo para buscar la MX06';

  final List<String> _servicesInfo = [];

  static const int printerWidth = 384;

  @override
  void initState() {
    super.initState();
    _listenScanResults();
  }

  // ============================================================
  // ESCANEO BLE
  // ============================================================

  void _listenScanResults() {
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;

      for (final result in results) {
        final exists = _devices.any(
          (item) => item.device.remoteId == result.device.remoteId,
        );

        if (!exists) {
          setState(() {
            _devices.add(result);
          });
        }
      }
    });
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final scan =
        statuses[Permission.bluetoothScan]?.isGranted ?? false;

    final connect =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;

    if (scan && connect) {
      return true;
    }

    if (!mounted) return false;

    setState(() {
      _status = 'Falta permiso para dispositivos Bluetooth cercanos';
    });

    return false;
  }

  Future<void> _startScan() async {
    final permissionOk = await _requestPermissions();

    if (!permissionOk) return;

    try {
      final adapterState = await FlutterBluePlus.adapterState.first;

      if (adapterState != BluetoothAdapterState.on) {
        if (!mounted) return;

        setState(() {
          _status = 'Activa Bluetooth en el teléfono';
        });

        return;
      }

      setState(() {
        _devices.clear();
        _servicesInfo.clear();
        _printerWriteCharacteristic = null;
        _scanning = true;
        _status = 'Buscando dispositivos BLE...';
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      await Future.delayed(
        const Duration(seconds: 15),
      );

      await FlutterBluePlus.stopScan();

      if (!mounted) return;

      setState(() {
        _scanning = false;

        if (_devices.isEmpty) {
          _status = 'No se encontraron dispositivos BLE';
        } else {
          _status = 'Encontrados: ${_devices.length} dispositivos';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _scanning = false;
        _status = 'Error durante búsqueda: $e';
      });
    }
  }

  Future<void> _stopScan() async {
    try {
      await FlutterBluePlus.stopScan();

      if (!mounted) return;

      setState(() {
        _scanning = false;
        _status = 'Búsqueda detenida';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'Error deteniendo búsqueda: $e';
      });
    }
  }

  // ============================================================
  // CONEXIÓN MX06
  // ============================================================

  Future<void> _connect(ScanResult result) async {
    setState(() {
      _connecting = true;
      _status = 'Conectando a ${_deviceName(result)}...';
      _servicesInfo.clear();
      _printerWriteCharacteristic = null;
    });

    try {
      await FlutterBluePlus.stopScan();

      final device = result.device;

      await _connectionSubscription?.cancel();

      _connectionSubscription =
          device.connectionState.listen((connectionState) {
        if (!mounted) return;

        if (connectionState ==
            BluetoothConnectionState.disconnected) {
          setState(() {
            _connectedDevice = null;
            _printerWriteCharacteristic = null;
            _status = 'MX06 desconectada';
          });
        }
      });

      await device.connect(
        timeout: const Duration(seconds: 15),
        license: License.nonprofit,
      );

      if (!mounted) return;

      setState(() {
        _connectedDevice = device;
        _status = '${_deviceName(result)} conectada';
      });

      await _discoverServices(device);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'Error de conexión: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    }
  }

  Future<void> _discoverServices(
    BluetoothDevice device,
  ) async {
    try {
      setState(() {
        _status = 'Descubriendo servicios MX06...';
        _servicesInfo.clear();
        _printerWriteCharacteristic = null;
      });

      final services = await device.discoverServices();

      for (final service in services) {
        final serviceUuid =
            service.uuid.toString().toLowerCase();

        _servicesInfo.add(
          'SERVICIO\n${service.uuid}',
        );

        for (final characteristic in service.characteristics) {
          final characteristicUuid =
              characteristic.uuid.toString().toLowerCase();

          final properties = <String>[];

          if (characteristic.properties.read) {
            properties.add('READ');
          }

          if (characteristic.properties.write) {
            properties.add('WRITE');
          }

          if (characteristic.properties.writeWithoutResponse) {
            properties.add('WRITE WITHOUT RESPONSE');
          }

          if (characteristic.properties.notify) {
            properties.add('NOTIFY');
          }

          if (characteristic.properties.indicate) {
            properties.add('INDICATE');
          }

          _servicesInfo.add(
            'Característica: ${characteristic.uuid}\n'
            'Propiedades: ${properties.join(", ")}',
          );

          if (serviceUuid.contains('ae30') &&
              characteristicUuid.contains('ae01') &&
              characteristic.properties.writeWithoutResponse) {
            _printerWriteCharacteristic = characteristic;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        if (_printerWriteCharacteristic != null) {
          _status = 'MX06 lista para imprimir';
        } else {
          _status = 'MX06 conectada, pero AE01 no fue encontrada';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'Error descubriendo servicios: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    final device = _connectedDevice;

    if (device == null) return;

    try {
      await device.disconnect();

      if (!mounted) return;

      setState(() {
        _connectedDevice = null;
        _printerWriteCharacteristic = null;
        _servicesInfo.clear();
        _status = 'MX06 desconectada';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'Error al desconectar: $e';
      });
    }
  }

  // ============================================================
  // CRC8
  // ============================================================

  int _crc8(List<int> data) {
    int crc = 0;

    for (final byte in data) {
      crc ^= byte;

      for (int i = 0; i < 8; i++) {
        if ((crc & 0x80) != 0) {
          crc = ((crc << 1) ^ 0x07) & 0xFF;
        } else {
          crc = (crc << 1) & 0xFF;
        }
      }
    }

    return crc;
  }

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

  Future<void> _send(
    List<int> packet,
  ) async {
    final characteristic = _printerWriteCharacteristic;

    if (characteristic == null) {
      throw Exception('AE01 no disponible');
    }

    await characteristic.write(
      packet,
      withoutResponse: true,
    );

    await Future.delayed(
      const Duration(milliseconds: 3),
    );
  }

  // ============================================================
  // AVANCE PAPEL
  // ============================================================

  Future<void> _testFeedPaper() async {
    if (_printerWriteCharacteristic == null) {
      setState(() {
        _status = 'Primero conecta la MX06';
      });

      return;
    }

    try {
      setState(() {
        _status = 'Moviendo papel...';
      });

      await _send(
        _packet(
          0xA1,
          [
            0x30,
            0x00,
          ],
        ),
      );

      if (!mounted) return;

      setState(() {
        _status = 'Papel avanzado correctamente';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'Error moviendo papel: $e';
      });
    }
  }

  // ============================================================
  // IMAGEN TEST ANTIGUA
  // ============================================================

  Future<ui.Image> _createTestImage() async {
    const width = printerWidth;
    const height = 270;

    final recorder = ui.PictureRecorder();

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
      Paint()..color = Colors.white,
    );

    final titlePainter = TextPainter(
      text: const TextSpan(
        text: 'CHICHEJ',
        style: TextStyle(
          color: Colors.black,
          fontSize: 44,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    titlePainter.layout(
      maxWidth: width.toDouble(),
    );

    titlePainter.paint(
      canvas,
      Offset(
        (width - titlePainter.width) / 2,
        15,
      ),
    );

    canvas.drawRect(
      const Rect.fromLTWH(
        25,
        73,
        334,
        2,
      ),
      Paint()..color = Colors.black,
    );

    final bodyPainter = TextPainter(
      text: const TextSpan(
        text:
            'DISPENSADOR INTELIGENTE\n\n'
            'PRUEBA MX06 OK\n\n'
            '13va Expo Feria\n'
            'Chelito Quiroga 2026',
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    bodyPainter.layout(
      maxWidth: 350,
    );

    bodyPainter.paint(
      canvas,
      Offset(
        (width - bodyPainter.width) / 2,
        90,
      ),
    );

    final picture = recorder.endRecording();

    return picture.toImage(
      width,
      height,
    );
  }

  Future<List<List<int>>> _imageToRows(
    ui.Image image,
  ) async {
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (byteData == null) {
      throw Exception('No se pudo leer la imagen');
    }

    final bytes = byteData.buffer.asUint8List();

    final rows = <List<int>>[];

    for (int y = 0; y < image.height; y++) {
      final row = List<int>.filled(
        printerWidth ~/ 8,
        0,
      );

      for (int x = 0; x < printerWidth; x++) {
        final pixelIndex =
            ((y * printerWidth) + x) * 4;

        final red = bytes[pixelIndex];
        final green = bytes[pixelIndex + 1];
        final blue = bytes[pixelIndex + 2];

        final luminance =
            (red * 0.299) +
            (green * 0.587) +
            (blue * 0.114);

        if (luminance < 165) {
          final byteIndex = x ~/ 8;
          final bitIndex = x % 8;

          row[byteIndex] |=
              (1 << bitIndex);
        }
      }

      rows.add(row);
    }

    return rows;
  }

  // ============================================================
  // TEST ANTIGUO DIRECTO
  // ============================================================

  Future<void> _printChichejTest() async {
    if (_connectedDevice == null ||
        _printerWriteCharacteristic == null) {
      setState(() {
        _status = 'Primero conecta la MX06';
      });

      return;
    }

    if (_printing) return;

    setState(() {
      _printing = true;
      _status = 'Preparando impresión CHICHEJ...';
    });

    try {
      final image = await _createTestImage();
      final rows = await _imageToRows(image);

      await _send(
        _packet(
          0xA4,
          [0x32],
        ),
      );

      await _send(
        _packet(
          0xAF,
          [
            0x3F,
            0x00,
          ],
        ),
      );

      await _send(
        _packet(
          0xBE,
          [0x01],
        ),
      );

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

      await _send(latticeStart);

      for (int i = 0; i < rows.length; i++) {
        if (!mounted) return;

        if (i % 25 == 0) {
          setState(() {
            final percent =
                ((i / rows.length) * 100)
                    .round();

            _status =
                'Imprimiendo CHICHEJ... $percent%';
          });
        }

        await _send(
          _packet(
            0xA2,
            rows[i],
          ),
        );
      }

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

      await _send(latticeEnd);

      await Future.delayed(
        const Duration(milliseconds: 200),
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

      if (!mounted) return;

      setState(() {
        _status =
            '¡CHICHEJ impreso y listo para cortar!';
      });
    } catch (e, stackTrace) {
      debugPrint(
        '[MX06] Error impresión: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _status =
            'Error durante impresión: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
        });
      }
    }
  }

  // ============================================================
  // NUEVA PRUEBA PRINTER SERVICE
  // ============================================================

  Future<void> _testPrinterService() async {
    if (_printing) return;

    setState(() {
      _printing = true;
      _status = 'Probando PrinterService...';
    });

    try {
      final ok =
          await PrinterService.instance.printDemoTicket();

      if (!mounted) return;

      setState(() {
        _status = ok
            ? 'PrinterService OK - ticket impreso'
            : PrinterService.instance.status;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status =
            'Error probando PrinterService: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
        });
      }
    }
  }

  // ============================================================
  // NOMBRE DISPOSITIVO
  // ============================================================

  String _deviceName(
    ScanResult result,
  ) {
    final advertisedName =
        result.advertisementData.advName.trim();

    if (advertisedName.isNotEmpty) {
      return advertisedName;
    }

    final platformName =
        result.device.platformName.trim();

    if (platformName.isNotEmpty) {
      return platformName;
    }

    return 'Dispositivo BLE';
  }

  bool _isMx06(
    ScanResult result,
  ) {
    return _deviceName(result)
        .toUpperCase()
        .contains('MX06');
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();

    FlutterBluePlus.stopScan();

    super.dispose();
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final orderedDevices = [..._devices];

    orderedDevices.sort((a, b) {
      if (_isMx06(a) && !_isMx06(b)) {
        return -1;
      }

      if (!_isMx06(a) && _isMx06(b)) {
        return 1;
      }

      return b.rssi.compareTo(a.rssi);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Impresora CHICHEJ',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.print,
                    size: 52,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  const Text(
                    'MX06 - CHICHEJ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    _status,
                    textAlign:
                        TextAlign.center,
                  ),
                ],
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _scanning ||
                                  _connecting ||
                                  _printing
                              ? null
                              : _startScan,
                      icon: const Icon(
                        Icons
                            .bluetooth_searching,
                      ),
                      label: const Text(
                        'Buscar',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          _scanning
                              ? _stopScan
                              : null,
                      icon: const Icon(
                        Icons.stop,
                      ),
                      label: const Text(
                        'Detener',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // NUEVO BOTÓN DEL PRINTER SERVICE
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                0,
              ),
              child: SizedBox(
                width: double.infinity,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _printing
                          ? null
                          : _testPrinterService,
                  icon: const Icon(
                    Icons.print_outlined,
                  ),
                  label: Text(
                    _printing
                        ? 'PROCESANDO...'
                        : 'PROBAR PRINTER SERVICE',
                  ),
                ),
              ),
            ),

            // ==================================================
            // BOTONES ANTIGUOS DE DIAGNÓSTICO
            // Solo aparecen si conectas manualmente.
            // ==================================================

            if (_connectedDevice != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  0,
                ),
                child: SizedBox(
                  width:
                      double.infinity,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        _printing ||
                                _printerWriteCharacteristic ==
                                    null
                            ? null
                            : _printChichejTest,
                    icon: const Icon(
                      Icons.receipt_long,
                    ),
                    label: Text(
                      _printing
                          ? 'IMPRIMIENDO...'
                          : 'IMPRIMIR CHICHEJ TEST',
                    ),
                  ),
                ),
              ),

            if (_connectedDevice != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  0,
                ),
                child: SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _printing
                            ? null
                            : _testFeedPaper,
                    icon: const Icon(
                      Icons
                          .keyboard_double_arrow_down,
                    ),
                    label: const Text(
                      'AVANZAR PAPEL',
                    ),
                  ),
                ),
              ),

            if (_connectedDevice != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  0,
                ),
                child: SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _printing
                            ? null
                            : _disconnect,
                    icon: const Icon(
                      Icons
                          .bluetooth_disabled,
                    ),
                    label: const Text(
                      'Desconectar MX06',
                    ),
                  ),
                ),
              ),

            const Divider(),

            Expanded(
              child:
                  _connectedDevice ==
                          null
                      ? ListView.builder(
                          itemCount:
                              orderedDevices
                                  .length,
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final result =
                                orderedDevices[
                                    index];

                            final name =
                                _deviceName(
                              result,
                            );

                            final mx06 =
                                _isMx06(
                              result,
                            );

                            return Card(
                              margin:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    12,
                                vertical:
                                    5,
                              ),
                              child:
                                  ListTile(
                                leading:
                                    Icon(
                                  mx06
                                      ? Icons
                                          .print
                                      : Icons
                                          .bluetooth,
                                ),
                                title:
                                    Text(
                                  name,
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        mx06
                                            ? FontWeight
                                                .bold
                                            : FontWeight
                                                .normal,
                                  ),
                                ),
                                subtitle:
                                    Text(
                                  '${result.device.remoteId}\n'
                                  'RSSI: ${result.rssi}',
                                ),
                                isThreeLine:
                                    true,
                                trailing:
                                    ElevatedButton(
                                  onPressed:
                                      _connecting
                                          ? null
                                          : () =>
                                              _connect(
                                                result,
                                              ),
                                  child:
                                      const Text(
                                    'Conectar',
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          itemCount:
                              _servicesInfo
                                  .length,
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            return Card(
                              margin:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    12,
                                vertical:
                                    5,
                              ),
                              child:
                                  Padding(
                                padding:
                                    const EdgeInsets
                                        .all(
                                  12,
                                ),
                                child:
                                    SelectableText(
                                  _servicesInfo[
                                      index],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}