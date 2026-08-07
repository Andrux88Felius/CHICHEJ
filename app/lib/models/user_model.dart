enum TipoSesion {
  invitado,
  registrado,
  admin,
  desconocido,
}

class UserModel {
  String? uid; // Es bueno tenerlo aquí para operaciones futuras
  String nombre;
  String email;
  String password;
  TipoSesion tipoSesion;
  int muestrasGratisDisponibles;
  int muestrasGratisUtilizadas;
  String? avatarPath; 
  String? rol;       

  UserModel({
    this.uid,
    required this.nombre,
    required this.email,
    this.password = "",
    required this.tipoSesion,
    this.muestrasGratisDisponibles = 0,
    this.muestrasGratisUtilizadas = 0,
    this.avatarPath,
    this.rol = "cliente",
  });

  // Esto ayuda a convertir los datos de Firebase a un objeto UserModel
  factory UserModel.fromMap(Map<dynamic, dynamic> map, String uid) {
    final rol = map['rol']?.toString() ?? "cliente";
    final esAdmin = rol == "admin";

    return UserModel(
      uid: uid,
      nombre: map['nombre'] ?? "Usuario",
      email: map['email'] ?? "",
      tipoSesion: esAdmin 
      ? TipoSesion.admin 
      : TipoSesion.registrado,
      muestrasGratisDisponibles:
      (map['muestrasGratisDisponibles'] as num ?)?.toInt() ?? 0,
      muestrasGratisUtilizadas: 
      (map['muestrasGratisUtilizadas'] as num ?)?.toInt() ?? 0,
      avatarPath: esAdmin
          ? "assets/icon/logo_icon2.png"
          : map['avatarPath'],
      rol: rol
    );
  }
}