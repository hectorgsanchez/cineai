// pantallas/pantalla_detalle.dart
// Pantalla de detalle de una película. Muestra cartel, sinopsis, géneros,
// director, reparto y duración cargados desde TMDb via append_to_response=credits.
//
// Funcionalidades sociales integradas:
//   - Marcar como favorita, vista o pendiente (con Deshacer 4s)
//   - Valorar de 1 a 5 estrellas (actualiza también el ranking comunitario global)
//   - Escribir y guardar una reseña de texto libre
//   - Añadir la película a una lista personalizada (selector en BottomSheet)
//   - Ver la media comunitaria de votos en tiempo real
//
// Los estados de favorita, vista y pendientes se leen de la caché local del
// ServicioFirebase para evitar parpadeos al abrir la pantalla.

import 'package:flutter/material.dart';
import '../modelos/pelicula.dart';
import '../servicios/servicio_firebase.dart';
import '../servicios/servicio_tmdb.dart';

class PantallaDetalle extends StatefulWidget {
  final Pelicula pelicula;
  final ServicioFirebase servicioFirebase;

  const PantallaDetalle({
    super.key,
    required this.pelicula,
    required this.servicioFirebase,
  });

  @override
  State<PantallaDetalle> createState() => _EstadoPantallaDetalle();
}

class _EstadoPantallaDetalle extends State<PantallaDetalle> {
  final ServicioTMDb _servicioTMDb = ServicioTMDb();
  late Pelicula _pelicula;
  late bool _guardadaComoFavorita;
  late bool _vistaPorUsuario;
  late bool _enPendientes;
  late int _puntuacionUsuario; // 0 = sin puntuar, 1-5 estrellas
  bool _cargandoDetalles = true;
  double _mediaComunitaria = 0.0;
  int _totalVotos = 0;
  final TextEditingController _controladorResena = TextEditingController();
  bool _guardandoResena = false;

  @override
  void initState() {
    super.initState();
    _pelicula = widget.pelicula;
    _guardadaComoFavorita = widget.servicioFirebase.estaGuardadaComoFavorita(_pelicula.identificador);
    _vistaPorUsuario =
        widget.servicioFirebase.estaVista(_pelicula.identificador);
    _enPendientes =
        widget.servicioFirebase.estaEnPendientes(_pelicula.identificador);
    _puntuacionUsuario =
        widget.servicioFirebase.obtenerValoracion(_pelicula.identificador);
    _cargarDetallesCompletos();
    _cargarRankingYResena();
  }

  Future<void> _cargarRankingYResena() async {
    final ranking = await widget.servicioFirebase
        .obtenerRankingComunitario(_pelicula.identificador);
    final resena = await widget.servicioFirebase
        .obtenerResena(_pelicula.identificador);
    if (mounted) {
      setState(() {
        _mediaComunitaria = (ranking['media'] as double?) ?? 0.0;
        _totalVotos = (ranking['totalVotos'] as int?) ?? 0;
        _controladorResena.text = resena;
      });
    }
  }

  Future<void> _guardarResena() async {
    setState(() => _guardandoResena = true);
    await widget.servicioFirebase
        .guardarResena(_pelicula, _controladorResena.text);
    setState(() => _guardandoResena = false);
    _snack('Reseña guardada');
  }

  Future<void> _cargarDetallesCompletos() async {
    final detalle =
        await _servicioTMDb.obtenerDetallePelicula(_pelicula.identificador);
    if (detalle != null && mounted) {
      setState(() {
        _pelicula = Pelicula(
          identificador: detalle.identificador,
          titulo: detalle.titulo,
          descripcion: detalle.descripcion,
          urlCartel: detalle.urlCartel.isNotEmpty
              ? detalle.urlCartel
              : _pelicula.urlCartel,
          puntuacion: detalle.puntuacion,
          fechaEstreno: detalle.fechaEstreno,
          generos: detalle.generos.isNotEmpty
              ? detalle.generos
              : _pelicula.generos,
          duracion: detalle.duracion,
          reparto: detalle.reparto,
          director: detalle.director,
          guardadaComoFavorita: _guardadaComoFavorita,
        );
        _cargandoDetalles = false;
      });
    } else if (mounted) {
      setState(() => _cargandoDetalles = false);
    }
  }

