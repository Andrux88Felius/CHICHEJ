import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_model.dart';
import '../providers/user_provider.dart';
import '../services/admin_service.dart';
import '../services/product_service.dart';
import '../utils/colors.dart';

class AdminProductsCrud extends StatelessWidget {
  const AdminProductsCrud({
    super.key,
    required this.productService,
    required this.onEditarPrecioRapido,
  });

  final ProductService productService;
  final Future<void> Function(Product producto) onEditarPrecioRapido;

  static const List<String> _imagenesDisponibles = [
    // Presentaciones originales
    'assets/150ml.png',
    'assets/250ml.jpg',
    'assets/500ml.jpg',
    'assets/750ml.jpg',
    'assets/1000ml.jpg',
  
    // Bebidas tradicionales
    'assets/cebada.png',
    'assets/garapiña.png',
    'assets/guarapo.png',
    'assets/linaza.png',
    'assets/mocochinchi.png',
  
    // Chicha macerada / variantes
    'assets/maserado1.jpeg',
    'assets/maserado2.jpeg',
    'assets/maserado3.jpeg',
    'assets/maserado4.jpeg',
  ];

  static const Map<int, int> _mlPorOpcion = {
    1: 45,
    2: 150,
    3: 250,
    4: 500,
    5: 750,
    6: 1000,
  };

  static const Map<int, String> _textoOpcion = {
    1: '45 ml — Muestra',
    2: '150 ml',
    3: '250 ml',
    4: '500 ml',
    5: '750 ml',
    6: '1000 ml / 1 L',
  };

  Future<void> _registrarAuditoria(
    UserProvider userProvider, {
    required String accion,
    required String descripcion,
    String? productoId,
    String? productoNombre,
    dynamic valorAnterior,
    dynamic valorNuevo,
  }) async {
    await AdminService().registrarAuditoria(
      accion: accion,
      adminUid: userProvider.uid ?? '',
      adminNombre: userProvider.user?.nombre ?? 'Administrador',
      adminRol: userProvider.user?.rol ?? 'admin',
      descripcion: descripcion,
      productoId: productoId,
      productoNombre: productoNombre,
      valorAnterior: valorAnterior,
      valorNuevo: valorNuevo,
    );
  }

  String _estadoProducto(Product producto) {
    if (!producto.activo) return 'OCULTO';
    if (producto.agotado) return 'AGOTADO';
    return 'DISPONIBLE';
  }

  Color _colorEstado(Product producto) {
    if (!producto.activo) return Colors.grey;
    if (producto.agotado) return Colors.redAccent;
    return Colors.green;
  }

  IconData _iconoEstado(Product producto) {
    if (!producto.activo) return Icons.visibility_off;
    if (producto.agotado) return Icons.remove_shopping_cart;
    return Icons.check_circle;
  }

