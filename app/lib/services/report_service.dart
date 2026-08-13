import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum SalesReportPeriodType { day, month, custom, year }

class SalesProductStat {
  final String nombre;
  final int cantidad;
  final int mililitros;

  const SalesProductStat({
    required this.nombre,
    required this.cantidad,
    required this.mililitros,
  });
}

class ReportOrderItem {
  final String nombre;
  final int cantidad;
  final int cantidadMl;
  final double precioUnitario;
  final double subtotal;
  final bool esGratis;

  const ReportOrderItem({
    required this.nombre,
    required this.cantidad,
    required this.cantidadMl,
    required this.precioUnitario,
    required this.subtotal,
    required this.esGratis,
  });
}

class ReportOrder {
  final String id;
  final DateTime fechaCreacion;
  final String estado;
  final String estadoPago;
  final String metodoPago;
  final double total;
  final int cantidadTotalMl;
  final String nombreUsuario;
  final String email;
  final String tipoUsuario;
  final String usuarioId;
  final String origenPedido;
  final String dispensadorId;
  final List<ReportOrderItem> items;

  const ReportOrder({
    required this.id,
    required this.fechaCreacion,
    required this.estado,
    required this.estadoPago,
    required this.metodoPago,
    required this.total,
    required this.cantidadTotalMl,
    required this.nombreUsuario,
    required this.email,
    required this.tipoUsuario,
    required this.usuarioId,
    required this.origenPedido,
    required this.dispensadorId,
    required this.items,
  });

  bool get esVentaValida =>
      estadoPago == 'aprobado' &&
      estado != 'cancelado' &&
      metodoPago != 'admin';

  bool get esDispensacionAdministrativa =>
      metodoPago == 'admin' || estadoPago == 'no_requerido';

  bool get esFisico => tipoUsuario == 'fisico' || origenPedido == 'pulsador';

  bool get esApp => !esFisico;

  String get detalleProductos {
    if (items.isEmpty) return 'Sin detalle';
    return items.map((item) {
      final sufijo = item.cantidad > 1 ? ' x${item.cantidad}' : '';
      return '${item.nombre}$sufijo';
    }).join(', ');
  }
}

class SalesReportSummary {
  final DateTime fechaInicial;
  final DateTime fechaFinal;
  final List<ReportOrder> pedidos;
  final int pedidosEntregados;
  final int pedidosCancelados;
  final int ventasValidas;
  final double totalVendido;
  final int dispensadoMl;
  final int ventasApp;
  final int ventasFisicas;
  final double totalApp;
  final double totalFisico;
  final String productoMasVendido;
  final int cantidadProductoMasVendido;
  final List<SalesProductStat> productosMasVendidos;
  final Map<String, int> metodosPago;

  const SalesReportSummary({
    required this.fechaInicial,
    required this.fechaFinal,
    required this.pedidos,
    required this.pedidosEntregados,
    required this.pedidosCancelados,
    required this.ventasValidas,
    required this.totalVendido,
    required this.dispensadoMl,
    required this.ventasApp,
    required this.ventasFisicas,
    required this.totalApp,
    required this.totalFisico,
    required this.productoMasVendido,
    required this.cantidadProductoMasVendido,
    required this.productosMasVendidos,
    required this.metodosPago,
  });
}

class ReportService {
  const ReportService();

  SalesReportSummary crearResumenGeneral({
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documentos,
  }) {
    final pedidos = documentos
        .map(_normalizarPedido)
        .whereType<ReportOrder>()
        .toList()
      ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    final ahora = DateTime.now();
    final inicio = pedidos.isEmpty ? ahora : pedidos.last.fechaCreacion;
    final fin = pedidos.isEmpty ? ahora : pedidos.first.fechaCreacion;
    return _crearResumenPedidos(pedidos, inicio, fin);
  }

