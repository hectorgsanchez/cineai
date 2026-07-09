// pantallas/pantalla_actividad.dart
// Pantalla de estadísticas y ranking comunitario.
// Muestra las estadísticas del usuario (contador de favoritas, vistas, etc.)
// y el top 10 de películas mejor valoradas por toda la comunidad.
//
// El ranking se obtiene de la colección global Firestore ranking/{movieId},
// donde cada documento contiene un mapa de votos {uid: puntuacion}.
// La media se calcula en cliente y se ordenan de mayor a menor.
// Cada entrada del ranking es clicable y navega a PantallaDetalle.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelos/pelicula.dart';
import '../servicios/servicio_firebase.dart';
import '../servicios/servicio_tmdb.dart';
import 'pantalla_favoritas.dart';
import 'pantalla_vistas.dart';
import 'pantalla_pendientes.dart';
import 'pantalla_valoraciones.dart';
import 'pantalla_resenas.dart';
import 'pantalla_detalle.dart';

class PantallaActividad extends StatefulWidget {
  final ServicioFirebase servicioFirebase;
  final void Function(int) alNavegar;

  const PantallaActividad({
    super.key,
    required this.servicioFirebase,
    required this.alNavegar,
  });

  @override
  State<PantallaActividad> createState() => _EstadoPantallaActividad();
}

