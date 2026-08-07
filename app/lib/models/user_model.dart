enum TipoSesion {
  invitado,
  registrado,
  admin,
  desconocido,
}

class UserModel {
  String? uid;
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
    this.password = '',
    required this.tipoSesion,
    this.muestrasGratisDisponibles = 0,
    this.muestrasGratisUtilizadas = 0,
    this.avatarPath,
    this.rol = 'cliente',
  });

  factory UserModel.fromMap(
    Map<dynamic, dynamic> map,
    String uid,
  ) {
    final String rol = map['rol']?.toString() ?? 'cliente';

    final bool esAdministrador = rol == 'admin' || rol == 'admin_principal';

    return UserModel(
      uid: uid,
      nombre: map['nombre']?.toString() ?? 'Usuario',
      email: map['email']?.toString() ?? '',
      tipoSesion: esAdministrador ? TipoSesion.admin : TipoSesion.registrado,
      muestrasGratisDisponibles:
          (map['muestrasGratisDisponibles'] as num?)?.toInt() ?? 0,
      muestrasGratisUtilizadas:
          (map['muestrasGratisUtilizadas'] as num?)?.toInt() ?? 0,
      avatarPath: esAdministrador
          ? 'assets/logochichej.png'
          : map['avatarPath']?.toString(),
      rol: rol,
    );
  }
}