  Future<void> _mostrarFormularioProducto(
    BuildContext context, {
    Product? producto,
  }) async {
    final userProvider = Provider.of<UserProvider>(
      context,
      listen: false,
    );

    final editando = producto != null;
    final esMuestraProtegida = producto?.esGratis == true;

    String nombre = producto?.nombre ?? '';
    String tipoBebida = producto?.tipoBebida ?? 'chicha';
    String descripcion = producto?.descripcion ?? '';
    double precio = producto?.precio ?? 0;
    int opcion = producto?.option ?? 2;
    String imagen = producto?.imagen ?? _imagenesDisponibles.first;

    String estado = producto == null
        ? 'disponible'
        : !producto.activo
            ? 'oculto'
            : producto.agotado
                ? 'agotado'
                : 'disponible';

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final opcionesPermitidas =
                esMuestraProtegida ? <int>[1] : <int>[2, 3, 4, 5, 6];

            if (!opcionesPermitidas.contains(opcion)) {
              opcion = opcionesPermitidas.first;
            }

            final cantidadMl = _mlPorOpcion[opcion] ?? 150;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    editando ? Icons.edit : Icons.add_circle,
                    color: AppColors.lilaOscuro,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      editando ? 'Editar producto' : 'Nuevo producto',
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: nombre,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del producto',
                          hintText: 'Ej. Refresco de linaza',
                          prefixIcon: Icon(Icons.local_drink),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => nombre = value,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: tipoBebida,
                        maxLength: 40,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de bebida',
                          hintText: 'Ej. linaza, durazno, hervido',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => tipoBebida = value,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: descripcion,
                        maxLength: 160,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          hintText: 'Descripción breve para el catálogo',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => descripcion = value,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: opcion,
                        decoration: const InputDecoration(
                          labelText: 'Presentación / programa de dispensado',
                          prefixIcon: Icon(Icons.straighten),
                          border: OutlineInputBorder(),
                        ),
                        items: opcionesPermitidas
                            .map(
                              (value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text(_textoOpcion[value] ?? '$value'),
                              ),
                            )
                            .toList(),
                        onChanged: esMuestraProtegida
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() => opcion = value);
                              },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cantidad configurada: $cantidadMl ml',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: precio.toStringAsFixed(2),
                        enabled: !esMuestraProtegida,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: esMuestraProtegida
                              ? 'Precio — producto gratuito'
                              : 'Precio (Bs)',
                          prefixIcon: const Icon(Icons.payments),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          final parsed = double.tryParse(
                            value.trim().replaceAll(',', '.'),
                          );
                          if (parsed != null) precio = parsed;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Estado del producto',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Disponible'),
                            avatar: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 18,
                            ),
                            selected: estado == 'disponible',
                            onSelected: (_) {
                              setDialogState(() => estado = 'disponible');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Agotado'),
                            avatar: const Icon(
                              Icons.remove_shopping_cart,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            selected: estado == 'agotado',
                            onSelected: (_) {
                              setDialogState(() => estado = 'agotado');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Oculto'),
                            avatar: const Icon(
                              Icons.visibility_off,
                              color: Colors.grey,
                              size: 18,
                            ),
                            selected: estado == 'oculto',
                            onSelected: (_) {
                              setDialogState(() => estado = 'oculto');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Seleccionar imagen',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '${_imagenesDisponibles.length} disponibles',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _imagenesDisponibles.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 9,
                          mainAxisSpacing: 9,
                          childAspectRatio: 0.90,
                        ),
                        itemBuilder: (context, index) {
                          final ruta = _imagenesDisponibles[index];
                          final seleccionada = ruta == imagen;

                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setDialogState(() => imagen = ruta);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: seleccionada
                                    ? AppColors.lilaOscuro.withValues(alpha: .10)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: seleccionada
                                      ? AppColors.lilaOscuro
                                      : Colors.grey.shade300,
                                  width: seleccionada ? 3 : 1,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        ruta,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Container(
                                            color: Colors.grey.shade200,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  if (seleccionada)
                                    const Positioned(
                                      top: 4,
                                      right: 4,
                                      child: CircleAvatar(
                                        radius: 11,
                                        backgroundColor: AppColors.lilaOscuro,
                                        child: Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (esMuestraProtegida) ...[
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield, color: Colors.orange),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'La muestra gratuita está protegida. '
                                  'Puede cambiar nombre, descripción, imagen '
                                  'y estado, pero no su presentación ni precio.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lilaOscuro,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final nombreLimpio = nombre.trim();
                    final tipoLimpio = tipoBebida.trim();

                    if (nombreLimpio.isEmpty || tipoLimpio.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Completa nombre y tipo de bebida.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (!esMuestraProtegida && precio < 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Introduce un precio válido.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      {
                        'nombre': nombreLimpio,
                        'tipoBebida': tipoLimpio,
                        'descripcion': descripcion.trim(),
                        'precio': esMuestraProtegida ? 0.0 : precio,
                        'imagen': imagen,
                        'opcion': opcion,
                        'cantidadMl': cantidadMl,
                        'activo': estado != 'oculto',
                        'agotado': estado == 'agotado',
                      },
                    );
                  },
                  icon: Icon(editando ? Icons.save : Icons.add),
                  label: Text(
                    editando ? 'Guardar cambios' : 'Crear producto',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == null) return;

    try {
      if (producto == null) {
        final nuevoId = await productService.crearProducto(
          nombre: resultado['nombre'] as String,
          descripcion: resultado['descripcion'] as String,
          tipoBebida: resultado['tipoBebida'] as String,
          cantidadMl: resultado['cantidadMl'] as int,
          precio: resultado['precio'] as double,
          imagen: resultado['imagen'] as String,
          opcion: resultado['opcion'] as int,
        );

        await _registrarAuditoria(
          userProvider,
          accion: 'producto_creado',
          descripcion:
              '${resultado['nombre']} → Creado',
          productoId: nuevoId,
          productoNombre:
              resultado['nombre'] as String,
          valorNuevo:
              '${resultado['cantidadMl']} ml • '
              '${(resultado['precio'] as double).toStringAsFixed(2)} Bs',
        );

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto creado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final String detalleAnterior =
            '${producto.cantidadMl} ml • '
            '${producto.precio.toStringAsFixed(2)} Bs • '
            '${_estadoProducto(producto)}';

        await productService.actualizarProducto(
          productoId: producto.productoId,
          nombre: resultado['nombre'] as String,
          descripcion: resultado['descripcion'] as String,
          tipoBebida: resultado['tipoBebida'] as String,
          cantidadMl: resultado['cantidadMl'] as int,
          precio: resultado['precio'] as double,
          imagen: resultado['imagen'] as String,
          opcion: resultado['opcion'] as int,
          esGratis: producto.esGratis,
          activo: resultado['activo'] as bool,
          agotado: resultado['agotado'] as bool,
        );
        final String nuevoEstado =
            !(resultado['activo'] as bool)
                ? 'OCULTO'
                : (resultado['agotado'] as bool)
                    ? 'AGOTADO'
                    : 'DISPONIBLE';

        final String detalleNuevo =
            '${resultado['cantidadMl']} ml • '
            '${(resultado['precio'] as double).toStringAsFixed(2)} Bs • '
            '$nuevoEstado';

        await _registrarAuditoria(
          userProvider,
          accion: 'producto_editado',
          descripcion:
              '${resultado['nombre']} → Editado',
          productoId: producto.productoId,
          productoNombre:
              resultado['nombre'] as String,
          valorAnterior: detalleAnterior,
          valorNuevo: detalleNuevo,
        );

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto actualizado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el producto: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _cambiarEstadoRapido(
    BuildContext context, {
    required Product producto,
    required String nuevoEstado,
  }) async {
    final userProvider = Provider.of<UserProvider>(
      context,
      listen: false,
    );

    final activo = nuevoEstado != 'oculto';
    final agotado = nuevoEstado == 'agotado';

    try {
      await productService.actualizarProducto(
        productoId: producto.productoId,
        nombre: producto.nombre,
        descripcion: producto.descripcion,
        tipoBebida: producto.tipoBebida,
        cantidadMl: producto.cantidadMl,
        precio: producto.precio,
        imagen: producto.imagen,
        opcion: producto.option,
        esGratis: producto.esGratis,
        activo: activo,
        agotado: agotado,
      );

      await _registrarAuditoria(
        userProvider,
        accion: 'estado_producto',
        descripcion:
            'Cambió ${producto.nombre} a ${nuevoEstado.toUpperCase()}',
        productoId: producto.productoId,
        productoNombre: producto.nombre,
        valorAnterior: _estadoProducto(producto),
        valorNuevo: nuevoEstado.toUpperCase(),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar el estado: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _eliminarProducto(
    BuildContext context,
    Product producto,
  ) async {
    final userProvider = Provider.of<UserProvider>(
      context,
      listen: false,
    );

    if (producto.esGratis) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La muestra gratuita está protegida y no puede eliminarse.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Eliminar producto',
                  maxLines: 2,
                ),
              ),
            ],
          ),
          content: Text(
            '¿Eliminar definitivamente "${producto.nombre}"?\n\n'
            'Esta acción lo quitará de Firestore y no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete),
              label: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await productService.eliminarProducto(
        productoId: producto.productoId,
      );

      await _registrarAuditoria(
        userProvider,
        accion: 'producto_eliminado',
        descripcion:
            '${producto.nombre} → Eliminado',
        productoId: producto.productoId,
        productoNombre: producto.nombre,
        valorAnterior:
            '${producto.cantidadMl} ml • '
            '${producto.precio.toStringAsFixed(2)} Bs • '
            '${_estadoProducto(producto)}',
        valorNuevo: 'ELIMINADO',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${producto.nombre} fue eliminado.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _tarjetaProducto(
    BuildContext context,
    Product producto,
  ) {
    final colorEstado = _colorEstado(producto);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2.5,
      child: ExpansionTile(
        key: PageStorageKey<String>(
          'admin_producto_${producto.productoId}',
        ),
        leading: SizedBox(
          width: 58,
          height: 58,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              producto.imagen,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.local_drink,
                    color: AppColors.lilaOscuro,
                  ),
                );
              },
            ),
          ),
        ),
        title: Text(
          producto.nombre,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: producto.activo ? Colors.black87 : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              producto.esGratis
                  ? '${producto.cantidadMl} ml • GRATIS'
                  : '${producto.cantidadMl} ml • '
                      '${producto.precio.toStringAsFixed(2)} Bs',
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconoEstado(producto),
                  size: 14,
                  color: colorEstado,
                ),
                const SizedBox(width: 4),
                Text(
                  _estadoProducto(producto),
                  style: TextStyle(
                    color: colorEstado,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: producto.esGratis
            ? const Chip(label: Text('GRATIS'))
            : Icon(Icons.expand_more, color: colorEstado),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          const Divider(),
          if (producto.descripcion.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  producto.descripcion,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _mostrarFormularioProducto(
                      context,
                      producto: producto,
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
              ),
              if (!producto.esGratis) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Editar precio rápido',
                  color: AppColors.lilaOscuro,
                  onPressed: () {
                    onEditarPrecioRapido(producto);
                  },
                  icon: const Icon(Icons.price_change),
                ),
              ],
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Estado',
                icon: Icon(Icons.inventory_2, color: colorEstado),
                onSelected: (value) {
                  _cambiarEstadoRapido(
                    context,
                    producto: producto,
                    nuevoEstado: value,
                  );
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'disponible',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Disponible'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'agotado',
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.remove_shopping_cart,
                        color: Colors.redAccent,
                      ),
                      title: Text('Agotado'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'oculto',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.visibility_off, color: Colors.grey),
                      title: Text('Oculto'),
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip:
                    producto.esGratis ? 'Muestra protegida' : 'Eliminar',
                color: producto.esGratis ? Colors.grey : Colors.redAccent,
                onPressed: producto.esGratis
                    ? null
                    : () {
                        _eliminarProducto(context, producto);
                      },
                icon: Icon(
                  producto.esGratis ? Icons.shield : Icons.delete_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contadorEstado({
    required int valor,
    required String texto,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: .25),
        ),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(height: 3),
          Text(
            '$valor',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              texto,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: productService.observarProductos(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo leer el catálogo.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final productos = snapshot.data ?? <Product>[];

        final disponibles = productos
            .where((p) => p.activo && !p.agotado)
            .length;

        final agotados = productos
            .where((p) => p.activo && p.agotado)
            .length;

        final ocultos = productos.where((p) => !p.activo).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestión de productos',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'CRUD del catálogo en tiempo real.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lilaOscuro,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _mostrarFormularioProducto(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _contadorEstado(
                    valor: disponibles,
                    texto: 'Disponibles',
                    icono: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _contadorEstado(
                    valor: agotados,
                    texto: 'Agotados',
                    icono: Icons.remove_shopping_cart,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _contadorEstado(
                    valor: ocultos,
                    texto: 'Ocultos',
                    icono: Icons.visibility_off,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (productos.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(25),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 55,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 10),
                      Text('No hay productos registrados.'),
                    ],
                  ),
                ),
              ),
            ...productos.map(
              (producto) => _tarjetaProducto(context, producto),
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}
