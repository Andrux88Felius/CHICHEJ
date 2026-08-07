import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String mensaje = "Has pulsado en el teléfono";

  void mostrarSnackbar(String texto, BuildContext context) {
    setState(() {
      mensaje = "Has pulsado en $texto";
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Has pulsado en $texto"),
        backgroundColor: Colors.deepPurple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Listview + Mensaje',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color.fromARGB(255, 97, 82, 38), // Fondo naranjado claro
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 120, 173, 201), // Naranja más oscuro para AppBar
          title: const Text(
            'Listview + Mensaje',
            style: TextStyle(color: Color.fromARGB(255, 23, 23, 23), fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Título principal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Color.fromARGB(255, 255, 228, 179), // Fondo naranjado muy claro
              child: const Text(
                'Datos Usuarios',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Imagen de familia
            Center(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[800]!, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/150ml.jpeg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 200,
                      color: Colors.amber[100],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, color: Color.fromARGB(255, 87, 115, 138), size: 50),
                          Text('150ml.jpeg'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Perfil
            _buildListTile(
              Icons.person, 
              'Perfil', 
              'Información personal', 
              Color.fromARGB(255, 218, 127, 9),
              () => mostrarSnackbar('Perfil', context),
            ),
            
            const SizedBox(height: 10),
            
            // Teléfono
            _buildListTile(
              Icons.phone, 
              'Teléfono', 
              'Datos del teléfono', 
              Colors.green,
              () => mostrarSnackbar('el teléfono', context),
            ),
            
            const SizedBox(height: 10),
            
            // Email
            _buildListTile(
              Icons.email, 
              'Email', 
              'Datos del email', 
              Colors.red,
              () => mostrarSnackbar('Email', context),
            ),
            
            const SizedBox(height: 10),
            
            // Dirección
            _buildListTile(
              Icons.location_on, 
              'Dirección', 
              'Datos de domicilio', 
              Colors.orange,
              () => mostrarSnackbar('Dirección', context),
            ),
            
            const SizedBox(height: 10),
            
            // Trabajo
            _buildListTile(
              Icons.work, 
              'Trabajo', 
              'Información laboral', 
              Colors.purple,
              () => mostrarSnackbar('Trabajo', context),
            ),
            
            const SizedBox(height: 10),
            
            // Configuración
            _buildListTile(
              Icons.settings, 
              'Configuración', 
              'Ajustes de la cuenta', 
              Color.fromARGB(255, 158, 158, 158),
              () => mostrarSnackbar('Configuración', context),
            ),
            
            const SizedBox(height: 30),
            
            // Mensaje inferior
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 21, 194, 44), // Naranja como AppBar
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[800]!, width: 1),
              ),
              child: Text(
                mensaje,
                style: const TextStyle(
                  color: Color.fromARGB(255, 230, 140, 6),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, Color iconColor, VoidCallback onTap) {
    return Card(
      elevation: 2,
      color: Color.fromARGB(255, 241, 197, 138), // Fondo blanco para las tarjetas
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.amber[300]!, width: 1), // Borde naranjado
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Color.fromARGB(255, 154, 226, 172)),
        onTap: onTap,
      ),
    );
  }
}