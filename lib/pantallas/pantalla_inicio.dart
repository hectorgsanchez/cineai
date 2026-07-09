// pantallas/pantalla_inicio.dart
// Pantalla principal de la app. Muestra:
//   - Saludo personalizado con el nombre del usuario y la hora del día
//   - Banner deslizante automático con las 7 películas en tendencia (PageView, 4s)
//   - Sección "Recomendadas para ti": basada en las favoritas del usuario via /recommendations
//   - Sección "Tendencias hoy": scroll horizontal con las películas del día
//   - Sección "Más populares": dos páginas aleatorias mezcladas para variar cada sesión
//   - Barra de búsqueda y filtros avanzados (género, año, puntuación) via /discover

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelos/pelicula.dart';
import '../servicios/servicio_tmdb.dart';
import '../servicios/servicio_firebase.dart';
import '../servicios/servicio_notificaciones.dart';
import '../componentes/tarjeta_pelicula.dart';
import 'pantalla_detalle.dart';

// AutomaticKeepAliveClientMixin conserva el estado cuando el IndexedStack
// cambia de tab, evitando recargar las peticiones de red al volver a Inicio.
class PantallaInicio extends StatefulWidget {
  final ServicioFirebase servicioFirebase;
  const PantallaInicio({super.key, required this.servicioFirebase});

  @override
  State<PantallaInicio> createState() => _EstadoPantallaInicio();
}

