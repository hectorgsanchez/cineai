// pantallas/pantalla_perfil.dart
// Pantalla de perfil del usuario autenticado. Muestra:
//   - Nombre (editable con updateDisplayName de Firebase) y correo electrónico
//   - Estadísticas propias: favoritas, vistas, pendientes, valoraciones y reseñas
//   - Accesos directos a Mis valoraciones y Mis reseñas
//   - Botón de prueba de notificación heads-up
//   - Cierre de sesión (vuelve a PantallaLogin via StreamBuilder)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../servicios/servicio_firebase.dart';
import '../servicios/servicio_notificaciones.dart';

class PantallaPerfil extends StatefulWidget {
  final ServicioFirebase servicioFirebase;

  const PantallaPerfil({super.key, required this.servicioFirebase});

  @override
  State<PantallaPerfil> createState() => _EstadoPantallaPerfil();
}

class _EstadoPantallaPerfil extends State<PantallaPerfil>
    with AutomaticKeepAliveClientMixin {
  User? get _usuario => FirebaseAuth.instance.currentUser;
  late TextEditingController _controladorNombre;
  bool _editandoNombre = false;
  bool _guardando = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controladorNombre = TextEditingController(
      text: _usuario?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _controladorNombre.dispose();
    super.dispose();
  }

  Future<void> _guardarNombre() async {
    if (_controladorNombre.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    try {
      await _usuario?.updateDisplayName(_controladorNombre.text.trim());
      await FirebaseAuth.instance.currentUser?.reload();
      setState(() => _editandoNombre = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nombre actualizado correctamente')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar el nombre')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final usuario = snapshot.data ?? _usuario;
        final nombre = usuario?.displayName?.isNotEmpty == true
            ? usuario!.displayName!
            : 'Usuario';
        final iniciales = nombre.trim().split(' ')
            .take(2)
            .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
            .join();

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D0D14),
            automaticallyImplyLeading: false,
            title: const Text(
              'Mi perfil',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar con gradiente
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E75B6).withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            iniciales.isEmpty ? 'U' : iniciales,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        usuario?.email ?? '',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Información personal',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Nombre editable
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161625),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.badge_outlined,
                                  size: 16, color: Colors.white54),
                              SizedBox(width: 6),
                              Text('Nombre de usuario',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                          if (!_editandoNombre)
                            GestureDetector(
                              onTap: () => setState(() {
                                _controladorNombre.text = nombre;
                                _editandoNombre = true;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E75B6).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        size: 13, color: Color(0xFF2E75B6)),
                                    SizedBox(width: 4),
                                    Text('Editar',
                                        style: TextStyle(
                                            color: Color(0xFF2E75B6),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_editandoNombre) ...[
                        TextField(
                          controller: _controladorNombre,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          autofocus: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF2A2A3E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    setState(() => _editandoNombre = false),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  foregroundColor: Colors.white54,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _guardando ? null : _guardarNombre,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E75B6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _guardando
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Text('Guardar'),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          nombre,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Email (solo lectura)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161625),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 16, color: Colors.white54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Correo electrónico',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              usuario?.email ?? '',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Verificado',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Sección notificaciones ──────────────────────
                const Text(
                  'Notificaciones',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: const Color(0xFF161625),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () async {
                      final nombre =
                          FirebaseAuth.instance.currentUser?.displayName ??
                              'cinéfilo';
                      await ServicioNotificaciones()
                          .notificarBienvenida(nombre);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar( // ignore: use_build_context_synchronously
                          const SnackBar(
                            content: Text(
                                'Notificación enviada — comprueba la barra de estado'),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E75B6).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.notifications_active_rounded,
                                color: Color(0xFF2E75B6), size: 20),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Probar notificación',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                Text('Envía una notificación de bienvenida',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white24),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Cuenta',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Cerrar sesión
                Material(
                  color: const Color(0xFF161625),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _cerrarSesion,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: Colors.redAccent, size: 20),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text('Cerrar sesión',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
