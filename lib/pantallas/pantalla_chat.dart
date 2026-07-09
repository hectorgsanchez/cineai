// pantallas/pantalla_chat.dart
// Pantalla de CineBot, el asistente de IA de CineAI.
//
// Flujo de una recomendación:
//   1. El usuario escribe un mensaje o pulsa un chip de sugerencia rápida.
//   2. Se envía el historial completo a ServicioOpenAI (GPT-4o-mini).
//   3. parsearRespuesta() separa el texto visible del bloque CINEAI_PELICULAS:[...].
//   4. Las películas del bloque JSON se buscan en TMDb en paralelo (Future.wait).
//   5. Se muestran como tarjetas horizontales clicables con cartel y botón "Ver película".
//   6. Se dispara una notificación heads-up con los títulos recomendados.
//
// El historial se mantiene en memoria durante la sesión para que GPT recuerde
// el contexto de la conversación y no repita recomendaciones.

import 'package:flutter/material.dart';
import '../servicios/servicio_openai.dart';
import '../servicios/servicio_tmdb.dart';
import '../servicios/servicio_firebase.dart';
import '../servicios/servicio_notificaciones.dart';
import '../modelos/pelicula.dart';
import 'pantalla_detalle.dart';

class PantallaChat extends StatefulWidget {
  final ServicioFirebase? servicioFirebase;
  const PantallaChat({super.key, this.servicioFirebase});

  @override
  State<PantallaChat> createState() => _EstadoPantallaChat();
}

class _EstadoPantallaChat extends State<PantallaChat> {
  final ServicioOpenAI _servicioIA = ServicioOpenAI();
  final ServicioTMDb _tmdb = ServicioTMDb();
  final TextEditingController _controladorTexto = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<MensajeConversacion> _historial = [];
  final List<_MensajeUI> _mensajes = [];
  bool _esperando = false;

  late final ServicioFirebase _servicioFirebase;

  @override
  void initState() {
    super.initState();
    _servicioFirebase = widget.servicioFirebase ?? ServicioFirebase();
    _mensajes.add(_MensajeUI(
      texto:
          'Hola, soy CineBot. Cuéntame qué te apetece ver hoy — un género, un estado de ánimo, una ocasión especial — y te recomiendo la película perfecta.',
      esDelUsuario: false,
    ));
  }

  Future<void> _enviar([String? textoForzado]) async {
    final texto = (textoForzado ?? _controladorTexto.text).trim();
    if (texto.isEmpty || _esperando) return;
    _controladorTexto.clear();

    _historial.add(MensajeConversacion(remitente: 'user', contenido: texto));
    setState(() {
      _mensajes.add(_MensajeUI(texto: texto, esDelUsuario: true));
      _esperando = true;
    });
    _irAlFinal();

    final raw = await _servicioIA.enviarMensaje(_historial);
    _historial.add(MensajeConversacion(remitente: 'assistant', contenido: raw));

    final (textoLimpio, datosPeliculas) = ServicioOpenAI.parsearRespuesta(raw);

    // Buscar cada película recomendada en TMDB en paralelo
    List<Pelicula> peliculasEncontradas = [];
    if (datosPeliculas.isNotEmpty) {
      final futures = datosPeliculas.map((d) {
        final titulo = d['titulo'] as String? ?? '';
        final anio = (d['anio'] as num?)?.toInt() ?? 0;
        return _tmdb.buscarPorTituloAnio(titulo, anio);
      });
      final resultados = await Future.wait(futures);
      peliculasEncontradas = resultados.whereType<Pelicula>().toList();
    }

    if (mounted) {
      setState(() {
        _mensajes.add(_MensajeUI(
          texto: textoLimpio,
          esDelUsuario: false,
          peliculas: peliculasEncontradas,
        ));
        _esperando = false;
      });
      _irAlFinal();

      // Notificación local cuando el bot recomienda películas
      if (peliculasEncontradas.isNotEmpty) {
        ServicioNotificaciones().notificarRecomendacionIA(
          peliculasEncontradas.map((p) => p.titulo).toList(),
        );
      }
    }
  }