class _EstadoPantallaActividad extends State<PantallaActividad>
    with AutomaticKeepAliveClientMixin {
  Map<String, int> _stats = {};
  List<_EntradaRanking> _ranking = [];
  bool _cargando = true;
  final ServicioTMDb _tmdb = ServicioTMDb();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final results = await Future.wait([
      widget.servicioFirebase.obtenerEstadisticas(),
      widget.servicioFirebase.obtenerTopRanking(limite: 10),
    ]);
    final stats = results[0] as Map<String, int>;
    final topRaw = results[1] as List<Map<String, dynamic>>;

    // Obtener detalles de cada película del ranking desde TMDb
    final entradas = <_EntradaRanking>[];
    await Future.wait(topRaw.map((e) async {
      final p = await _tmdb.obtenerDetallePelicula(e['movieId'] as int);
      if (p != null) {
        entradas.add(_EntradaRanking(
          pelicula: p,
          media: e['media'] as double,
          totalVotos: e['totalVotos'] as int,
        ));
      }
    }));
    entradas.sort((a, b) => b.media.compareTo(a.media));

    if (mounted) {
      setState(() {
        _stats = stats;
        _ranking = entradas;
        _cargando = false;
      });
    }
  }

  void _navegar(Widget pantalla) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => pantalla,
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
    super.build(context);
    final usuario = FirebaseAuth.instance.currentUser;
    final nombre = usuario?.displayName?.isNotEmpty == true
        ? usuario!.displayName!
        : 'Usuario';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        automaticallyImplyLeading: false,
        title: const Text(
          'Mi actividad',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E75B6)))
          : RefreshIndicator(
              onRefresh: _cargar,
              color: const Color(0xFF2E75B6),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  // Saludo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hola, $nombre',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Aquí tienes tu historial cinéfilo',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Resumen rápido
                  const Text(
                    'Resumen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _tarjetaResumen(
                          '${(_stats['favoritas'] ?? 0) + (_stats['vistas'] ?? 0) + (_stats['pendientes'] ?? 0)}',
                          'Películas\nen listas',
                          Icons.movie_rounded,
                          const Color(0xFF2E75B6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _tarjetaResumen(
                          '${(_stats['valoraciones'] ?? 0) + (_stats['resenas'] ?? 0)}',
                          'Opiniones\nregistradas',
                          Icons.edit_rounded,
                          const Color(0xFFFFD700),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Ranking comunitario
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: Color(0xFFFFD700), size: 17),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ranking comunitario',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700)),
                            Text('Mejor valoradas por los usuarios',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_ranking.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161625),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.how_to_vote_rounded,
                                size: 40, color: Colors.white24),
                            SizedBox(height: 10),
                            Text('Aún no hay valoraciones',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 14)),
                            SizedBox(height: 4),
                            Text('Valora películas para aparecer aquí',
                                style: TextStyle(
                                    color: Colors.white24, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_ranking.length, (i) {
                      final e = _ranking[i];
                      final medallas = ['1°', '2°', '3°'];
                      final pos = i < 3 ? medallas[i] : '${i + 1}';
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, _) =>
                                PantallaDetalle(
                              pelicula: e.pelicula,
                              servicioFirebase: widget.servicioFirebase,
                            ),
                            transitionsBuilder:
                                (context, animation, _, child) =>
                                    SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic)),
                              child: child,
                            ),
                            transitionDuration:
                                const Duration(milliseconds: 300),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: i < 3
                                ? const Color(0xFFFFD700).withValues(alpha: 0.07)
                                : const Color(0xFF161625),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: i < 3
                                  ? const Color(0xFFFFD700).withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(pos,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: i < 3 ? 20 : 14,
                                        color: i < 3
                                            ? Colors.white
                                            : Colors.white38,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: e.pelicula.urlCartel.isNotEmpty
                                    ? Image.network(
                                        e.pelicula.urlCartel,
                                        width: 38,
                                        height: 54,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          width: 38,
                                          height: 54,
                                          color: const Color(0xFF1C1C2E),
                                        ),
                                      )
                                    : Container(
                                        width: 38,
                                        height: 54,
                                        color: const Color(0xFF1C1C2E),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.pelicula.titulo,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      e.pelicula.fechaEstreno.length >= 4
                                          ? e.pelicula.fechaEstreno
                                              .substring(0, 4)
                                          : '',
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 14,
                                          color: Color(0xFFFFD700)),
                                      const SizedBox(width: 3),
                                      Text(
                                        e.media.toStringAsFixed(1),
                                        style: const TextStyle(
                                            color: Color(0xFFFFD700),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${e.totalVotos} voto${e.totalVotos == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  const Text(
                    'Tus listas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _tarjetaActividad(
                    icono: Icons.favorite_rounded,
                    color: Colors.redAccent,
                    titulo: 'Favoritas',
                    subtitulo: 'Tus películas imprescindibles',
                    cantidad: _stats['favoritas'] ?? 0,
                    onTap: () => _navegar(PantallaFavoritas(
                        servicioFirebase: widget.servicioFirebase)),
                  ),
                  _tarjetaActividad(
                    icono: Icons.visibility_rounded,
                    color: const Color(0xFF4CAF50),
                    titulo: 'Películas vistas',
                    subtitulo: 'Todo lo que has visto',
                    cantidad: _stats['vistas'] ?? 0,
                    onTap: () => _navegar(PantallaVistas(
                        servicioFirebase: widget.servicioFirebase)),
                  ),
                  _tarjetaActividad(
                    icono: Icons.bookmark_rounded,
                    color: const Color(0xFF9C27B0),
                    titulo: 'Quiero ver',
                    subtitulo: 'Tu lista de pendientes',
                    cantidad: _stats['pendientes'] ?? 0,
                    onTap: () => _navegar(PantallaPendientes(
                        servicioFirebase: widget.servicioFirebase)),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Tus opiniones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _tarjetaActividad(
                    icono: Icons.star_rounded,
                    color: const Color(0xFFFFD700),
                    titulo: 'Mis valoraciones',
                    subtitulo: 'Películas que has puntuado',
                    cantidad: _stats['valoraciones'] ?? 0,
                    onTap: () => _navegar(PantallaValoraciones(
                        servicioFirebase: widget.servicioFirebase)),
                  ),
                  _tarjetaActividad(
                    icono: Icons.rate_review_rounded,
                    color: const Color(0xFF2E75B6),
                    titulo: 'Mis reseñas',
                    subtitulo: 'Tus opiniones escritas',
                    cantidad: _stats['resenas'] ?? 0,
                    onTap: () => _navegar(PantallaResenas(
                        servicioFirebase: widget.servicioFirebase)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tarjetaResumen(
      String valor, String etiqueta, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161625),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            etiqueta,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaActividad({
    required IconData icono,
    required Color color,
    required String titulo,
    required String subtitulo,
    required int cantidad,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF161625),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitulo,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$cantidad',
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white24, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntradaRanking {
  final Pelicula pelicula;
  final double media;
  final int totalVotos;
  const _EntradaRanking({
    required this.pelicula,
    required this.media,
    required this.totalVotos,
  });
}