  SalesReportSummary crearResumenEntre({
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documentos,
    required DateTime inicio,
    required DateTime finExclusivo,
  }) {
    final pedidos = documentos
        .map(_normalizarPedido)
        .whereType<ReportOrder>()
        .where(
          (pedido) =>
              !pedido.fechaCreacion.isBefore(inicio) &&
              pedido.fechaCreacion.isBefore(finExclusivo),
        )
        .toList()
      ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    return _crearResumenPedidos(
      pedidos,
      inicio,
      finExclusivo.subtract(const Duration(microseconds: 1)),
    );
  }

  SalesReportSummary crearResumen({
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documentos,
    required DateTime fechaInicial,
    required DateTime fechaFinal,
    String? usuarioId,
  }) {
    final inicio = DateTime(
      fechaInicial.year,
      fechaInicial.month,
      fechaInicial.day,
    );
    final finExclusivo = DateTime(
      fechaFinal.year,
      fechaFinal.month,
      fechaFinal.day + 1,
    );

    final documentosFiltrados = usuarioId == null
        ? documentos
        : documentos.where(
            (documento) =>
                documento.data()['usuarioId']?.toString() == usuarioId,
          );

    return crearResumenEntre(
      documentos: documentosFiltrados,
      inicio: inicio,
      finExclusivo: finExclusivo,
    );
  }

  SalesReportSummary _crearResumenPedidos(
    List<ReportOrder> pedidos,
    DateTime fechaInicial,
    DateTime fechaFinal,
  ) {
    var pedidosEntregados = 0;
    var pedidosCancelados = 0;
    var ventasValidas = 0;
    var totalVendido = 0.0;
    var dispensadoMl = 0;
    var ventasApp = 0;
    var ventasFisicas = 0;
    var totalApp = 0.0;
    var totalFisico = 0.0;
    final productosVendidos = <String, int>{};
    final mililitrosPorProducto = <String, int>{};
    final metodosPago = <String, int>{};

    for (final pedido in pedidos) {
      if (pedido.estado == 'entregado') {
        pedidosEntregados++;
        dispensadoMl += pedido.cantidadTotalMl;
        for (final item in pedido.items) {
          productosVendidos[item.nombre] =
              (productosVendidos[item.nombre] ?? 0) + item.cantidad;
          mililitrosPorProducto[item.nombre] =
              (mililitrosPorProducto[item.nombre] ?? 0) +
                  (item.cantidadMl * item.cantidad);
        }
      }

      if (pedido.estado == 'cancelado') pedidosCancelados++;

      if (!pedido.esVentaValida) continue;

      ventasValidas++;
      totalVendido += pedido.total;
      if (pedido.esFisico) {
        ventasFisicas++;
        totalFisico += pedido.total;
      } else {
        ventasApp++;
        totalApp += pedido.total;
      }
      final metodo =
          pedido.metodoPago.isEmpty ? 'no especificado' : pedido.metodoPago;
      metodosPago[metodo] = (metodosPago[metodo] ?? 0) + 1;
    }

    var productoMasVendido = 'Sin datos';
    var cantidadProductoMasVendido = 0;
    final productosOrdenados = productosVendidos.entries.toList()
      ..sort((a, b) {
        final porCantidad = b.value.compareTo(a.value);
        return porCantidad != 0 ? porCantidad : a.key.compareTo(b.key);
      });
    final productosMasVendidos = productosOrdenados
        .take(5)
        .map(
          (entry) => SalesProductStat(
            nombre: entry.key,
            cantidad: entry.value,
            mililitros: mililitrosPorProducto[entry.key] ?? 0,
          ),
        )
        .toList(growable: false);

    if (productosMasVendidos.isNotEmpty) {
      productoMasVendido = productosMasVendidos.first.nombre;
      cantidadProductoMasVendido = productosMasVendidos.first.cantidad;
    }

    return SalesReportSummary(
      fechaInicial: fechaInicial,
      fechaFinal: fechaFinal,
      pedidos: pedidos,
      pedidosEntregados: pedidosEntregados,
      pedidosCancelados: pedidosCancelados,
      ventasValidas: ventasValidas,
      totalVendido: totalVendido,
      dispensadoMl: dispensadoMl,
      ventasApp: ventasApp,
      ventasFisicas: ventasFisicas,
      totalApp: totalApp,
      totalFisico: totalFisico,
      productoMasVendido: productoMasVendido,
      cantidadProductoMasVendido: cantidadProductoMasVendido,
      productosMasVendidos: productosMasVendidos,
      metodosPago: metodosPago,
    );
  }