  // ── Favoritas ────────────────────────────────────────────────────────
  void _cambiarEstadoFavorita() {
    setState(() {
      _guardadaComoFavorita = !_guardadaComoFavorita;
      _pelicula.guardadaComoFavorita = _guardadaComoFavorita;
    });
    if (_guardadaComoFavorita) {
      widget.servicioFirebase.guardarComoFavorita(_pelicula);
    } else {
      widget.servicioFirebase.eliminarDeFavoritas(_pelicula.identificador);
    }
    if (_guardadaComoFavorita) {
      _snack('${_pelicula.titulo} añadida a favoritas');
    } else {
      _snack('Eliminada de favoritas', onDeshacer: () {
        setState(() {
          _guardadaComoFavorita = true;
          _pelicula.guardadaComoFavorita = true;
        });
        widget.servicioFirebase.guardarComoFavorita(_pelicula);
      });
    }
  }

  // ── Vista ────────────────────────────────────────────────────────────
  void _cambiarEstadoVista() {
    setState(() => _vistaPorUsuario = !_vistaPorUsuario);
    if (_vistaPorUsuario) {
      widget.servicioFirebase.marcarComoVista(_pelicula);
    } else {
      widget.servicioFirebase.quitarDeVistas(_pelicula.identificador);
    }
    if (_vistaPorUsuario) {
      _snack('${_pelicula.titulo} marcada como vista');
    } else {
      _snack('Eliminada de vistas', onDeshacer: () {
        setState(() => _vistaPorUsuario = true);
        widget.servicioFirebase.marcarComoVista(_pelicula);
      });
    }
  }

  // ── Pendientes ───────────────────────────────────────────────────────
  void _cambiarEstadoPendiente() {
    setState(() => _enPendientes = !_enPendientes);
    if (_enPendientes) {
      widget.servicioFirebase.agregarAPendientes(_pelicula);
    } else {
      widget.servicioFirebase.quitarDePendientes(_pelicula.identificador);
    }
    if (_enPendientes) {
      _snack('${_pelicula.titulo} añadida a pendientes');
    } else {
      _snack('Eliminada de pendientes', onDeshacer: () {
        setState(() => _enPendientes = true);
        widget.servicioFirebase.agregarAPendientes(_pelicula);
      });
    }
  }

  // ── Valoración propia ────────────────────────────────────────────────
  @override
  void dispose() {
    _controladorResena.dispose();
    super.dispose();
  }

  void _guardarValoracion(int estrellas) {
    final nueva = _puntuacionUsuario == estrellas ? 0 : estrellas;
    setState(() => _puntuacionUsuario = nueva);
    if (nueva > 0) {
      widget.servicioFirebase.guardarValoracion(_pelicula, nueva);
    } else {
      widget.servicioFirebase.eliminarValoracion(_pelicula.identificador);
    }
  }

