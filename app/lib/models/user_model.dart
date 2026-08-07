class UserModel {
  String? uid; // Es bueno tenerlo aquí para operaciones futuras
  String nombre;
  String email;
  String password;
  bool pruebaGratis;
  String? avatarPath; // Nuevo: guarda la ruta del animalito elegido
  String? rol;       // Nuevo: "cliente" o "admin"

  UserModel({
    this.uid,
    required this.nombre,
    required this.email,
    required this.password,
    this.pruebaGratis = true,
    this.avatarPath,
    this.rol = "cliente", // Valor por defecto
  });

  // Esto ayuda a convertir los datos de Firebase a un objeto UserModel
  factory UserModel.fromMap(Map<dynamic, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      nombre: map['nombre'] ?? "Usuario",
      email: map['email'] ?? "",
      password: "", // Normalmente no guardamos la contraseña en el modelo por seguridad
      avatarPath: map['avatarPath'],
      rol: map['rol'] ?? "cliente",
    );
  }
}