// pantallas/pantalla_valoraciones.dart
// Lista de todas las películas que el usuario ha valorado (1-5 estrellas),
// ordenadas de mayor a menor puntuación.
// Cada entrada es clicable: obtiene los detalles de la película en TMDb
// y navega a PantallaDetalle.

import 'package:flutter/material.dart';
import '../servicios/servicio_firebase.dart';
import '../servicios/servicio_tmdb.dart';
import 'pantalla_detalle.dart';

class PantallaValoraciones extends StatefulWidget {
  final ServicioFirebase servicioFirebase;
  const PantallaValoraciones({super.key, required this.servicioFirebase});

  @override
  State<PantallaValoraciones> createState() => _EstadoPantallaValoraciones();
}

class _EstadoPantallaValoraciones extends State<PantallaValoraciones> {
  final ServicioTMDb _servicioTMDb = ServicioTMDb();
  List<Map<String, dynamic>> _valoraciones = [];
  bool _cargando = true;
  final Set<int> _cargandoNavegacion = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await widget.servicioFirebase.obtenerListaValoraciones();
    if (mounted) setState(() { _valoraciones = lista; _cargando = false; });
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
          Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 20),
          SizedBox(width: 8),
          Text('Mis valoraciones'),
        ]),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _valoraciones.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 200),
                      Center(child: Column(children: [
                        Icon(Icons.star_outline_rounded, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('Todavía no has valorado ninguna película',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                            textAlign: TextAlign.center),
                        SizedBox(height: 8),
                        Text('Entra en el detalle de una película\ny puntúala con estrellas',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                            textAlign: TextAlign.center),
                      ])),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _valoraciones.length,
                      itemBuilder: (context, i) {
                        final v = _valoraciones[i];
                        final puntuacion = (v['puntuacion'] as int?) ?? 0;
                        final id = v['identificador'] as int?;
                        final cargando = id != null && _cargandoNavegacion.contains(id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: const Color(0xFF161625),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: cargando ? null : () => _abrirDetalle(v),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: v['urlCartel'] != null &&
                                              (v['urlCartel'] as String).isNotEmpty
                                          ? Image.network(
                                              v['urlCartel'] as String,
                                              width: 48,
                                              height: 70,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => _cartelVacio(),
                                            )
                                          : _cartelVacio(),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            v['titulo'] as String? ?? '',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: List.generate(
                                              5,
                                              (s) => Icon(
                                                s < puntuacion
                                                    ? Icons.star_rounded
                                                    : Icons.star_outline_rounded,
                                                color: const Color(0xFFFFD700),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (cargando)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFFFD700),
                                        ),
                                      )
                                    else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$puntuacion/5',
                                          style: const TextStyle(
                                              color: Color(0xFFFFD700),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.chevron_right_rounded,
                                          color: Colors.white24, size: 18),
                                    ],
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
        width: 48,
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.movie_rounded, color: Color(0xFF2E75B6), size: 20),
      );
}
