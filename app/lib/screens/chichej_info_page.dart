import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/music_service.dart';
import '../utils/colors.dart';

class ChichejInfoPage extends StatelessWidget {
  const ChichejInfoPage({super.key});

  static const String _facebookUrl =
      'https://www.facebook.com/share/19654KdARH/';
  static const String _instagramUrl =
      'https://www.instagram.com/chichejwinapu?igsh=aGd6MWgzbjJhMWt0';
  static const String _tiktokUrl = 'https://www.tiktok.com/@chichej.wiapu';
  static const String _whatsappNumero = '59177271557';
  static const String _whatsappMensaje =
      'Hola, vengo desde la app CHICHEJ y quisiera más información.';

  Future<void> _abrirUrl(
    BuildContext context,
    String? url, {
    String? mensajeNoConfigurado,
  }) async {
    if (url == null || url.trim().isEmpty) {
      _mostrarMensaje(
        context,
        mensajeNoConfigurado ?? 'Este enlace todavía no está configurado.',
      );
      return;
    }

    final uri = Uri.parse(url);
    var abierto = false;

    try {
      abierto = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      abierto = false;
    }

    if (!abierto) {
      try {
        abierto = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        abierto = false;
      }
    }

    if (!abierto && context.mounted) {
      _mostrarMensaje(context, 'No se pudo abrir el enlace.');
    }
  }

  void _mostrarMensaje(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  String get _whatsappUrl => 'https://wa.me/$_whatsappNumero?text='
      '${Uri.encodeComponent(_whatsappMensaje)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Información de CHICHEJ'),
        backgroundColor: AppColors.lilaOscuro,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xffe9f7f5),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/logo-chichej.png',
                    width: 190,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'CHICHEJ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xff00796b),
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Text(
                  'Bebidas Tradicionales Bolivianas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '“Tradición que nos une,\ninnovación que nos impulsa.”',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.lilaOscuro,
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                _seccion(
                  titulo: '¿QUÉ ES CHICHEJ?',
                  contenido: const Text(
                    'CHICHEJ es un sistema inteligente de dispensación '
                    'automatizada de bebidas tradicionales bolivianas, '
                    'integrado con una aplicación móvil y tecnologías IoT.\n\n'
                    'Permite gestionar pedidos, controlar la dispensación '
                    'y mantener un registro digital de las operaciones '
                    'del sistema.',
                    textAlign: TextAlign.justify,
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
                const SizedBox(height: 18),
                _musicSection(),
                const SizedBox(height: 18),
                _seccion(
                  titulo: 'SÍGUENOS Y CONTÁCTANOS',
                  contenido: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 12,
                    runSpacing: 16,
                    children: [
                      _redSocial(
                        context: context,
                        nombre: 'Facebook',
                        asset: 'assets/redes-ico/Facebook_Logo_Primary.png',
                        onTap: () => _abrirUrl(context, _facebookUrl),
                      ),
                      _redSocial(
                        context: context,
                        nombre: 'Instagram',
                        asset: 'assets/redes-ico/Instagram_Glyph_Gradient.png',
                        onTap: () => _abrirUrl(context, _instagramUrl),
                      ),
                      _redSocial(
                        context: context,
                        nombre: 'TikTok',
                        asset: 'assets/redes-ico/TikTok_Icon_Black_Circle.png',
                        onTap: () => _abrirUrl(
                          context,
                          _tiktokUrl,
                          mensajeNoConfigurado:
                              'El enlace de TikTok todavía no está configurado.',
                        ),
                      ),
                      _redSocial(
                        context: context,
                        nombre: 'WhatsApp',
                        asset:
                            'assets/redes-ico/Digital_Glyph_Green_RGB_2026.png',
                        onTap: () => _abrirUrl(context, _whatsappUrl),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _seccion(
                  titulo: 'INFORMACIÓN INSTITUCIONAL',
                  contenido: Column(
                    children: [
                      const Text(
                        'Proyecto desarrollado en el\n'
                        'Instituto Tecnológico Marcelo Quiroga Santa Cruz',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Carrera de Sistemas Informáticos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.lilaOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FractionallySizedBox(
                        widthFactor: 0.62,
                        child: Image.asset(
                          'assets/icon/logo-feria.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '© 2026 CHICHEJ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xff00796b),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _seccion({
    required String titulo,
    required Widget contenido,
  }) {
    return Card(
      elevation: 1.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xffb2dfdb)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.lilaOscuro,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            const Divider(color: AppColors.dorado, thickness: 1.3),
            const SizedBox(height: 10),
            contenido,
          ],
        ),
      ),
    );
  }

  Widget _redSocial({
    required BuildContext context,
    required String nombre,
    required String asset,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: 'Abrir $nombre',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
              const SizedBox(height: 6),
              Text(
                nombre,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _musicSection() {
    return Consumer<MusicService>(
      builder: (context, musicService, _) {
        return _seccion(
          titulo: 'MÚSICA AMBIENTAL',
          contenido: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  musicService.enabled ? 'Sonido ON' : 'Sonido OFF',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  musicService.enabled
                      ? 'Reproduciendo: ${musicService.currentTrackName}'
                      : 'La música está pausada.',
                ),
                value: musicService.enabled,
                activeThumbColor: AppColors.turquesa,
                onChanged: musicService.setEnabled,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<MusicSelection>(
                key: ValueKey(musicService.selection),
                initialValue: musicService.selection,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Selección de canción',
                  prefixIcon: Icon(
                    Icons.music_note,
                    color: AppColors.turquesa,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: MusicSelection.values
                    .map(
                      (selection) => DropdownMenuItem(
                        value: selection,
                        child: Text(musicService.labelFor(selection)),
                      ),
                    )
                    .toList(),
                onChanged: (selection) {
                  if (selection != null) {
                    musicService.select(selection);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
