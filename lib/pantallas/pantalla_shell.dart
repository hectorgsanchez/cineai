// pantallas/pantalla_shell.dart
// Pantalla contenedora principal de la app autenticada.
// Implementa la navegación por las 5 secciones mediante una barra inferior personalizada.
//
// Decisión de diseño: IndexedStack mantiene vivos todos los widgets hijos
// aunque no estén visibles, preservando el scroll, los datos cargados y el estado
// de cada pantalla al cambiar de tab sin necesidad de recargas.
//
// El botón central de IA abre PantallaChat con animación slide-up + fade,
// separándola del stack para que siempre parta de un historial vacío.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../servicios/servicio_firebase.dart';
import 'pantalla_inicio.dart';
import 'pantalla_mis_listas.dart';
import 'pantalla_actividad.dart';
import 'pantalla_perfil.dart';
import 'pantalla_chat.dart';

class PantallaShell extends StatefulWidget {
  const PantallaShell({super.key});

  @override
  State<PantallaShell> createState() => _EstadoPantallaShell();
}

class _EstadoPantallaShell extends State<PantallaShell> {
  int _tabActual = 0;

  // Instancia única compartida entre todas las pantallas del stack.
  // Contiene la caché de IDs y la conexión a Firestore.
  final ServicioFirebase _servicioFirebase = ServicioFirebase();

  @override
  void initState() {
    super.initState();
    // Precarga los IDs de favoritas, vistas, pendientes y valoraciones en memoria.
    _servicioFirebase.inicializar();
  }

  // Permite que PantallaActividad navegue a otro tab (por ejemplo, al pulsar "Mis listas").
  void irATab(int index) => setState(() => _tabActual = index);

  // Abre CineBot como una pantalla modal con animación slide desde abajo.
  void _abrirIA(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => PantallaChat(
          servicioFirebase: _servicioFirebase,
        ),
        transitionsBuilder: (context, animation, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // userChanges() emite cuando cambia el displayName o el email,
    // lo que permite actualizar el saludo en PantallaInicio en tiempo real.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: const Color(0xFF0D0D14),
          body: IndexedStack(
            index: _tabActual,
            children: [
              PantallaInicio(servicioFirebase: _servicioFirebase),
              PantallaMisListas(servicioFirebase: _servicioFirebase),
              PantallaActividad(
                servicioFirebase: _servicioFirebase,
                alNavegar: irATab,
              ),
              PantallaPerfil(servicioFirebase: _servicioFirebase),
            ],
          ),
          bottomNavigationBar: _BarraNavegacion(
            tabActual: _tabActual,
            onTabSeleccionado: (i) => setState(() => _tabActual = i),
            onIA: () => _abrirIA(context),
          ),
        );
      },
    );
  }
}

// Barra de navegación inferior personalizada con 4 tabs y un botón central de IA.
// Se construye por separado para mantener el código de PantallaShell limpio.
class _BarraNavegacion extends StatelessWidget {
  final int tabActual;
  final void Function(int) onTabSeleccionado;
  final VoidCallback onIA;

  const _BarraNavegacion({
    required this.tabActual,
    required this.onTabSeleccionado,
    required this.onIA,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _itemNav(0, Icons.home_outlined, Icons.home_rounded, 'Inicio'),
              _itemNav(1, Icons.video_library_outlined, Icons.video_library_rounded, 'Mis listas'),

              // Botón central de IA con gradiente azul y efecto de brillo
              Expanded(
                child: GestureDetector(
                  onTap: onIA,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E75B6).withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'IA',
                        style: TextStyle(
                          color: Color(0xFF42A5F5),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _itemNav(2, Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Actividad'),
              _itemNav(3, Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  // Construye un item de navegación con icono animado y etiqueta.
  // AnimatedSwitcher hace la transición entre icono activo/inactivo.
  // AnimatedDefaultTextStyle anima el cambio de peso y color del texto.
  Widget _itemNav(int index, IconData icono, IconData iconoActivo, String etiqueta) {
    final activo = tabActual == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSeleccionado(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                activo ? iconoActivo : icono,
                key: ValueKey(activo),
                color: activo ? const Color(0xFF2E75B6) : Colors.white38,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: activo ? const Color(0xFF2E75B6) : Colors.white38,
                fontSize: 11,
                fontWeight: activo ? FontWeight.w700 : FontWeight.normal,
              ),
              child: Text(etiqueta),
            ),
          ],
        ),
      ),
    );
  }
}
