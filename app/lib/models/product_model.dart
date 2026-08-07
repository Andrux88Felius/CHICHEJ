class Product {
  String nombre;
  String descripcion;
  double precio;
  bool esGratis;
  String imagen; // 
  final int option;

  Product({
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.imagen,
    required this.option,
    this.esGratis = false,
  });
}