  String nombreArchivoPdf({
    required SalesReportPeriodType tipo,
    required DateTime fechaInicial,
    required DateTime fechaFinal,
  }) {
    final fechaCorta = DateFormat('ddMMyy');
    switch (tipo) {
      case SalesReportPeriodType.day:
        return 'Reporte_Ventas_CHICHEJ_D_'
            '${fechaCorta.format(fechaInicial)}.pdf';
      case SalesReportPeriodType.month:
        return 'Reporte_Ventas_CHICHEJ_M_'
            '${DateFormat('MMyyyy').format(fechaInicial)}.pdf';
      case SalesReportPeriodType.custom:
        return 'Reporte_Ventas_CHICHEJ_P_'
            '${fechaCorta.format(fechaInicial)}_'
            '${fechaCorta.format(fechaFinal)}.pdf';
      case SalesReportPeriodType.year:
        return 'Reporte_Ventas_CHICHEJ_A_${fechaInicial.year}.pdf';
    }
  }

  Future<Uint8List> generarPdfVentas(
    SalesReportSummary resumen, {
    bool incluirGraficas = false,
  }) async {
    final logo = await _cargarLogo();
    final documento = pw.Document(
      title: 'Reporte de Ventas CHICHEJ',
      author: 'CHICHEJ',
      creator: 'Sistema Inteligente de Dispensación Automatizada',
    );
    final fecha = DateFormat('dd/MM/yyyy HH:mm');
    final fechaCorta = DateFormat('dd/MM/yyyy');
    final dinero = NumberFormat('#,##0.00', 'en_US');
    final generado = DateTime.now();

    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 34),
        header: (context) => _encabezadoPdf(
          resumen: resumen,
          generado: generado,
          fecha: fecha,
          fechaCorta: fechaCorta,
          logo: logo,
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'CHICHEJ - Tradición que nos une, innovación que nos impulsa.',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'Resumen',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xff5b2c83),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tarjetaPdf('Pedidos del período', '${resumen.pedidos.length}'),
              _tarjetaPdf('Pedidos entregados', '${resumen.pedidosEntregados}'),
              _tarjetaPdf('Pedidos cancelados', '${resumen.pedidosCancelados}'),
              _tarjetaPdf('Ventas válidas', '${resumen.ventasValidas}'),
              _tarjetaPdf(
                'Total vendido',
                '${dinero.format(resumen.totalVendido)} Bs',
              ),
              _tarjetaPdf(
                  'Dispensado real', _formatearMl(resumen.dispensadoMl)),
              _tarjetaPdf('Ventas App', '${resumen.ventasApp}'),
              _tarjetaPdf('Ventas físicas', '${resumen.ventasFisicas}'),
              _tarjetaPdf(
                'Total App',
                '${dinero.format(resumen.totalApp)} Bs',
              ),
              _tarjetaPdf(
                'Total físico',
                '${dinero.format(resumen.totalFisico)} Bs',
              ),
              _tarjetaPdf(
                'Producto más vendido',
                resumen.cantidadProductoMasVendido == 0
                    ? 'Sin datos'
                    : '${resumen.productoMasVendido} '
                        '(${resumen.cantidadProductoMasVendido})',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Totales por origen',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Aplicación: ${resumen.ventasApp} ventas · '
            '${dinero.format(resumen.totalApp)} Bs',
          ),
          pw.Text(
            'Pulsador físico: ${resumen.ventasFisicas} ventas · '
            '${dinero.format(resumen.totalFisico)} Bs',
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Métodos de pago',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          resumen.metodosPago.isEmpty
              ? pw.Text('Sin ventas válidas en el período.')
              : pw.Wrap(
                  spacing: 12,
                  children: resumen.metodosPago.entries
                      .map(
                        (entry) => pw.Text(
                          '${_capitalizar(entry.key)}: ${entry.value}',
                        ),
                      )
                      .toList(),
                ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Movimientos por origen',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 7),
          if (resumen.pedidos.isEmpty)
            pw.Text('No existen pedidos para el período seleccionado.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Fecha',
                'Cliente',
                'Origen',
                'Detalle',
                'Método',
                'Estado',
                'Total',
              ],
              data: resumen.pedidos
                  .map(
                    (pedido) => [
                      fecha.format(pedido.fechaCreacion),
                      pedido.nombreUsuario,
                      pedido.esFisico ? 'Pulsador' : 'App',
                      pedido.detalleProductos,
                      _capitalizar(pedido.metodoPago),
                      _capitalizar(pedido.estado),
                      '${dinero.format(pedido.total)} Bs',
                    ],
                  )
                  .toList(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xff5b2c83),
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellPadding: const pw.EdgeInsets.all(4),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.15),
                1: const pw.FlexColumnWidth(1.15),
                2: const pw.FlexColumnWidth(0.75),
                3: const pw.FlexColumnWidth(1.8),
                4: const pw.FlexColumnWidth(0.9),
                5: const pw.FlexColumnWidth(0.9),
                6: const pw.FlexColumnWidth(0.9),
              },
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xfff7f3fa),
              ),
            ),
          if (incluirGraficas) ...[
            pw.SizedBox(height: 22),
            ..._anexoEstadistico(resumen),
          ],
        ],
      ),
    );

    return documento.save();
  }

  ReportOrder? _normalizarPedido(
    QueryDocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final data = documento.data();
    final fecha = _fecha(data['fechaCreacion']);
    if (fecha == null) return null;

    final items = <ReportOrderItem>[];
    final itemsRaw = data['items'];
    if (itemsRaw is List) {
      for (final itemRaw in itemsRaw) {
        if (itemRaw is! Map) continue;
        final item = Map<String, dynamic>.from(itemRaw);
        final cantidad = _entero(item['cantidad'], respaldo: 1);
        final precioUnitario = _decimal(item['precioUnitario']);
        items.add(
          ReportOrderItem(
            nombre: _texto(item['nombre'], respaldo: 'Producto'),
            cantidad: cantidad <= 0 ? 1 : cantidad,
            cantidadMl: _entero(item['cantidadMl']),
            precioUnitario: precioUnitario,
            subtotal: item['subtotal'] == null
                ? precioUnitario * (cantidad <= 0 ? 1 : cantidad)
                : _decimal(item['subtotal']),
            esGratis: item['esGratis'] == true,
          ),
        );
      }
    }

    return ReportOrder(
      id: _texto(data['pedidoId'], respaldo: documento.id),
      fechaCreacion: fecha.toLocal(),
      estado: _texto(data['estado']).toLowerCase(),
      estadoPago: _texto(data['estadoPago']).toLowerCase(),
      metodoPago: _texto(data['metodoPago']).toLowerCase(),
      total: _decimal(data['total']),
      cantidadTotalMl: _entero(data['cantidadTotalMl']),
      nombreUsuario: _texto(data['nombreUsuario'], respaldo: 'Invitado'),
      email: _texto(data['email']),
      tipoUsuario: _texto(data['tipoUsuario']).toLowerCase(),
      usuarioId: _texto(data['usuarioId']),
      origenPedido: _texto(data['origenPedido']).toLowerCase(),
      dispensadorId: _texto(data['dispensadorId'], respaldo: 'principal'),
      items: items,
    );
  }

  Future<pw.MemoryImage?> _cargarLogo() async {
    try {
      final data = await rootBundle.load('assets/logo-chichej.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  DateTime? _fecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is int) return DateTime.fromMillisecondsSinceEpoch(valor);
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  int _entero(dynamic valor, {int respaldo = 0}) {
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? respaldo;
  }

  double _decimal(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  String _texto(dynamic valor, {String respaldo = ''}) {
    final texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? respaldo : texto;
  }

  pw.Widget _encabezadoPdf({
    required SalesReportSummary resumen,
    required DateTime generado,
    required DateFormat fecha,
    required DateFormat fechaCorta,
    required pw.MemoryImage? logo,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColor.fromInt(0xffd4af37),
            width: 2,
          ),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.SizedBox(
                  width: 82,
                  height: 68,
                  child: pw.Image(
                    logo,
                    fit: pw.BoxFit.contain,
                  ),
                )
              else
                pw.Text(
                  'CHICHEJ',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xff5b2c83),
                  ),
                ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Período: ${fechaCorta.format(resumen.fechaInicial)} - '
                    '${fechaCorta.format(resumen.fechaFinal)}',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                  pw.Text(
                    'Generado: ${fecha.format(generado)}',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'REPORTE DE VENTAS',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _tarjetaPdf(String titulo, String valor) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xfff7f3fa),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(titulo, style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 3),
          pw.Text(
            valor,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _anexoEstadistico(SalesReportSummary resumen) {
    return [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 7),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColor.fromInt(0xffd4af37)),
          ),
        ),
        child: pw.Text(
          'ANEXO ESTADÍSTICO',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xff5b2c83),
          ),
        ),
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Productos más vendidos',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 7),
      if (resumen.productosMasVendidos.isEmpty)
        pw.Text('Sin productos vendidos en el período.')
      else
        ...resumen.productosMasVendidos.map(
          (producto) => _barraPdf(
            etiqueta: '${producto.nombre} '
                '(${_formatearMl(producto.mililitros)})',
            valor: producto.cantidad,
            maximo: resumen.productosMasVendidos.first.cantidad,
            color: const PdfColor.fromInt(0xff5b2c83),
          ),
        ),
      pw.SizedBox(height: 14),
      pw.Text(
        'Métodos de pago válidos',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 7),
      if (resumen.metodosPago.isEmpty)
        pw.Text('Sin métodos de pago válidos en el período.')
      else
        ...resumen.metodosPago.entries.map(
          (entry) => _barraPdf(
            etiqueta: _capitalizar(entry.key),
            valor: entry.value,
            maximo: resumen.metodosPago.values.reduce(
              (actual, siguiente) => actual > siguiente ? actual : siguiente,
            ),
            color: const PdfColor.fromInt(0xffd4af37),
          ),
        ),
    ];
  }

  pw.Widget _barraPdf({
    required String etiqueta,
    required int valor,
    required int maximo,
    required PdfColor color,
  }) {
    final proporcion = maximo <= 0 ? 0.0 : valor / maximo;
    final proporcionEntera = (proporcion * 1000).round().clamp(1, 1000);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 125,
            child: pw.Text(
              etiqueta,
              maxLines: 2,
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              height: 11,
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: proporcionEntera,
                    child: pw.Container(color: color),
                  ),
                  if (proporcionEntera < 1000)
                    pw.Expanded(
                      flex: 1000 - proporcionEntera,
                      child: pw.SizedBox(),
                    ),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 7),
          pw.SizedBox(
            width: 28,
            child: pw.Text(
              '$valor',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static String formatearMl(int mililitros) => _formatearMl(mililitros);

  static String _formatearMl(int mililitros) {
    if (mililitros >= 1000) {
      return '${(mililitros / 1000).toStringAsFixed(2)} L';
    }
    return '$mililitros ml';
  }

  static String _capitalizar(String texto) {
    if (texto.isEmpty) return 'No especificado';
    return '${texto[0].toUpperCase()}${texto.substring(1)}';
  }
}