class _EstadoPantallaInicio extends State<PantallaInicio>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ServicioTMDb _tmdb = ServicioTMDb();
  final TextEditingController _controladorBusqueda = TextEditingController();

  List<Pelicula> _banner = [];
  List<Pelicula> _tendencias = [];
  List<Pelicula> _recomendadas = [];
  List<Pelicula> _populares = [];
  List<Pelicula> _popularesConFiltro = [];
  List<Pelicula> _resultadosBusqueda = [];

  bool _cargando = true;
  bool _cargandoFiltro = false;
  bool _estaBuscando = false;
  String _mensajeError = '';

  double _filtroCalificacion = 0.0;
  int _filtroAno = 0;
  final Set<String> _filtroGeneros = {};

  // Timers de refresco automático en segundo plano
  Timer? _timerPopulares;
  Timer? _timerTendencias;

  bool get _hayFiltros =>
      _filtroCalificacion > 0 || _filtroAno > 0 || _filtroGeneros.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
    // Rota "Más populares" cada 5 minutos con páginas aleatorias distintas
    _timerPopulares = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && !_estaBuscando && !_hayFiltros) _refrescarPopulares();
    });
    // Refresca el banner, tendencias y recomendaciones cada 10 minutos
    _timerTendencias = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted && !_estaBuscando) _refrescarTendenciasYRecomendadas();
    });
  }

  @override
  void dispose() {
    _timerPopulares?.cancel();
    _timerTendencias?.cancel();
    _controladorBusqueda.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() { _cargando = true; _mensajeError = ''; });
    try {
      await widget.servicioFirebase.inicializar();

      final resultados = await Future.wait([
        _tmdb.obtenerTendencias(),
        _tmdb.obtenerPopularesAleatorios(),
      ]);

      final tendencias = resultados[0];
      final populares = resultados[1];

      // Recomendadas: basadas en favoritas del usuario
      final favoritas = await widget.servicioFirebase.obtenerFavoritas();
      List<Pelicula> recomendadas = [];
      if (favoritas.isNotEmpty) {
        final semilla = favoritas[Random().nextInt(favoritas.length)];
        recomendadas = await _tmdb.obtenerRecomendaciones(semilla.identificador);
        // Excluir lo que ya tiene en favoritas
        final idsFavoritas = favoritas.map((f) => f.identificador).toSet();
        recomendadas = recomendadas
            .where((p) => !idsFavoritas.contains(p.identificador))
            .toList();
      }
      // Fallback: si no hay favoritas o no hay recomendaciones, usar trending aleatorio
      if (recomendadas.isEmpty) {
        recomendadas = List.from(tendencias)..shuffle(Random());
      }

      // Marcar favoritas en todas las listas
      for (final lista in [tendencias, populares, recomendadas]) {
        for (final p in lista) {
          p.guardadaComoFavorita =
              widget.servicioFirebase.estaGuardadaComoFavorita(p.identificador);
        }
      }

      if (mounted) {
        setState(() {
          _banner = tendencias.take(7).toList();
          _tendencias = tendencias;
          _recomendadas = recomendadas.take(15).toList();
          _populares = populares;
          _cargando = false;
        });

        // Notificación de tendencia al abrir la app (primera carga)
        if (tendencias.isNotEmpty) {
          Future.delayed(const Duration(seconds: 3), () {
            ServicioNotificaciones()
                .notificarTendencia(tendencias.first.titulo);
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _mensajeError = 'Error al cargar. Desliza para reintentar.';
          _cargando = false;
        });
      }
    }
  }

  // Sustituye "Más populares" con nuevas páginas aleatorias sin tocar el resto.
  Future<void> _refrescarPopulares() async {
    final nuevos = await _tmdb.obtenerPopularesAleatorios();
    for (final p in nuevos) {
      p.guardadaComoFavorita =
          widget.servicioFirebase.estaGuardadaComoFavorita(p.identificador);
    }
    if (mounted) setState(() => _populares = nuevos);
  }

  // Refresca el banner de tendencias y las recomendaciones personalizadas.
  Future<void> _refrescarTendenciasYRecomendadas() async {
    final tendencias = await _tmdb.obtenerTendencias();
    final favoritas = await widget.servicioFirebase.obtenerFavoritas();
    List<Pelicula> recomendadas = [];
    if (favoritas.isNotEmpty) {
      final semilla = favoritas[Random().nextInt(favoritas.length)];
      recomendadas = await _tmdb.obtenerRecomendaciones(semilla.identificador);
      final idsFavoritas = favoritas.map((f) => f.identificador).toSet();
      recomendadas = recomendadas
          .where((p) => !idsFavoritas.contains(p.identificador))
          .toList();
    }
    if (recomendadas.isEmpty) {
      recomendadas = List.from(tendencias)..shuffle(Random());
    }
    for (final lista in [tendencias, recomendadas]) {
      for (final p in lista) {
        p.guardadaComoFavorita =
            widget.servicioFirebase.estaGuardadaComoFavorita(p.identificador);
      }
    }
    if (mounted) {
      setState(() {
        _banner = tendencias.take(7).toList();
        _tendencias = tendencias;
        _recomendadas = recomendadas.take(15).toList();
      });
    }
  }

  Future<void> _buscarPeliculas(String texto) async {
    if (texto.trim().isEmpty) {
      setState(() { _estaBuscando = false; _resultadosBusqueda = []; });
      return;
    }
    setState(() => _estaBuscando = true);
    final resultados = await _tmdb.buscarPeliculas(texto);
    for (final p in resultados) {
      p.guardadaComoFavorita =
          widget.servicioFirebase.estaGuardadaComoFavorita(p.identificador);
    }
    if (mounted) setState(() => _resultadosBusqueda = resultados);
  }

  void _toggleFavorita(Pelicula pelicula) {
    setState(() {
      if (pelicula.guardadaComoFavorita) {
        widget.servicioFirebase.eliminarDeFavoritas(pelicula.identificador);
        pelicula.guardadaComoFavorita = false;
      } else {
        widget.servicioFirebase.guardarComoFavorita(pelicula);
        pelicula.guardadaComoFavorita = true;
      }
    });
  }

  void _irADetalle(Pelicula pelicula) {
    Navigator.push(
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
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  Future<void> _aplicarFiltrosAPI() async {
    setState(() => _cargandoFiltro = true);
    final resultados = await _tmdb.descubrirPeliculas(
      generos: Set.from(_filtroGeneros),
      anioDesde: _filtroAno,
      puntuacionMinima: _filtroCalificacion,
    );
    for (final p in resultados) {
      p.guardadaComoFavorita =
          widget.servicioFirebase.estaGuardadaComoFavorita(p.identificador);
    }
    if (mounted) {
      setState(() {
        _popularesConFiltro = resultados;
        _cargandoFiltro = false;
      });
    }
  }

  String _saludo() {
    final hora = DateTime.now().hour;
    if (hora < 6) return 'Buenas noches';
    if (hora < 13) return 'Buenos días';
    if (hora < 21) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: _cargando
          ? const _PantallaCargaInicio()
          : RefreshIndicator(
              onRefresh: _cargarTodo,
              color: const Color(0xFF2E75B6),
              child: _estaBuscando
                  ? _vistaResultadosBusqueda()
                  : _vistaInicio(),
            ),
    );
  }

  Widget _vistaInicio() {
    final usuario = FirebaseAuth.instance.currentUser;
    final nombre = usuario?.displayName?.isNotEmpty == true
        ? usuario!.displayName!.split(' ').first
        : 'cinéfilo';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // AppBar
        SliverAppBar(
          backgroundColor: const Color(0xFF0D0D14),
          floating: true,
          snap: true,
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.movie_rounded, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 9),
              const Text('CineAI',
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Filtros',
              icon: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.tune_rounded, color: Colors.white60),
                if (_hayFiltros)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E75B6), shape: BoxShape.circle),
                    ),
                  ),
              ]),
              onPressed: _mostrarFiltros,
            ),
          ],
        ),

        // Barra de búsqueda
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _controladorBusqueda,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar películas, directores...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                suffixIcon: _controladorBusqueda.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38),
                        onPressed: () {
                          _controladorBusqueda.clear();
                          setState(() { _estaBuscando = false; _resultadosBusqueda = []; });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1C1C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (v) {
                setState(() {});
                _buscarPeliculas(v);
              },
            ),
          ),
        ),

        // Saludo personalizado
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.userChanges(),
              builder: (context, snap) {
                final n = snap.data?.displayName?.isNotEmpty == true
                    ? snap.data!.displayName!.split(' ').first
                    : nombre;
                return RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontFamily: 'Nunito', fontSize: 22, height: 1.2),
                    children: [
                      TextSpan(
                        text: '${_saludo()},\n',
                        style: const TextStyle(
                            color: Colors.white60, fontWeight: FontWeight.w400),
                      ),
                      TextSpan(
                        text: n,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 26),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Banner destacado (tendencias hoy)
        if (_banner.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _BannerTendencias(
                peliculas: _banner,
                alPulsar: _irADetalle,
              ),
            ),
          ),

        // Sección: Recomendadas para ti
        if (_recomendadas.isNotEmpty) ...[
          _cabeceraSeccion(
            icono: Icons.auto_awesome_rounded,
            color: const Color(0xFF42A5F5),
            titulo: 'Recomendadas para ti',
            subtitulo: 'Basadas en tus favoritas',
          ),
          SliverToBoxAdapter(
            child: _SeccionHorizontal(
              peliculas: _recomendadas,
              alPulsar: _irADetalle,
              alPulsarFavorito: _toggleFavorita,
            ),
          ),
        ],

        // Sección: Tendencias hoy
        if (_tendencias.isNotEmpty) ...[
          _cabeceraSeccion(
            icono: Icons.local_fire_department_rounded,
            color: Colors.orangeAccent,
            titulo: 'Tendencias hoy',
            subtitulo: 'Lo más visto del día',
          ),
          SliverToBoxAdapter(
            child: _SeccionHorizontal(
              peliculas: _tendencias.skip(7).take(12).toList(),
              alPulsar: _irADetalle,
              alPulsarFavorito: _toggleFavorita,
            ),
          ),
        ],

        // Sección: Más populares (lista vertical)
        _cabeceraSeccion(
          icono: Icons.star_rounded,
          color: const Color(0xFFFFD700),
          titulo: 'Más populares',
          subtitulo: 'Actualizado constantemente',
        ),

        if (_mensajeError.isNotEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(_mensajeError,
                  style: const TextStyle(color: Colors.white38)),
            ),
          )
        else if (_cargandoFiltro)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2E75B6),
                strokeWidth: 2,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: Builder(builder: (context) {
              final peliculas = _hayFiltros ? _popularesConFiltro : _populares;
              if (peliculas.isEmpty && _hayFiltros) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.movie_filter_rounded,
                            size: 52, color: Colors.white24),
                        SizedBox(height: 12),
                        Text('Sin resultados para estos filtros',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i >= peliculas.length) return null;
                    final p = peliculas[i];
                    return TweenAnimationBuilder<double>(
                      key: ValueKey(p.identificador),
                      duration:
                          Duration(milliseconds: 250 + (i < 8 ? i * 40 : 0)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - v)),
                          child: child,
                        ),
                      ),
                      child: TarjetaPelicula(
                        pelicula: p,
                        alPulsar: () => _irADetalle(p),
                        alPulsarFavorito: () => _toggleFavorita(p),
                      ),
                    );
                  },
                  childCount: peliculas.length,
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _vistaResultadosBusqueda() {
    final peliculas = _resultadosBusqueda;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF0D0D14),
          floating: true,
          snap: true,
          elevation: 0,
          title: TextField(
            controller: _controladorBusqueda,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar películas...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white38),
                onPressed: () {
                  _controladorBusqueda.clear();
                  setState(() { _estaBuscando = false; _resultadosBusqueda = []; });
                },
              ),
              filled: true,
              fillColor: const Color(0xFF1C1C2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (v) {
              setState(() {});
              _buscarPeliculas(v);
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: peliculas.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 56, color: Colors.white24),
                        SizedBox(height: 12),
                        Text('Sin resultados',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final p = peliculas[i];
                      return TarjetaPelicula(
                        pelicula: p,
                        alPulsar: () => _irADetalle(p),
                        alPulsarFavorito: () => _toggleFavorita(p),
                      );
                    },
                    childCount: peliculas.length,
                  ),
                ),
        ),
      ],
    );
  }

  SliverToBoxAdapter _cabeceraSeccion({
    required IconData icono,
    required Color color,
    required String titulo,
    required String subtitulo,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                Text(subtitulo,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFiltros() {
    double tempCalificacion = _filtroCalificacion;
    int tempAno = _filtroAno;
    final tempGeneros = Set<String>.from(_filtroGeneros);

    const generos = [
      'Acción', 'Aventura', 'Comedia', 'Drama',
      'Terror', 'Ciencia ficción', 'Animación',
      'Romance', 'Thriller', 'Crimen',
    ];
    const anos = [
      {'etiqueta': 'Todos', 'valor': 0},
      {'etiqueta': 'Desde 2020', 'valor': 2020},
      {'etiqueta': 'Desde 2015', 'valor': 2015},
      {'etiqueta': 'Desde 2010', 'valor': 2010},
      {'etiqueta': 'Desde 2000', 'valor': 2000},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filtros',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  TextButton(
                    onPressed: () {
                      setModal(() {
                        tempCalificacion = 0;
                        tempAno = 0;
                        tempGeneros.clear();
                      });
                      setState(() {
                        _filtroCalificacion = 0;
                        _filtroAno = 0;
                        _filtroGeneros.clear();
                        _popularesConFiltro = [];
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Limpiar',
                        style: TextStyle(color: Color(0xFF2E75B6))),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Puntuación mínima',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tempCalificacion == 0
                          ? 'Todas'
                          : tempCalificacion.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFF2E75B6),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF2E75B6),
                  overlayColor: const Color(0xFF2E75B6).withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: tempCalificacion,
                  min: 0, max: 9.0, divisions: 18,
                  onChanged: (v) => setModal(() => tempCalificacion = v),
                ),
              ),
              const SizedBox(height: 4),
              const Text('Año de estreno',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: anos.map((item) {
                  final val = item['valor'] as int;
                  final sel = tempAno == val;
                  return GestureDetector(
                    onTap: () => setModal(() => tempAno = val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF2E75B6)
                            : const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFF2E75B6)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(item['etiqueta'] as String,
                          style: TextStyle(
                              color: sel ? Colors.white : Colors.white54,
                              fontSize: 13,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Géneros',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: generos.map((g) {
                  final sel = tempGeneros.contains(g);
                  return GestureDetector(
                    onTap: () => setModal(() =>
                        sel ? tempGeneros.remove(g) : tempGeneros.add(g)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF2E75B6)
                            : const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFF2E75B6)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(g,
                          style: TextStyle(
                              color: sel ? Colors.white : Colors.white54,
                              fontSize: 13,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
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
                    backgroundColor: const Color(0xFF2E75B6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    setState(() {
                      _filtroCalificacion = tempCalificacion;
                      _filtroAno = tempAno;
                      _filtroGeneros..clear()..addAll(tempGeneros);
                    });
                    Navigator.pop(context);
                    if (_hayFiltros) _aplicarFiltrosAPI();
                  },
                  child: const Text('Aplicar filtros',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ── Banner deslizante de tendencias ───────────────────────────────────────────

class _BannerTendencias extends StatefulWidget {
  final List<Pelicula> peliculas;
  final void Function(Pelicula) alPulsar;
  const _BannerTendencias({required this.peliculas, required this.alPulsar});

  @override
  State<_BannerTendencias> createState() => _EstadoBannerTendencias();
}

class _EstadoBannerTendencias extends State<_BannerTendencias> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _pagina = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final sig = (_pagina + 1) % widget.peliculas.length;
      _pageController.animateToPage(
        sig,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.peliculas.length,
            onPageChanged: (i) => setState(() => _pagina = i),
            itemBuilder: (context, i) {
              final p = widget.peliculas[i];
              return AnimatedScale(
                scale: _pagina == i ? 1.0 : 0.95,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  onTap: () => widget.alPulsar(p),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          p.urlCartel.isNotEmpty
                              ? Image.network(
                                  p.urlCartel.replaceAll('/w500', '/w780'),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: const Color(0xFF1C1C2E)),
                                )
                              : Container(color: const Color(0xFF1C1C2E)),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.92),
                                ],
                                stops: const [0.4, 1.0],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department_rounded,
                                      size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Tendencia',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  p.titulo,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 14, color: Color(0xFFFFD700)),
                                    const SizedBox(width: 4),
                                    Text(
                                      p.puntuacion.toStringAsFixed(1),
                                      style: const TextStyle(
                                          color: Color(0xFFFFD700),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (p.fechaEstreno.length >= 4) ...[
                                      const SizedBox(width: 10),
                                      Text(
                                        p.fechaEstreno.substring(0, 4),
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 13),
                                      ),
                                    ],
                                    if (p.generos.isNotEmpty) ...[
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          p.generos.first,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ],
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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.peliculas.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _pagina == i ? 18 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: _pagina == i
                    ? const Color(0xFF2E75B6)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sección horizontal de tarjetas compactas ──────────────────────────────────

class _SeccionHorizontal extends StatelessWidget {
  final List<Pelicula> peliculas;
  final void Function(Pelicula) alPulsar;
  final void Function(Pelicula) alPulsarFavorito;

  const _SeccionHorizontal({
    required this.peliculas,
    required this.alPulsar,
    required this.alPulsarFavorito,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 195,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: peliculas.length,
        itemBuilder: (context, i) {
          final p = peliculas[i];
          return TweenAnimationBuilder<double>(
            key: ValueKey(p.identificador),
            duration: Duration(milliseconds: 300 + i * 50),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(20 * (1 - v), 0),
                child: child,
              ),
            ),
            child: GestureDetector(
              onTap: () => alPulsar(p),
              child: Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: p.urlCartel.isNotEmpty
                                ? Image.network(
                                    p.urlCartel,
                                    width: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF1C1C2E),
                                      child: const Icon(Icons.movie_rounded,
                                          color: Colors.white24, size: 36),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF1C1C2E),
                                    child: const Icon(Icons.movie_rounded,
                                        color: Colors.white24, size: 36),
                                  ),
                          ),
                          // Badge favorita
                          Positioned(
                            top: 6, right: 6,
                            child: GestureDetector(
                              onTap: () => alPulsarFavorito(p),
                              child: Container(
                                width: 28, height: 28,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  p.guardadaComoFavorita
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 15,
                                  color: p.guardadaComoFavorita
                                      ? Colors.redAccent
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          // Badge puntuación
                          Positioned(
                            bottom: 6, left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 10, color: Color(0xFFFFD700)),
                                  const SizedBox(width: 2),
                                  Text(
                                    p.puntuacion.toStringAsFixed(1),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.titulo,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Pantalla de carga animada ─────────────────────────────────────────────────

class _PantallaCargaInicio extends StatelessWidget {
  const _PantallaCargaInicio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF2E75B6),
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            'Preparando tu experiencia...',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
