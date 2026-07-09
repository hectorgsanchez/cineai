// pantallas/pantalla_favoritas.dart
// Lista de películas guardadas como favoritas por el usuario.
// Al eliminar una, se muestra un SnackBar con "Deshacer" durante 4 segundos
// que permite recuperar la película en Firestore si el usuario se arrepiente.

import 'package:flutter/material.dart';
import '../modelos/pelicula.dart';
import '../servicios/servicio_firebase.dart';
import '../componentes/tarjeta_pelicula.dart';
import 'pantalla_detalle.dart';

class PantallaFavoritas extends StatefulWidget {
  final ServicioFirebase servicioFirebase;

  const PantallaFavoritas({super.key, required this.servicioFirebase});

  @override
  State<PantallaFavoritas> createState() => _EstadoPantallaFavoritas();
}

class _EstadoPantallaFavoritas extends State<PantallaFavoritas> {
  List<Pelicula> _peliculasFavoritas = [];
  bool _estaCargando = true;

  @override
  void initState() {
    super.initState();
    _cargarFavoritas();
  }

  // Carga la lista de películas favoritas desde Firebase
  Future<void> _cargarFavoritas() async {
    final lista = await widget.servicioFirebase.obtenerFavoritas();
    setState(() {
      _peliculasFavoritas = lista;
      _estaCargando = false;
    });
  }

  // Elimina una película de la lista de favoritas
  void _eliminarDeFavoritas(Pelicula pelicula) {
    final indice = _peliculasFavoritas
        .indexWhere((p) => p.identificador == pelicula.identificador);
    setState(() => _peliculasFavoritas.removeAt(indice));
    widget.servicioFirebase.eliminarDeFavoritas(pelicula.identificador);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pelicula.titulo} eliminada de favoritas'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: const Color(0xFF42A5F5),
          onPressed: () {
            setState(() => _peliculasFavoritas.insert(indice, pelicula));
            widget.servicioFirebase.guardarComoFavorita(pelicula);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis favoritas'),
      ),
      body: _estaCargando
          ? const Center(child: CircularProgressIndicator())
          : _peliculasFavoritas.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 64,
                        color: Colors.white24,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Todavía no tienes películas favoritas',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pulsa el corazón en cualquier película para guardarla aquí',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _peliculasFavoritas.length,
                  itemBuilder: (context, indice) {
                    final pelicula = _peliculasFavoritas[indice];
                    return TarjetaPelicula(
                      pelicula: pelicula,
                      alPulsar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaDetalle(
                              pelicula: pelicula,
                              servicioFirebase: widget.servicioFirebase,
                            ),
                          ),
                        );
                      },
                      alPulsarFavorito: () =>
                          _eliminarDeFavoritas(pelicula),
                    );
                  },
                ),
    );
  }
}
