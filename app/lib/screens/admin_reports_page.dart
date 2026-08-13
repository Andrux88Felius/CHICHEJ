import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../services/report_service.dart';
import '../utils/colors.dart';

enum _FiltroReporte { hoy, mes, personalizado }

class AdminReportsPage extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> pedidos;
  final List<Map<String, dynamic>> usuarios;
  final bool cargando;
  final Object? error;

  const AdminReportsPage({
    super.key,
    required this.pedidos,
    required this.usuarios,
    required this.cargando,
    required this.error,
  });

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final ReportService _reportService = const ReportService();
  _FiltroReporte _filtro = _FiltroReporte.hoy;
  late DateTime _fechaInicial;
  late DateTime _fechaFinal;
  bool _incluirGraficas = false;
  String? _usuarioId;

  @override
  void initState() {
    super.initState();
    _seleccionarHoy(actualizarVista: false);
  }

  void _seleccionarHoy({bool actualizarVista = true}) {
    final ahora = DateTime.now();
    void aplicar() {
      _filtro = _FiltroReporte.hoy;
      _fechaInicial = DateTime(ahora.year, ahora.month, ahora.day);
      _fechaFinal =
          DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59, 999);
    }

    if (actualizarVista) {
      setState(aplicar);
    } else {
      aplicar();
    }
  }

  void _seleccionarMes() {
    final ahora = DateTime.now();
    setState(() {
      _filtro = _FiltroReporte.mes;
      _fechaInicial = DateTime(ahora.year, ahora.month);
      _fechaFinal = DateTime(ahora.year, ahora.month + 1, 0, 23, 59, 59, 999);
    });
  }

  Future<void> _seleccionarRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _fechaInicial,
        end: _fechaFinal,
      ),
      helpText: 'Selecciona el período del reporte',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );

    if (rango == null || !mounted) return;

    setState(() {
      _filtro = _FiltroReporte.personalizado;
      _fechaInicial =
          DateTime(rango.start.year, rango.start.month, rango.start.day);
      _fechaFinal = DateTime(
        rango.end.year,
        rango.end.month,
        rango.end.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  Future<void> _previsualizarPdf(SalesReportSummary resumen) async {
    await Printing.layoutPdf(
      name: _reportService.nombreArchivoPdf(
        tipo: _tipoPeriodoPdf(),
        fechaInicial: _fechaInicial,
        fechaFinal: _fechaFinal,
      ),
      format: PdfPageFormat.a4,
      onLayout: (_) => _reportService.generarPdfVentas(
        resumen,
        incluirGraficas: _incluirGraficas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.error != null && widget.pedidos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudieron cargar los pedidos:\n${widget.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (widget.cargando && widget.pedidos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final resumen = _reportService.crearResumen(
      documentos: widget.pedidos,
      fechaInicial: _fechaInicial,
      fechaFinal: _fechaFinal,
      usuarioId: _usuarioId,
    );

    final usuarios = <String, String>{};
    for (final documento in widget.pedidos) {
      final data = documento.data();
      final uid = data['usuarioId']?.toString().trim() ?? '';
      final esFisico =
          data['tipoUsuario']?.toString().toLowerCase() == 'fisico' ||
              data['origenPedido']?.toString().toLowerCase() == 'pulsador';
      if (uid.isNotEmpty && !esFisico) {
        usuarios[uid] =
            data['nombreUsuario']?.toString().trim().isNotEmpty == true
                ? data['nombreUsuario'].toString()
                : data['email']?.toString() ?? 'Usuario';
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Reportes CHICHEJ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 3),
        const Text(
          'Reporte de ventas',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Hoy'),
              selected: _filtro == _FiltroReporte.hoy,
              onSelected: (_) => _seleccionarHoy(),
            ),
            ChoiceChip(
              label: const Text('Este mes'),
              selected: _filtro == _FiltroReporte.mes,
              onSelected: (_) => _seleccionarMes(),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: const Text('Rango personalizado'),
              selected: _filtro == _FiltroReporte.personalizado,
              onSelected: (_) => _seleccionarRango(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _textoPeriodo(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          initialValue: _usuarioId,
          decoration: const InputDecoration(
            labelText: 'Cliente',
            labelStyle: TextStyle(color: AppColors.lilaOscuro),
            prefixIcon: Icon(Icons.person_search, color: AppColors.lilaOscuro),
            filled: true,
            fillColor: Color(0xfff7f3fa),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.lilaClaro),
            ),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos (incluye ventas físicas)'),
            ),
            ...usuarios.entries.map(
              (entry) => DropdownMenuItem<String?>(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (valor) => setState(() => _usuarioId = valor),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _tarjeta(
                'Pedidos', '${resumen.pedidos.length}', Icons.receipt_long),
            _tarjeta('Entregados', '${resumen.pedidosEntregados}',
                Icons.check_circle),
            _tarjeta(
                'Cancelados', '${resumen.pedidosCancelados}', Icons.cancel),
            _tarjeta('Ventas válidas', '${resumen.ventasValidas}',
                Icons.point_of_sale),
            _tarjeta(
              'Total vendido',
              '${resumen.totalVendido.toStringAsFixed(2)} Bs',
              Icons.monetization_on,
            ),
            _tarjeta(
              'Dispensado',
              ReportService.formatearMl(resumen.dispensadoMl),
              Icons.local_drink,
            ),
            _tarjeta('Ventas App', '${resumen.ventasApp}', Icons.phone_android,
                detalle: '${resumen.totalApp.toStringAsFixed(2)} Bs'),
            _tarjeta(
                'Ventas físicas', '${resumen.ventasFisicas}', Icons.touch_app,
                detalle: '${resumen.totalFisico.toStringAsFixed(2)} Bs'),
            _tarjeta(
              'Más vendido',
              resumen.cantidadProductoMasVendido == 0
                  ? 'Sin datos'
                  : resumen.productoMasVendido,
              Icons.star,
              detalle: resumen.cantidadProductoMasVendido == 0
                  ? null
                  : '${resumen.cantidadProductoMasVendido} unidades',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _productosMasVendidos(resumen),
        const SizedBox(height: 20),
        const Text(
          'Métodos de pago',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (resumen.metodosPago.isEmpty)
          const Card(
            child: ListTile(title: Text('Sin ventas válidas en el período.')),
          )
        else
          ...resumen.metodosPago.entries.map(
            (entry) => Card(
              child: ListTile(
                leading: Icon(
                  entry.key == 'qr' ? Icons.qr_code : Icons.payments,
                  color: AppColors.lilaOscuro,
                ),
                title: Text(entry.key.toUpperCase()),
                trailing: Text(
                  '${entry.value}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Incluir gráficas en el PDF',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Añade un anexo estadístico con productos y métodos de pago.',
          ),
          value: _incluirGraficas,
          activeThumbColor: AppColors.lilaOscuro,
          onChanged: (valor) {
            setState(() {
              _incluirGraficas = valor;
            });
          },
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lilaOscuro,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          onPressed: () => _previsualizarPdf(resumen),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('GENERAR / PREVISUALIZAR PDF'),
        ),
        const SizedBox(height: 14),
        _pedidosIncluidos(resumen),
        const SizedBox(height: 20),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _tarjeta(
    String titulo,
    String valor,
    IconData icono, {
    String? detalle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Icon(icono, color: AppColors.lilaOscuro),
            const SizedBox(height: 4),
            Text(titulo, textAlign: TextAlign.center),
            const SizedBox(height: 3),
            Expanded(
              child: Center(
                child: Text(
                  valor,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.05,
                  ),
                ),
              ),
            ),
            if (detalle != null)
              Text(
                detalle,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _productosMasVendidos(SalesReportSummary resumen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Productos más vendidos',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (resumen.productosMasVendidos.isEmpty)
          const Card(
            child: ListTile(
              title: Text('Sin productos vendidos en el período.'),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: resumen.productosMasVendidos
                    .map(
                      (producto) => _barraProducto(
                        producto,
                        resumen.productosMasVendidos.first.cantidad,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _barraProducto(SalesProductStat producto, int maximo) {
    final proporcion = maximo <= 0 ? 0.0 : producto.cantidad / maximo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              producto.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 12,
                child: LinearProgressIndicator(
                  value: proporcion,
                  backgroundColor: Colors.grey.shade200,
                  color: AppColors.lilaOscuro,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: Text(
              '${producto.cantidad} · '
              '${ReportService.formatearMl(producto.mililitros)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pedidosIncluidos(SalesReportSummary resumen) {
    final app = resumen.pedidos.where((pedido) => pedido.esApp).toList();
    final fisicos = resumen.pedidos.where((pedido) => pedido.esFisico).toList();
    final administrativos = resumen.pedidos
        .where((pedido) => pedido.esDispensacionAdministrativa && pedido.esApp)
        .toList();

    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(
          Icons.receipt_long,
          color: AppColors.lilaOscuro,
        ),
        title: Text(
          'Pedidos incluidos (${resumen.pedidos.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          _grupoPedidos(
            titulo: 'Ventas desde aplicación',
            pedidos: app
                .where((pedido) => !pedido.esDispensacionAdministrativa)
                .toList(),
          ),
          const SizedBox(height: 12),
          _grupoPedidos(
            titulo: 'Ventas físicas por pulsador',
            pedidos: fisicos,
          ),
          const SizedBox(height: 12),
          _grupoPedidos(
            titulo: 'Dispensaciones administrativas',
            pedidos: administrativos,
          ),
        ],
      ),
    );
  }

  Widget _grupoPedidos({
    required String titulo,
    required List<ReportOrder> pedidos,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(
          '$titulo (${pedidos.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.lilaOscuro,
          ),
        ),
        const SizedBox(height: 6),
        if (pedidos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin pedidos en esta categoría.'),
          )
        else
          ...pedidos.map(_pedidoCard),
      ],
    );
  }

  Widget _pedidoCard(ReportOrder pedido) {
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(pedido.fechaCreacion);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: pedido.esVentaValida ? Colors.green : Colors.grey,
          foregroundColor: Colors.white,
          child: Icon(pedido.esVentaValida ? Icons.check : Icons.receipt_long),
        ),
        title: Text(pedido.nombreUsuario),
        subtitle: Text(
          '$fecha\n${pedido.detalleProductos}\n'
          '${pedido.metodoPago.toUpperCase()} • ${pedido.estado.toUpperCase()}',
        ),
        isThreeLine: true,
        trailing: Text(
          '${pedido.total.toStringAsFixed(2)} Bs',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _textoPeriodo() {
    final formato = DateFormat('dd/MM/yyyy');
    return 'Período: ${formato.format(_fechaInicial)} - '
        '${formato.format(_fechaFinal)}';
  }

  SalesReportPeriodType _tipoPeriodoPdf() {
    switch (_filtro) {
      case _FiltroReporte.hoy:
        return SalesReportPeriodType.day;
      case _FiltroReporte.mes:
        return SalesReportPeriodType.month;
      case _FiltroReporte.personalizado:
        return SalesReportPeriodType.custom;
    }
  }
}
