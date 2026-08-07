class Product {
  final String productoId;
  final String bebidaId;
  final String tipoBebida;
  final int cantidadMl;

  final String nombre;
  final String descripcion;
  final double precio;
  final bool esGratis;
  final String imagen;
  final int option;
  final bool activo;

  const Product({
    required this.productoId,
    required this.bebidaId,
    required this.tipoBebida,
    required this.cantidadMl,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.imagen,
    required this.option,
    this.esGratis = false,
    this.activo = true,
  });

  factory Product.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final productoId = map['productoId']?.toString().trim().isNotEmpty == true
        ? map['productoId'].toString()
        : documentId;

    if (productoId == null || productoId.isEmpty) {
      throw const FormatException(
        'El producto no tiene productoId válido.',
      );
    }

    final precioRaw = map['precio'];
    final cantidadRaw = map['cantidadMl'];
    final opcionRaw = map['opcion'];

    if (precioRaw is! num) {
      throw FormatException(
        'Producto $productoId: precio inválido '
        '(${precioRaw.runtimeType}: $precioRaw)',
      );
    }

    if (cantidadRaw is! num) {
      throw FormatException(
        'Producto $productoId: cantidadMl inválida '
        '(${cantidadRaw.runtimeType}: $cantidadRaw)',
      );
    }

    if (opcionRaw is! num) {
      throw FormatException(
        'Producto $productoId: opcion inválida '
        '(${opcionRaw.runtimeType}: $opcionRaw)',
      );
    }

    return Product(
      productoId: productoId,
      bebidaId: map['bebidaId']?.toString() ?? '',
      tipoBebida: map['tipoBebida']?.toString() ?? '',
      cantidadMl: cantidadRaw.toInt(),
      nombre: map['nombre']?.toString() ?? 'Producto',
      descripcion: map['descripcion']?.toString() ?? '',
      precio: precioRaw.toDouble(),
      imagen: map['imagen']?.toString() ?? 'assets/logochichej.png',
      option: opcionRaw.toInt(),
      esGratis: map['esGratis'] == true,
      activo: map['activo'] != false,
    );
  }

  Product copyWith({
    String? productoId,
    String? bebidaId,
    String? tipoBebida,
    int? cantidadMl,
    String? nombre,
    String? descripcion,
    double? precio,
    bool? esGratis,
    String? imagen,
    int? option,
    bool? activo,
  }) {
    return Product(
      productoId: productoId ?? this.productoId,
      bebidaId: bebidaId ?? this.bebidaId,
      tipoBebida: tipoBebida ?? this.tipoBebida,
      cantidadMl: cantidadMl ?? this.cantidadMl,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precio: precio ?? this.precio,
      imagen: imagen ?? this.imagen,
      option: option ?? this.option,
      esGratis: esGratis ?? this.esGratis,
      activo: activo ?? this.activo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'bebidaId': bebidaId,
      'tipoBebida': tipoBebida,
      'cantidadMl': cantidadMl,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'imagen': imagen,
      'opcion': option,
      'esGratis': esGratis,
      'activo': activo,
    };
  }
}
