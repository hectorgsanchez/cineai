// pantallas/pantalla_mis_listas.dart
// Pantalla de gestión de listas personalizadas del usuario.
// Permite crear listas con nombre, emoji y color, editarlas y eliminarlas.
// Cada lista se almacena como un documento en Firestore con un array de películas.
// Al pulsar una lista se navega a PantallaListaPersonalizada para ver su contenido.

import 'package:flutter/material.dart';
import '../servicios/servicio_firebase.dart';
import 'pantalla_lista_personalizada.dart';

class PantallaMisListas extends StatefulWidget {
  final ServicioFirebase servicioFirebase;
  const PantallaMisListas({super.key, required this.servicioFirebase});

  @override
  State<PantallaMisListas> createState() => _EstadoPantallaMisListas();
}

class _EstadoPantallaMisListas extends State<PantallaMisListas>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _listas = [];
  bool _cargando = true;

  @override
  bool get wantKeepAlive => true;

  static const List<Map<String, dynamic>> _emojisDisponibles = [
    {'emoji': '🎬', 'label': 'Cine'},
    {'emoji': '🍿', 'label': 'Palomitas'},
    {'emoji': '❤️', 'label': 'Amor'},
    {'emoji': '😂', 'label': 'Comedia'},
    {'emoji': '😱', 'label': 'Terror'},
    {'emoji': '🚀', 'label': 'Sci-Fi'},
    {'emoji': '🌙', 'label': 'Noche'},
    {'emoji': '👨‍👩‍👧', 'label': 'Familia'},
    {'emoji': '🏆', 'label': 'Top'},
    {'emoji': '🎭', 'label': 'Drama'},
    {'emoji': '🔥', 'label': 'Fuego'},
    {'emoji': '⭐', 'label': 'Estrellas'},
  ];

  static const List<Map<String, dynamic>> _coloresDisponibles = [
    {'color': 0xFF2E75B6, 'label': 'Azul'},
    {'color': 0xFF9C27B0, 'label': 'Morado'},
    {'color': 0xFFE91E63, 'label': 'Rosa'},
    {'color': 0xFF4CAF50, 'label': 'Verde'},
    {'color': 0xFFFF9800, 'label': 'Naranja'},
    {'color': 0xFFE53935, 'label': 'Rojo'},
    {'color': 0xFF00BCD4, 'label': 'Cian'},
    {'color': 0xFFFFD700, 'label': 'Dorado'},
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final listas = await widget.servicioFirebase.obtenerListasPersonalizadas();
    if (mounted) setState(() { _listas = listas; _cargando = false; });
  }

  void _mostrarDialogoCrear() {
    final controlador = TextEditingController();
    String emojiSeleccionado = '🎬';
    int colorSeleccionado = 0xFF2E75B6;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Nueva lista',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Nombre
              TextField(
                controller: controlador,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ej: Pelis del finde, Para ver con Ana...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A2A3E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),

              const SizedBox(height: 20),
              const Text('Elige un emoji',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _emojisDisponibles.map((e) {
                  final sel = emojiSeleccionado == e['emoji'];
                  return GestureDetector(
                    onTap: () => setModal(
                        () => emojiSeleccionado = e['emoji'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: sel
                            ? Color(colorSeleccionado).withValues(alpha: 0.25)
                            : const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel
                              ? Color(colorSeleccionado)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(e['emoji'] as String,
                            style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Text('Color',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: _coloresDisponibles.map((c) {
                  final val = c['color'] as int;
                  final sel = colorSeleccionado == val;
                  return GestureDetector(
                    onTap: () =>
                        setModal(() => colorSeleccionado = val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Color(val),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: Color(val).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(colorSeleccionado),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final nombre = controlador.text.trim();
                    if (nombre.isEmpty) return;
                    Navigator.pop(context);
                    await widget.servicioFirebase.crearListaPersonalizada(
                      nombre: nombre,
                      color: colorSeleccionado,
                      emoji: emojiSeleccionado,
                    );
                    _cargar();
                  },
                  child: Text(
                    '$emojiSeleccionado  Crear lista',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarEliminar(Map<String, dynamic> lista) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar "${lista['nombre']}"',
            style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
            'Se eliminará la lista y todas las películas que contiene.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.servicioFirebase
                  .eliminarListaPersonalizada(lista['id'] as String);
              _cargar();
            },
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        automaticallyImplyLeading: false,
        title: const Text('Mis listas',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoCrear,
        backgroundColor: const Color(0xFF2E75B6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva lista',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E75B6)))
          : RefreshIndicator(
              onRefresh: _cargar,
              color: const Color(0xFF2E75B6),
              child: _listas.isEmpty
                  ? _vistaVacia()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: _listas.length,
                      itemBuilder: (context, i) {
                        final lista = _listas[i];
                        return _tarjetaLista(lista, i);
                      },
                    ),
            ),
    );
  }

  Widget _vistaVacia() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF2E75B6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.playlist_add_rounded,
                size: 40, color: Color(0xFF2E75B6)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Crea tu primera lista',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Organiza tus películas como quieras:\n"Para ver con María", "Top 10 Sci-Fi"...',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _mostrarDialogoCrear,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear lista'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E75B6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaLista(Map<String, dynamic> lista, int index) {
    final color = Color(lista['color'] as int? ?? 0xFF2E75B6);
    final emoji = lista['emoji'] as String? ?? '🎬';
    final nombre = lista['nombre'] as String? ?? 'Lista';
    final peliculas =
        List<Map<String, dynamic>>.from(lista['peliculas'] ?? []);

    return TweenAnimationBuilder<double>(
      key: ValueKey(lista['id']),
      duration: Duration(milliseconds: 200 + index * 60),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: const Color(0xFF161625),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, _) =>
                      PantallaListaPersonalizada(
                    listaId: lista['id'] as String,
                    nombre: nombre,
                    emoji: emoji,
                    color: lista['color'] as int? ?? 0xFF2E75B6,
                    servicioFirebase: widget.servicioFirebase,
                  ),
                  transitionsBuilder: (context, animation, _, child) =>
                      SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
              _cargar();
            },
            onLongPress: () => _confirmarEliminar(lista),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(
                          peliculas.isEmpty
                              ? 'Lista vacía · toca para añadir'
                              : '${peliculas.length} ${peliculas.length == 1 ? 'película' : 'películas'}',
                          style: TextStyle(
                              color: peliculas.isEmpty
                                  ? Colors.white24
                                  : Colors.white54,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // Mini-carteles de las primeras películas
                  if (peliculas.isNotEmpty)
                    SizedBox(
                      width: peliculas.take(3).length * 26.0 + 8,
                      height: 36,
                      child: Stack(
                        children: peliculas.take(3).toList().asMap().entries.map((e) {
                          final url = e.value['urlCartel'] as String? ?? '';
                          return Positioned(
                            left: e.key * 22.0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: url.isNotEmpty
                                  ? Image.network(
                                      url, width: 26, height: 36,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(
                                            width: 26, height: 36,
                                            color: const Color(0xFF2A2A3E),
                                          ),
                                    )
                                  : Container(
                                      width: 26, height: 36,
                                      color: const Color(0xFF2A2A3E),
                                    ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white24, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
