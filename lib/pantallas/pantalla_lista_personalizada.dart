// pantallas/pantalla_lista_personalizada.dart
// Muestra el contenido de una lista personalizada concreta.
// Permite eliminar películas de la lista (con Deshacer 4s) y
// navegar al detalle de cada una consultando TMDb para obtener los datos completos.
// Incluye opción de eliminar la lista completa con confirmación.

import 'package:flutter/material.dart';
import '../servicios/servicio_firebase.dart';
import '../modelos/pelicula.dart';
import '../servicios/servicio_tmdb.dart';
import 'pantalla_detalle.dart';

class PantallaListaPersonalizada extends StatefulWidget {
  final String listaId;
  final String nombre;
  final String emoji;
  final int color;
  final ServicioFirebase servicioFirebase;

  const PantallaListaPersonalizada({
    super.key,
    required this.listaId,
    required this.nombre,
    required this.emoji,
    required this.color,
    required this.servicioFirebase,
  });

  @override
  State<PantallaListaPersonalizada> createState() =>
      _EstadoPantallaListaPersonalizada();
}

class _EstadoPantallaListaPersonalizada
    extends State<PantallaListaPersonalizada> {
  final ServicioTMDb _tmdb = ServicioTMDb();
  List<Map<String, dynamic>> _peliculas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final lista = await widget.servicioFirebase
        .obtenerPeliculasDeListaPersonalizada(widget.listaId);
    if (mounted) setState(() { _peliculas = lista; _cargando = false; });
  }

  Future<void> _quitarPelicula(int id, String titulo) async {
    final indice = _peliculas.indexWhere((p) => p['identificador'] == id);
    setState(() => _peliculas.removeAt(indice));
    await widget.servicioFirebase.quitarPeliculaDeLista(widget.listaId, id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$titulo eliminada de la lista'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: const Color(0xFF42A5F5),
          onPressed: () async {
            await widget.servicioFirebase
                .agregarPeliculaALista(widget.listaId,
                    Pelicula(
                      identificador: id,
                      titulo: titulo,
                      descripcion: '',
                      urlCartel: '',
                      puntuacion: 0,
                      fechaEstreno: '',
                      generos: [],
                    ));
            _cargar();
          },
        ),
      ),
    );
  }

  Future<void> _abrirDetalle(Map<String, dynamic> datos) async {
    final id = datos['identificador'] as int?;
    if (id == null) return;
    final pelicula = await _tmdb.obtenerDetallePelicula(id);
    if (!mounted || pelicula == null) return;
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

  @override
  Widget build(BuildContext context) {
    final colorLista = Color(widget.color);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        title: Row(
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            tooltip: 'Eliminar lista',
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1C1C2E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text('Eliminar "${widget.nombre}"',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17)),
                  content: const Text(
                      'Se eliminará la lista y todas las películas que contiene.',
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Eliminar',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
              if (confirmar == true && mounted) {
                await widget.servicioFirebase
                    .eliminarListaPersonalizada(widget.listaId);
                // ignore: use_build_context_synchronously
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E75B6)))
          : _peliculas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.emoji,
                          style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                      const Text(
                        'Esta lista está vacía',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 17),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Añade películas desde\nel detalle de cada película',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  color: colorLista,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          '${_peliculas.length} ${_peliculas.length == 1 ? 'película' : 'películas'}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: _peliculas.length,
                          itemBuilder: (context, i) {
                            final p = _peliculas[i];
                            final id = p['identificador'] as int? ?? 0;
                            final titulo = p['titulo'] as String? ?? '';
                            final urlCartel = p['urlCartel'] as String? ?? '';
                            final puntuacion =
                                (p['puntuacion'] as num?)?.toDouble() ?? 0.0;
                            final ano = (p['fechaEstreno'] as String?)
                                    ?.substring(0, 4) ??
                                '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: const Color(0xFF161625),
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: () => _abrirDetalle(p),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: urlCartel.isNotEmpty
                                              ? Image.network(
                                                  urlCartel,
                                                  width: 50,
                                                  height: 72,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _cartelVacio(),
                                                )
                                              : _cartelVacio(),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(titulo,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  if (puntuacion > 0) ...[
                                                    const Icon(
                                                        Icons.star_rounded,
                                                        size: 13,
                                                        color: Color(0xFFFFD700)),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      puntuacion
                                                          .toStringAsFixed(1),
                                                      style: const TextStyle(
                                                          color:
                                                              Color(0xFFFFD700),
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  if (ano.isNotEmpty)
                                                    Text(ano,
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white38,
                                                            fontSize: 12)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.remove_circle_outline_rounded,
                                              color: Colors.white24,
                                              size: 20),
                                          onPressed: () =>
                                              _quitarPelicula(id, titulo),
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
                    ],
                  ),
                ),
    );
  }

  Widget _cartelVacio() => Container(
        width: 50,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.movie_rounded,
            color: Color(0xFF2E75B6), size: 22),
      );
}
