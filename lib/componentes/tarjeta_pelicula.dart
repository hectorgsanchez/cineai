// componentes/tarjeta_pelicula.dart
// Tarjeta reutilizable que representa una película en formato fila (cartel + info).
// Se usa en favoritas, vistas, pendientes, valoraciones, reseñas y resultados de búsqueda.
//
// Incluye una animación de escala al pulsar (efecto "press") implementada con
// AnimationController para dar feedback táctil sin librerías externas.
// El botón de acción (corazón por defecto) admite un icono personalizado
// para que la misma tarjeta sirva en pantallas con acciones distintas.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../modelos/pelicula.dart';

class TarjetaPelicula extends StatefulWidget {
  final Pelicula pelicula;
  final VoidCallback alPulsar;
  final VoidCallback? alPulsarFavorito;
  // Icono personalizado para el botón de acción secundario.
  // Si es null se usa el corazón (favorita/no favorita) por defecto.
  final IconData? iconoAccion;

  const TarjetaPelicula({
    super.key,
    required this.pelicula,
    required this.alPulsar,
    this.alPulsarFavorito,
    this.iconoAccion,
  });

  @override
  State<TarjetaPelicula> createState() => _EstadoTarjetaPelicula();
}

class _EstadoTarjetaPelicula extends State<TarjetaPelicula>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _escala;

  @override
  void initState() {
    super.initState();
    // Animación de escala: comprime la tarjeta a 0.96 al tocar y la suelta al soltar.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _escala = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.alPulsar();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _escala,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161625),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _construirCartel(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pelicula.titulo,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            _construirBadgePuntuacion(),
                            const SizedBox(width: 8),
                            // Muestra solo el año (primeros 4 caracteres de "YYYY-MM-DD")
                            if (widget.pelicula.fechaEstreno.isNotEmpty)
                              Text(
                                widget.pelicula.fechaEstreno.substring(0, 4),
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: Colors.white38,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.pelicula.descripcion,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Botón de acción: solo se muestra si el padre lo proporciona
                        if (widget.alPulsarFavorito != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: widget.alPulsarFavorito,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                        scale: animation, child: child),
                                child: Icon(
                                  // Icono personalizado o corazón según el estado de favorita
                                  widget.iconoAccion ??
                                      (widget.pelicula.guardadaComoFavorita
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded),
                                  key: ValueKey(widget.iconoAccion ??
                                      widget.pelicula.guardadaComoFavorita),
                                  size: 22,
                                  color: widget.iconoAccion != null
                                      ? Colors.white38
                                      : (widget.pelicula.guardadaComoFavorita
                                          ? Colors.redAccent
                                          : Colors.white24),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Badge dorado con la puntuación de TMDb (estrella + número con un decimal).
  Widget _construirBadgePuntuacion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFD700)),
          const SizedBox(width: 3),
          Text(
            widget.pelicula.puntuacion.toStringAsFixed(1),
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: const Color(0xFFFFD700),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // Carga el cartel desde la URL de TMDb. Si falla o no hay URL, muestra un placeholder.
  Widget _construirCartel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: widget.pelicula.urlCartel.isNotEmpty
          ? Image.network(
              widget.pelicula.urlCartel,
              width: 75,
              height: 112,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _imagenSustituta(),
            )
          : _imagenSustituta(),
    );
  }

  // Placeholder mostrado cuando no hay cartel disponible.
  Widget _imagenSustituta() {
    return Container(
      width: 75,
      height: 112,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.movie_rounded, color: Color(0xFF2E75B6), size: 32),
    );
  }
}
