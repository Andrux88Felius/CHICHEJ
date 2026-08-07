import '../models/product_model.dart';

List<Product> productos = [
  Product(
    nombre: "Chicha 150ml",
    descripcion: "Chicha tradicional",
    precio: 5,
    imagen: "assets/150ml.png",
    option: 2,
  ),

  Product(
    nombre: "Chicha 250ml",
    descripcion: "Chicha refrescante",
    precio: 10,
    imagen: "assets/250ml.jpg",
    option: 3,
  ),

  Product(
    nombre: "Chicha 500ml",
    descripcion: "Ideal para compartir",
    precio: 18,
    imagen: "assets/500ml.jpg",
    option: 4,
  ),

  Product(
    nombre: "Chicha 750ml",
    descripcion: "Para disfrutar en familia",
    precio: 25,
    imagen: "assets/750ml.jpg",
    option: 5,
  ),

  Product(
    nombre: "Chicha 1L",
    descripcion: "Máxima cantidad",
    precio: 30,
    imagen: "assets/1000ml.jpg",
    option: 6,
  ),

  // 🎁 PRUEBA GRATIS
  Product(
    nombre: "Prueba gratis 45ml",
    descripcion: "Solo por registro",
    precio: 0,
    imagen: "assets/logochichej.png", // o cambia por otra si tienes
    esGratis: true,
    option: 1,
  ),
];
