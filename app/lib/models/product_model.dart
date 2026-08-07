class Product {
  final String productoId;
  final String bebidaId;
  final String tipoBebida;
  final int cantidadMl;
  String nombre;
  String descripcion;
  double precio;
  bool esGratis;
  String imagen;
  final int option;

  Product({
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
  });
}
