// pantallas/pantalla_registro.dart
// Pantalla de creación de cuenta nueva con Firebase Authentication.
// Valida nombre, correo y contraseña antes de llamar a ServicioAuth.registrarse().
// Al registrarse correctamente, el StreamBuilder de main.dart navega
// automáticamente a PantallaShell sin necesidad de Navigator manual.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../servicios/servicio_auth.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _EstadoPantallaRegistro();
}

class _EstadoPantallaRegistro extends State<PantallaRegistro> {
  final ServicioAuth _servicioAuth = ServicioAuth();
  final _formKey = GlobalKey<FormState>();
  final _controladorNombre = TextEditingController();
  final _controladorEmail = TextEditingController();
  final _controladorContrasena = TextEditingController();
  final _controladorConfirmar = TextEditingController();

  bool _cargando = false;
  bool _verContrasena = false;
  bool _verConfirmar = false;
  String _mensajeError = '';

  Future<void> _registrarse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _mensajeError = '';
    });
    try {
      await _servicioAuth.registrarse(
        nombre: _controladorNombre.text,
        email: _controladorEmail.text,
        contrasena: _controladorContrasena.text,
      );
      // El StreamBuilder de main.dart redirige automáticamente al inicio
    } on FirebaseAuthException catch (e) {
      setState(() => _mensajeError = _servicioAuth.traducirError(e.code));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _controladorNombre.dispose();
    _controladorEmail.dispose();
    _controladorContrasena.dispose();
    _controladorConfirmar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        title: const Text('Crear cuenta'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenido a CineAI',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Crea tu cuenta para guardar tus favoritas',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 32),

                // Nombre
                TextFormField(
                  controller: _controladorNombre,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoracionCampo('Nombre', Icons.person_outline),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Introduce tu nombre';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Email
                TextFormField(
                  controller: _controladorEmail,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      _decoracionCampo('Correo electrónico', Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Introduce tu correo';
                    }
                    if (!v.contains('@')) return 'Correo no válido';
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Contraseña
                TextFormField(
                  controller: _controladorContrasena,
                  obscureText: !_verContrasena,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoracionCampo(
                    'Contraseña',
                    Icons.lock_outline_rounded,
                    sufijo: _botonVerContrasena(
                      _verContrasena,
                      () => setState(() => _verContrasena = !_verContrasena),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Introduce una contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Confirmar contraseña
                TextFormField(
                  controller: _controladorConfirmar,
                  obscureText: !_verConfirmar,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoracionCampo(
                    'Confirmar contraseña',
                    Icons.lock_outline_rounded,
                    sufijo: _botonVerContrasena(
                      _verConfirmar,
                      () => setState(() => _verConfirmar = !_verConfirmar),
                    ),
                  ),
                  validator: (v) {
                    if (v != _controladorContrasena.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),

                // Mensaje de error
                if (_mensajeError.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _mensajeError,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Botón registrarse
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _cargando
                      ? const Center(child: CircularProgressIndicator())
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF2E75B6).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _registrarse,
                            child: const Text(
                              'Crear cuenta',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                // Ya tengo cuenta
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Ya tengo cuenta — Iniciar sesión',
                      style: TextStyle(
                        color: Color(0xFF2E75B6),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracionCampo(
    String etiqueta,
    IconData icono, {
    Widget? sufijo,
  }) {
    return InputDecoration(
      hintText: etiqueta,
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icono, color: Colors.white38, size: 20),
      suffixIcon: sufijo,
      filled: true,
      fillColor: const Color(0xFF161625),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _botonVerContrasena(bool visible, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: Colors.white38,
        size: 20,
      ),
      onPressed: onTap,
    );
  }
}
