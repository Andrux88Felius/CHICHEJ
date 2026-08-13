import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/reservation_service.dart';
import '../utils/colors.dart';

class EventOrderPage extends StatefulWidget {
  const EventOrderPage({super.key});

  @override
  State<EventOrderPage> createState() => _EventOrderPageState();
}

class _EventOrderPageState extends State<EventOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = ReservationService();
  final _detailController = TextEditingController();
  final _quantityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _placeController = TextEditingController();
  final _addressController = TextEditingController();
  final _referencesController = TextEditingController();
  final _observationsController = TextEditingController();
  DateTime? _selectedDate;
  bool _saving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de la reserva.')),
      );
      return;
    }
    final provider = context.read<UserProvider>();
    final user = provider.user;
    if (user == null || provider.esInvitado || user.uid == null) return;
    setState(() => _saving = true);
    try {
      await _service.create(
        clientName: user.nombre,
        phone: _phoneController.text,
        email: user.email,
        detail: _detailController.text,
        requestedQuantity: _quantityController.text,
        requestedDate: _selectedDate!,
        userId: user.uid!,
        eventPlace: _placeController.text,
        address: _addressController.text,
        locationReferences: _referencesController.text,
        observations: _observationsController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva enviada al administrador.')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar la reserva.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    _quantityController.dispose();
    _phoneController.dispose();
    _placeController.dispose();
    _addressController.dispose();
    _referencesController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reserva especial'),
        backgroundColor: AppColors.lilaOscuro,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Image.asset('assets/pedidos.png', height: 180, fit: BoxFit.cover),
            const SizedBox(height: 18),
            const Text(
              'Solicitud comercial para eventos, pedidos por volumen, '
              'bebidas embotelladas o en bidones. No se envía al dispensador.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _detailController,
              decoration: const InputDecoration(
                labelText: 'Detalle del pedido o evento',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo requerido'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Cantidad solicitada en litros o unidades',
                hintText: 'Ej.: 20 litros, 50 botellas o 4 bidones',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                return value == null || value.trim().isEmpty
                    ? 'Ingresa la cantidad solicitada'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _placeController,
              decoration: const InputDecoration(
                labelText: 'Lugar del evento o entrega',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo requerido'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo requerido'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _referencesController,
              decoration: const InputDecoration(
                labelText: 'Referencias del lugar (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono de contacto',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().length < 7
                  ? 'Ingresa un teléfono válido'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _observationsController,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _selectedDate == null
                    ? 'Seleccionar fecha del evento o entrega'
                    : 'Fecha del evento o entrega: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _saving ? null : _pickDate,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Confirmar reserva'),
            ),
          ],
        ),
      ),
    );
  }
}