  void _irAlFinal() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _limpiar() {
    setState(() {
      _historial.clear();
      _mensajes
        ..clear()
        ..add(_MensajeUI(
          texto: '¿Qué tipo de película buscas hoy?',
          esDelUsuario: false,
        ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            const Text('CineBot',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Limpiar conversación',
            onPressed: _limpiar,
          ),
        ],
      ),
      body: Column(
        children: [
          // Chips de sugerencias
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _chip('Para ver en familia'),
                _chip('Que haga pensar'),
                _chip('Para reírme'),
                _chip('Para pasar miedo'),
                _chip('Noche romántica'),
                _chip('Ciencia ficción'),
                _chip('Mucha acción'),
                _chip('Ganadora del Oscar'),
              ],
            ),
          ),

          // Lista de mensajes
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _mensajes.length + (_esperando ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _mensajes.length && _esperando) {
                  return const _IndicadorEscribiendo();
                }
                final msg = _mensajes[i];
                return _BurbujaMensaje(
                  mensaje: msg,
                  onVerPelicula: (p) => _irADetalle(p),
                );
              },
            ),
          ),

          // Campo de texto
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controladorTexto,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Describe qué película quieres ver...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1C1C2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: (_) => _enviar(),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _esperando ? null : _enviar,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: _esperando
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _esperando ? const Color(0xFF2A2A3E) : null,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _esperando ? Icons.hourglass_top_rounded : Icons.send_rounded,
                      color: _esperando ? Colors.white24 : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _irADetalle(Pelicula pelicula) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => PantallaDetalle(
          pelicula: pelicula,
          servicioFirebase: _servicioFirebase,
        ),
        transitionsBuilder: (context, animation, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _chip(String texto) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(texto,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
        backgroundColor: const Color(0xFF1C1C2E),
        side: const BorderSide(color: Color(0xFF2E75B6), width: 0.5),
        onPressed: () => _enviar(texto),
      ),
    );
  }

  @override
  void dispose() {
    _controladorTexto.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

// ── Modelo de mensaje UI ──────────────────────────────────────────────────────

class _MensajeUI {
  final String texto;
  final bool esDelUsuario;
  final List<Pelicula> peliculas;

  _MensajeUI({
    required this.texto,
    required this.esDelUsuario,
    this.peliculas = const [],
  });
}

// ── Burbuja de mensaje con tarjetas opcionales ────────────────────────────────

class _BurbujaMensaje extends StatelessWidget {
  final _MensajeUI mensaje;
  final void Function(Pelicula) onVerPelicula;

  const _BurbujaMensaje({
    required this.mensaje,
    required this.onVerPelicula,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: mensaje.esDelUsuario
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Burbuja de texto
          Align(
            alignment: mensaje.esDelUsuario
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              margin: EdgeInsets.only(
                left: mensaje.esDelUsuario ? 48 : 0,
                right: mensaje.esDelUsuario ? 0 : 48,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mensaje.esDelUsuario
                    ? const Color(0xFF2E75B6)
                    : const Color(0xFF1C1C2E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft:
                      Radius.circular(mensaje.esDelUsuario ? 18 : 4),
                  bottomRight:
                      Radius.circular(mensaje.esDelUsuario ? 4 : 18),
                ),
              ),
              child: Text(
                mensaje.texto,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.5),
              ),
            ),
          ),

          // Tarjetas de películas recomendadas
          if (mensaje.peliculas.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 230,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: mensaje.peliculas.length,
                itemBuilder: (context, i) {
                  final p = mensaje.peliculas[i];
                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 250 + i * 80),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                          offset: Offset(16 * (1 - v), 0), child: child),
                    ),
                    child: _TarjetaPeliculaChat(
                      pelicula: p,
                      onTap: () => onVerPelicula(p),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tarjeta compacta de película en el chat ───────────────────────────────────

class _TarjetaPeliculaChat extends StatelessWidget {
  final Pelicula pelicula;
  final VoidCallback onTap;

  const _TarjetaPeliculaChat({
    required this.pelicula,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161625),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF2E75B6).withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cartel
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: pelicula.urlCartel.isNotEmpty
                  ? Image.network(
                      pelicula.urlCartel,
                      height: 130,
                      width: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _cartelVacio(),
                    )
                  : _cartelVacio(),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pelicula.titulo,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 11, color: Color(0xFFFFD700)),
                        const SizedBox(width: 2),
                        Text(
                          pelicula.puntuacion.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Botón Ver película
                    Container(
                      width: double.infinity,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Ver película',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartelVacio() => Container(
        height: 130, width: 130,
        color: const Color(0xFF1C1C2E),
        child: const Icon(Icons.movie_rounded,
            color: Colors.white24, size: 36),
      );
}

// ── Indicador de escritura ────────────────────────────────────────────────────

class _IndicadorEscribiendo extends StatefulWidget {
  const _IndicadorEscribiendo();

  @override
  State<_IndicadorEscribiendo> createState() => _EstadoIndicadorEscribiendo();
}

class _EstadoIndicadorEscribiendo extends State<_IndicadorEscribiendo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Punto(controller: _controller, retraso: 0.0),
            const SizedBox(width: 4),
            _Punto(controller: _controller, retraso: 0.2),
            const SizedBox(width: 4),
            _Punto(controller: _controller, retraso: 0.4),
            const SizedBox(width: 10),
            const Text('CineBot está pensando...',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  final AnimationController controller;
  final double retraso;

  const _Punto({required this.controller, required this.retraso});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = ((controller.value - retraso) % 1.0);
        final escala = t < 0.3
            ? 1.0 + t / 0.3 * 0.5
            : t < 0.6
                ? 1.5 - (t - 0.3) / 0.3 * 0.5
                : 1.0;
        return Transform.scale(
          scale: escala,
          child: Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF2E75B6),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
