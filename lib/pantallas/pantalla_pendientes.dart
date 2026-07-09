// pantallas/pantalla_pendientes.dart
// Watchlist del usuario: películas pendientes de ver.
// Permite eliminar con "Deshacer" de 4 segundos y navegar al detalle de cada una.

import 'package:flutter/material.dart';
import '../modelos/pelicula.dart';
import '../servicios/servicio_firebase.dart';
import '../componentes/tarjeta_pelicula.dart';
import 'pantalla_detalle.dart';

class PantallaPendientes extends StatefulWidget {
  final ServicioFirebase servicioFirebase;

  const PantallaPendientes({super.key, required this.servicioFirebase});

  @override
  State<PantallaPendientes> createState() => _EstadoPantallaPendientes();
}

class _EstadoPantallaPendientes extends State<PantallaPendientes> {
  List<Pelicula> _peliculasPendientes = [];
  bool _estaCargando = true;

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    final lista = await widget.servicioFirebase.obtenerPendientes();
    if (mounted) {
      setState(() {
        _peliculasPendientes = lista;
        _estaCargando = false;
      });
    }
  }

  void _quitarDePendientes(Pelicula pelicula) {
    final indice = _peliculasPendientes
        .indexWhere((p) => p.identificador == pelicula.identificador);
    setState(() => _peliculasPendientes.removeAt(indice));
    widget.servicioFirebase.quitarDePendientes(pelicula.identificador);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pelicula.titulo} eliminada de pendientes'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: const Color(0xFF42A5F5),
          onPressed: () {
            setState(() => _peliculasPendientes.insert(indice, pelicula));
            widget.servicioFirebase.agregarAPendientes(pelicula);
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
            Icon(Icons.bookmark_rounded, size: 20, color: Color(0xFF2E75B6)),
            SizedBox(width: 8),
            Text('Quiero ver'),
          ],
        ),
      ),
      body: _estaCargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarPendientes,
              child: _peliculasPendientes.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 200),
                  Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border_rounded,
                          size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'Tu lista de pendientes está vacía',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Entra en el detalle de una película\ny pulsa "Quiero verla"',
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
                        '${_peliculasPendientes.length} ${_peliculasPendientes.length == 1 ? 'película pendiente' : 'películas pendientes'}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _peliculasPendientes.length,
                        itemBuilder: (context, i) {
                          final pelicula = _peliculasPendientes[i];
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
                            ).then((_) => _cargarPendientes()),
                            alPulsarFavorito: () =>
                                _quitarDePendientes(pelicula),
                            iconoAccion: Icons.bookmark_remove_rounded,
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
