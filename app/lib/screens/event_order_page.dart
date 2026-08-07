import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../providers/order_provider.dart';

class EventOrderPage extends StatefulWidget {
  const EventOrderPage({super.key});

  @override
  State<EventOrderPage> createState() => _EventOrderPageState();
}

class MonthlyPromoPage extends StatelessWidget {
  final List<String> promos = [
    'assets/promos/enero.png', // índice 0
    'assets/promos/febrero.png', // índice 1
    'assets/promos/marzo.png', // índice 2
    'assets/promos/abril.png', // índice 3
    'assets/promos/mayo.png', // índice 4
    'assets/promos/junio.png', // índice 5
    'assets/promos/julio.png', // índice 6
    'assets/promos/agosto.png', // índice 7
    'assets/promos/septiembre.png', // índice 8
    'assets/promos/octubre.png', // índice 9
    'assets/promos/noviembre.png', // índice 10
    'assets/promos/diciembre.png', // índice 11
  ];

  @override
  Widget build(BuildContext context) {
    int mesActual = DateTime.now().month; // 1-12
    String imagenPromo = promos[mesActual - 1]; // Ajuste a base 0

    return Scaffold(
      appBar: AppBar(title: const Text("Promoción del Mes")),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25), // Bordes redondeados
                child: Image.asset(imagenPromo),
              ),
            ),
            const Text("¡Aprovecha la promoción de este mes!", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _EventOrderPageState extends State<EventOrderPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  final TextEditingController _eventoController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pedido para Evento"), backgroundColor: AppColors.lilaOscuro),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/pedidos.png', height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _eventoController,
                decoration: const InputDecoration(labelText: "Nombre del Evento", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Cantidad de unidades", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
    // ... campos evento y cantidad ...
    TextFormField(
      controller: _telefonoController,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(labelText: "Teléfono de contacto", border: OutlineInputBorder()),
    ),
              const SizedBox(height: 15),
              ListTile(
                title: Text(_selectedDate == null ? "Seleccionar fecha" : "Fecha: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.dorado),
                  onPressed: () {
      if (_formKey.currentState!.validate()) {
        Provider.of<OrderProvider>(context, listen: false).registrarReserva(
          _eventoController.text,
          int.parse(_cantidadController.text),
          _selectedDate!,
          _telefonoController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reserva enviada al administrador")));
      }
    },
                  child: const Text("Confirmar Reserva", style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}