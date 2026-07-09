// pantallas/pantalla_login.dart
// Pantalla de inicio de sesión con Firebase Auth

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../servicios/servicio_auth.dart';
import 'pantalla_registro.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _EstadoPantallaLogin();
}

class _EstadoPantallaLogin extends State<PantallaLogin> {
  final ServicioAuth _servicioAuth = ServicioAuth();
  final _formKey = GlobalKey<FormState>();
  final _controladorEmail = TextEditingController();
  final _controladorContrasena = TextEditingController();

  bool _cargando = false;
  bool _verContrasena = false;
  String _mensajeError = '';

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _mensajeError = '';
    });
    try {
      await _servicioAuth.iniciarSesion(
        email: _controladorEmail.text,
        contrasena: _controladorContrasena.text,
      );
      // La navegación la gestiona el StreamBuilder de main.dart
    } on FirebaseAuthException catch (e) {
      setState(() => _mensajeError = _servicioAuth.traducirError(e.code));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _controladorEmail.dispose();
    _controladorContrasena.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),

                  // Icono y título
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E75B6).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.movie_rounded,
                      size: 56,
                      color: Color(0xFF2E75B6),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'CineAI',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Tu sala de cine personal',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white38,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Campo email
                  TextFormField(
                    controller: _controladorEmail,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoracionCampo(
                      'Correo electrónico',
                      Icons.email_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Introduce tu correo';
                      }
                      if (!v.contains('@')) return 'Correo no válido';
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Campo contraseña
                  TextFormField(
                    controller: _controladorContrasena,
                    obscureText: !_verContrasena,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoracionCampo(
                      'Contraseña',
                      Icons.lock_outline_rounded,
                      sufijo: IconButton(
                        icon: Icon(
                          _verContrasena
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white38,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _verContrasena = !_verContrasena),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Introduce tu contraseña';
                      return null;
                    },
                    onFieldSubmitted: (_) => _iniciarSesion(),
                  ),

                  // Mensaje de error
                  if (_mensajeError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
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

                  const SizedBox(height: 24),

                  // Botón iniciar sesión
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _cargando
                        ? const Center(child: CircularProgressIndicator())
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1565C0),
                                  Color(0xFF42A5F5)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2E75B6)
                                      .withValues(alpha: 0.4),
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
                              onPressed: _iniciarSesion,
                              child: const Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Divisor
                  const Row(
                    children: [
                      Expanded(
                          child: Divider(color: Colors.white12)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('o',
                            style: TextStyle(color: Colors.white38)),
                      ),
                      Expanded(
                          child: Divider(color: Colors.white12)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Botón crear cuenta
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFF2E75B6), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PantallaRegistro()),
                        );
                      },
                      child: const Text(
                        'Crear cuenta nueva',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
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
}
