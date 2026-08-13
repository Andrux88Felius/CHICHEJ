import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/reservation_service.dart';
import '../utils/colors.dart';

class AdminReservationsPage extends StatefulWidget {
  final String? usuarioId;
  final String? nombreCliente;
  final String? emailCliente;

  const AdminReservationsPage({
    super.key,
    this.usuarioId,
    this.nombreCliente,
    this.emailCliente,
  });

  @override
  State<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<AdminReservationsPage> {
  final _service = ReservationService();
  String _filter = 'todas';

  Future<void> _changeStatus(String id, String status) async {
    await _service.updateStatus(id, status);
  }

  Future<void> _openWhatsApp(Map<String, dynamic> data) async {
    final digits = (data['telefono']?.toString() ?? '').replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final whatsappPhone = digits.length == 8 ? '591$digits' : digits;
    if (whatsappPhone.isEmpty || !whatsappPhone.startsWith('591')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El teléfono de la reserva no es válido.'),
          ),
        );
      }
      return;
    }
    final date = data['fechaSolicitada'] is Timestamp
        ? DateFormat('dd/MM/yyyy')
            .format((data['fechaSolicitada'] as Timestamp).toDate())
        : 'fecha por confirmar';
    final status = data['estado']?.toString() ?? 'pendiente';
    final quantity =
        data['cantidadSolicitada']?.toString().trim().isNotEmpty == true
            ? data['cantidadSolicitada'].toString()
            : '${data['cantidad'] ?? 'Por confirmar'} unidades';
    final place = data['lugarEvento']?.toString().trim().isNotEmpty == true
        ? data['lugarEvento'].toString()
        : 'Por confirmar';
    final message =
        'Hola ${data['nombreCliente'] ?? 'cliente'}, somos CHICHEJ.\n\n'
        'Nos comunicamos para coordinar su solicitud comercial de reserva.\n'
        'Cantidad solicitada: $quantity\n'
        'Fecha del evento o entrega: $date\n'
        'Lugar: $place\n'
        'Detalle: ${data['detalle'] ?? ''}\n'
        'Estado actual: $status.\n\n'
        'Gracias por confiar en CHICHEJ.';
    final uri = Uri.https(
      'wa.me',
      '/$whatsappPhone',
      {'text': message},
    );

    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir WhatsApp. Verifica que la aplicación o un navegador estén disponibles.',
          ),
        ),
      );
    }
  }

  Future<void> _printReport(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    await Printing.layoutPdf(
      name: 'Reporte_Reservas_CHICHEJ.pdf',
      onLayout: (_) async {
        final pdf = pw.Document(title: 'Reporte de reservas CHICHEJ');
        final counts = <String, int>{};
        for (final document in documents) {
          final status = document.data()['estado']?.toString() ?? 'pendiente';
          counts[status] = (counts[status] ?? 0) + 1;
        }
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            header: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CHICHEJ',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xff5b2c83),
                  ),
                ),
                pw.Text('Reporte de reservas y pedidos especiales'),
                pw.Divider(color: const PdfColor.fromInt(0xffd4af37)),
              ],
            ),
            footer: (context) => pw.Text(
              'CHICHEJ - Tradición que nos une, innovación que nos impulsa.  '
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            build: (_) => [
              pw.Text(
                'Total: ${documents.length}  |  '
                'Pendientes: ${counts['pendiente'] ?? 0}  |  '
                'Aceptadas: ${counts['aceptada'] ?? 0}  |  '
                'Rechazadas: ${counts['rechazada'] ?? 0}  |  '
                'Completadas: ${counts['completada'] ?? 0}  |  '
                'Canceladas: ${counts['cancelada'] ?? 0}',
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Cliente',
                  'Teléfono',
                  'Creada',
                  'Reservada',
                  'Detalle',
                  'Estado',
                ],
                data: documents.map((document) {
                  final data = document.data();
                  String date(dynamic value) => value is Timestamp
                      ? DateFormat('dd/MM/yyyy HH:mm').format(value.toDate())
                      : 'Sin fecha';
                  return [
                    data['nombreCliente'] ?? '',
                    data['telefono'] ?? '',
                    date(data['fechaCreacion']),
                    date(data['fechaSolicitada']),
                    '${data['cantidadSolicitada'] ?? '${data['cantidad'] ?? 0} unidades'} - '
                        '${data['detalle'] ?? ''}\n'
                        '${data['lugarEvento'] ?? ''} ${data['direccion'] ?? ''}',
                    data['estado'] ?? 'pendiente',
                  ];
                }).toList(),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xff5b2c83),
                ),
                headerStyle: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                ),
                cellStyle: const pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        );
        return pdf.save();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final contenido = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
              child: Text('No se pudieron cargar las reservas.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reservasCliente = snapshot.data!.docs.where((document) {
          if (widget.usuarioId == null) return true;
          final data = document.data();
          final reservaUid = data['usuarioId']?.toString().trim();
          if (reservaUid != null && reservaUid.isNotEmpty) {
            return reservaUid == widget.usuarioId;
          }
          final correoCliente = widget.emailCliente?.trim().toLowerCase() ?? '';
          final correoReserva =
              data['email']?.toString().trim().toLowerCase() ?? '';
          return correoCliente.isNotEmpty && correoReserva == correoCliente;
        }).toList();
        final documents = reservasCliente.where((document) {
          return _filter == 'todas' || document.data()['estado'] == _filter;
        }).toList();
        final counts = <String, int>{};
        for (final document in reservasCliente) {
          final status = document.data()['estado']?.toString() ?? 'pendiente';
          counts[status] = (counts[status] ?? 0) + 1;
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.nombreCliente == null
                  ? 'Reservas y pedidos especiales'
                  : 'Solicitudes de ${widget.nombreCliente}',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              color: const Color(0xfff7f3fa),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    Text('Total: ${reservasCliente.length}'),
                    Text('Pendientes: ${counts['pendiente'] ?? 0}'),
                    Text('Aceptadas: ${counts['aceptada'] ?? 0}'),
                    Text('Rechazadas: ${counts['rechazada'] ?? 0}'),
                    Text('Completadas: ${counts['completada'] ?? 0}'),
                    Text('Canceladas: ${counts['cancelada'] ?? 0}'),
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                'todas',
                'pendiente',
                'aceptada',
                'rechazada',
                'completada',
                'cancelada',
              ].map((status) {
                return ChoiceChip(
                  label: Text(status.toUpperCase()),
                  selected: _filter == status,
                  onSelected: (_) => setState(() => _filter = status),
                );
              }).toList(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _printReport(reservasCliente),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Reporte de reservas'),
              ),
            ),
            if (documents.isEmpty)
              const Card(child: ListTile(title: Text('Sin reservas.'))),
            ...documents.map((document) {
              final data = document.data();
              final date = data['fechaSolicitada'] is Timestamp
                  ? DateFormat('dd/MM/yyyy').format(
                      (data['fechaSolicitada'] as Timestamp).toDate(),
                    )
                  : 'Sin fecha';
              return Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.event, color: AppColors.lilaOscuro),
                  title: Text(data['nombreCliente']?.toString() ?? 'Cliente'),
                  subtitle: Text('$date · ${data['estado'] ?? 'pendiente'}'),
                  childrenPadding: const EdgeInsets.all(14),
                  children: [
                    ListTile(
                      title: Text(data['detalle']?.toString() ?? 'Sin detalle'),
                      subtitle: Text(
                        'Cantidad solicitada: '
                        '${data['cantidadSolicitada'] ?? '${data['cantidad'] ?? 0} unidades'}\n'
                        'Lugar: ${data['lugarEvento'] ?? 'Sin lugar'}\n'
                        'Dirección: ${data['direccion'] ?? 'Sin dirección'}\n'
                        'Referencias: ${data['referenciasLugar'] ?? 'Ninguna'}\n'
                        'Teléfono: ${data['telefono'] ?? 'Sin teléfono'}\n'
                        'Correo: ${data['email'] ?? 'Sin correo'}\n'
                        'Observaciones: ${data['observaciones'] ?? 'Ninguna'}',
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final status in [
                          'aceptada',
                          'rechazada',
                          'completada',
                          'cancelada',
                        ])
                          OutlinedButton(
                            onPressed: () => _changeStatus(document.id, status),
                            child: Text(status.toUpperCase()),
                          ),
                        ElevatedButton.icon(
                          onPressed: () => _openWhatsApp(data),
                          icon: const Icon(Icons.chat),
                          label: const Text('Responder por WhatsApp'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
    if (widget.usuarioId == null) return contenido;
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Solicitudes comerciales'),
        backgroundColor: AppColors.lilaOscuro,
      ),
      body: contenido,
    );
  }
}
