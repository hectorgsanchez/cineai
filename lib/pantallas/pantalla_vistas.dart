// pantallas/pantalla_vistas.dart
// Lista de películas marcadas como vistas por el usuario.
// Permite eliminar con "Deshacer" de 4 segundos y navegar al detalle de cada una.

import 'package:flutter/material.dart';
import '../modelos/pelicula.dart';
import '../servicios/servicio_firebase.dart';
import '../componentes/tarjeta_pelicula.dart';
import 'pantalla_detalle.dart';

class PantallaVistas extends StatefulWidget {
  final ServicioFirebase servicioFirebase;

  const PantallaVistas({super.key, required this.servicioFirebase});

  @override
  State<PantallaVistas> createState() => _EstadoPantallaVistas();
}

class _EstadoPantallaVistas extends State<PantallaVistas> {
  List<Pelicula> _peliculasVistas = [];
  bool _estaCargando = true;

  @override
  void initState() {
    super.initState();
    _cargarVistas();
  }

  Future<void> _cargarVistas() async {
    final lista = await widget.servicioFirebase.obtenerVistas();
    if (mounted) {
      setState(() {
        _peliculasVistas = lista;
        _estaCargando = false;
      });
    }
  }

  void _quitarDeVistas(Pelicula pelicula) {
    final indice = _peliculasVistas
        .indexWhere((p) => p.identificador == pelicula.identificador);
    setState(() => _peliculasVistas.removeAt(indice));
    widget.servicioFirebase.quitarDeVistas(pelicula.identificador);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pelicula.titulo} eliminada de vistas'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: const Color(0xFF42A5F5),
          onPressed: () {
            setState(() => _peliculasVistas.insert(indice, pelicula));
            widget.servicioFirebase.marcarComoVista(pelicula);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.visibility_rounded, size: 20, color: Color(0xFF2E75B6)),
            SizedBox(width: 8),
            Text('Películas vistas'),
          ],
        ),
      ),
      body: _estaCargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarVistas,
              child: _peliculasVistas.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 200),
                  Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_off_outlined,
                          size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'Todavía no has marcado\nninguna película como vista',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Entra en el detalle de una película\ny pulsa "He visto esto"',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )),
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        '${_peliculasVistas.length} ${_peliculasVistas.length == 1 ? 'película vista' : 'películas vistas'}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _peliculasVistas.length,
                        itemBuilder: (context, i) {
                          final pelicula = _peliculasVistas[i];
                          return TarjetaPelicula(
                            pelicula: pelicula,
                            alPulsar: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PantallaDetalle(
                                  pelicula: pelicula,
                                  servicioFirebase: widget.servicioFirebase,
                                ),
                              ),
                            ).then((_) => _cargarVistas()),
                            alPulsarFavorito: () =>
                                _quitarDeVistas(pelicula),
                            iconoAccion: Icons.visibility_off_rounded,
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ),
    );
  }
}
