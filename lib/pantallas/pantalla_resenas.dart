// pantallas/pantalla_resenas.dart
// Lista de todas las reseñas de texto escritas por el usuario.
// Cada entrada muestra el cartel, el título y un extracto del texto.
// Al pulsar, consulta TMDb y navega a PantallaDetalle para ver o editar la reseña.

import 'package:flutter/material.dart';
import '../servicios/servicio_firebase.dart';
import '../servicios/servicio_tmdb.dart';
import 'pantalla_detalle.dart';

class PantallaResenas extends StatefulWidget {
  final ServicioFirebase servicioFirebase;
  const PantallaResenas({super.key, required this.servicioFirebase});

  @override
  State<PantallaResenas> createState() => _EstadoPantallaResenas();
}

class _EstadoPantallaResenas extends State<PantallaResenas> {
  final ServicioTMDb _servicioTMDb = ServicioTMDb();
  List<Map<String, dynamic>> _resenas = [];
  bool _cargando = true;
  final Set<int> _cargandoNavegacion = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await widget.servicioFirebase.obtenerListaResenas();
    if (mounted) setState(() { _resenas = lista; _cargando = false; });
  }

  Future<void> _abrirDetalle(Map<String, dynamic> item) async {
    final id = item['identificador'] as int?;
    if (id == null) return;
    setState(() => _cargandoNavegacion.add(id));
    try {
      final pelicula = await _servicioTMDb.obtenerDetallePelicula(id);
      if (!mounted) return;
      if (pelicula != null) {
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, _) => PantallaDetalle(
              pelicula: pelicula,
              servicioFirebase: widget.servicioFirebase,
            ),
            transitionsBuilder: (context, animation, _, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        _cargar();
      }
    } finally {
      if (mounted) setState(() => _cargandoNavegacion.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.rate_review_rounded, color: Color(0xFF2E75B6), size: 20),
          SizedBox(width: 8),
          Text('Mis reseñas'),
        ]),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _resenas.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 200),
                      Center(child: Column(children: [
                        Icon(Icons.rate_review_outlined, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('Todavía no has escrito ninguna reseña',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                            textAlign: TextAlign.center),
                        SizedBox(height: 8),
                        Text('Entra en el detalle de una película\ny escribe tu opinión',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                            textAlign: TextAlign.center),
                      ])),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _resenas.length,
                      itemBuilder: (context, i) {
                        final r = _resenas[i];
                        final id = r['identificador'] as int?;
                        final cargando = id != null && _cargandoNavegacion.contains(id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: const Color(0xFF161625),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: cargando ? null : () => _abrirDetalle(r),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: r['urlCartel'] != null &&
                                              (r['urlCartel'] as String).isNotEmpty
                                          ? Image.network(
                                              r['urlCartel'] as String,
                                              width: 56,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => _cartelVacio(),
                                            )
                                          : _cartelVacio(),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  r['titulo'] as String? ?? '',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (cargando)
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFF2E75B6),
                                                  ),
                                                )
                                              else
                                                const Icon(Icons.chevron_right_rounded,
                                                    color: Colors.white24, size: 18),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            r['texto'] as String? ?? '',
                                            style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 13,
                                                height: 1.5),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _cartelVacio() => Container(
        width: 56,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.movie_rounded, color: Color(0xFF2E75B6), size: 24),
      );
}