  Future<void> _mostrarSelectorListas(BuildContext ctx) async {
    final listas = await widget.servicioFirebase.obtenerListasPersonalizadas();
    if (!mounted) return;

    if (listas.isEmpty) {
      _snack('Primero crea una lista en "Mis listas"');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Añadir a lista',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...listas.map((lista) {
            final color = Color(lista['color'] as int? ?? 0xFF2E75B6);
            final emoji = lista['emoji'] as String? ?? '';
            final nombre = lista['nombre'] as String? ?? 'Lista';
            return ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 22))),
              ),
              title: Text(nombre,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.add_rounded, color: Colors.white38),
              onTap: () async {
                Navigator.pop(ctx);
                await widget.servicioFirebase
                    .agregarPeliculaALista(lista['id'] as String, _pelicula);
                _snack('Añadida a "$nombre"');
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _snack(String texto, {VoidCallback? onDeshacer}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: Duration(seconds: onDeshacer != null ? 4 : 2),
        action: onDeshacer != null
            ? SnackBarAction(
                label: 'Deshacer',
                textColor: const Color(0xFF42A5F5),
                onPressed: onDeshacer,
              )
            : null,
      ),
    );
  }

  String _formatearDuracion(int minutos) {
    if (minutos <= 0) return '';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  String _textoValoracion(int v) {
    const textos = ['', 'Muy mala', 'Mala', 'Regular', 'Buena', 'Excelente'];
    return v >= 1 && v <= 5 ? textos[v] : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Cabecera expandible con cartel
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  _guardadaComoFavorita
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: _guardadaComoFavorita ? Colors.red : Colors.white,
                ),
                onPressed: _cambiarEstadoFavorita,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _pelicula.titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
              background: _pelicula.urlCartel.isNotEmpty
                  ? Image.network(
                      _pelicula.urlCartel.replaceAll('/w500', '/w780'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fondoGradiente(),
                    )
                  : _fondoGradiente(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Puntuación TMDb + año + duración
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: Color(0xFFFFD700), size: 20),
                      const SizedBox(width: 4),
                      Text(
                        _pelicula.puntuacion.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_pelicula.fechaEstreno.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            _pelicula.fechaEstreno.substring(0, 4),
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ]),
                      const SizedBox(width: 16),
                      if (!_cargandoDetalles && _pelicula.duracion > 0)
                        Row(children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            _formatearDuracion(_pelicula.duracion),
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ]),
                      if (_cargandoDetalles)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Mi valoración (1-5 estrellas) ──────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C2E),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_half_rounded,
                                size: 16, color: Color(0xFFFFD700)),
                            const SizedBox(width: 6),
                            const Text(
                              'Mi valoración',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            if (_puntuacionUsuario > 0) ...[
                              const SizedBox(width: 10),
                              Text(
                                _textoValoracion(_puntuacionUsuario),
                                style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(5, (i) {
                            final e = i + 1;
                            return GestureDetector(
                              onTap: () => _guardarValoracion(e),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  child: Icon(
                                    e <= _puntuacionUsuario
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    key: ValueKey(
                                        '$e-$_puntuacionUsuario'),
                                    color: const Color(0xFFFFD700),
                                    size: 38,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Ranking comunitario ────────────────────────────
                  if (_totalVotos > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C2E),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_rounded,
                              size: 16, color: Color(0xFF2E75B6)),
                          const SizedBox(width: 8),
                          Text(
                            'Comunidad: $_mediaComunitaria/5',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '($_totalVotos ${_totalVotos == 1 ? 'voto' : 'votos'})',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                          const Spacer(),
                          Row(
                            children: List.generate(5, (i) => Icon(
                              i < _mediaComunitaria.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFF2E75B6),
                              size: 16,
                            )),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Géneros
                  if (_pelicula.generos.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _pelicula.generos
                          .map((g) => Chip(
                                label: Text(g,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white)),
                                backgroundColor: const Color(0xFF2E75B6),
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Director
                  if (!_cargandoDetalles &&
                      _pelicula.director.isNotEmpty) ...[
                    const Text('Dirección',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.movie_creation,
                          size: 18, color: Color(0xFF2E75B6)),
                      const SizedBox(width: 8),
                      Text(_pelicula.director,
                          style: const TextStyle(
                              fontSize: 15, color: Colors.white70)),
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // Sinopsis
                  const Text('Sinopsis',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    _pelicula.descripcion.isNotEmpty
                        ? _pelicula.descripcion
                        : 'Sin descripción disponible.',
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        height: 1.6),
                  ),
                  const SizedBox(height: 20),

                  // Reparto
                  if (!_cargandoDetalles &&
                      _pelicula.reparto.isNotEmpty) ...[
                    const Text('Reparto principal',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pelicula.reparto
                          .map((a) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A3E),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFF2E75B6),
                                      width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person,
                                        size: 14,
                                        color: Color(0xFF2E75B6)),
                                    const SizedBox(width: 4),
                                    Text(a,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white70)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Mi reseña ───────────────────────────────────────
                  const Text('Mi reseña',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controladorResena,
                    maxLines: 4,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Escribe tu opinión sobre esta película...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1C1C2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _guardandoResena ? null : _guardarResena,
                      icon: _guardandoResena
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Guardar reseña'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E75B6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Botones Vista y Pendiente ───────────────────────
                  Row(children: [
                    Expanded(
                        child: _botonLista(
                      icono: _vistaPorUsuario
                          ? Icons.visibility_rounded
                          : Icons.visibility_outlined,
                      etiqueta:
                          _vistaPorUsuario ? 'Vista' : 'He visto esto',
                      activo: _vistaPorUsuario,
                      color: Colors.green.shade700,
                      onTap: _cambiarEstadoVista,
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _botonLista(
                      icono: _enPendientes
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      etiqueta:
                          _enPendientes ? 'En mi lista' : 'Quiero verla',
                      activo: _enPendientes,
                      color: const Color(0xFF7B1FA2),
                      onTap: _cambiarEstadoPendiente,
                    )),
                  ]),

                  const SizedBox(height: 10),

                  // Botón favoritas
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _cambiarEstadoFavorita,
                      icon: Icon(_guardadaComoFavorita
                          ? Icons.favorite
                          : Icons.favorite_border),
                      label: Text(_guardadaComoFavorita
                          ? 'Eliminar de favoritas'
                          : 'Guardar en favoritas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _guardadaComoFavorita
                            ? Colors.red.shade800
                            : const Color(0xFF2E75B6),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Botón añadir a lista personalizada
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _mostrarSelectorListas(context),
                      icon: const Icon(Icons.playlist_add_rounded,
                          size: 20),
                      label: const Text('Añadir a una lista'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonLista({
    required IconData icono,
    required String etiqueta,
    required bool activo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: activo ? color : const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: activo ? color : Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(etiqueta,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _fondoGradiente() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E75B6), Color(0xFF121212)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie, size: 80, color: Colors.white24),
      ),
    );
  }
}
