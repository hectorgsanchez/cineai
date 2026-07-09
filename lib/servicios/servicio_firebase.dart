// servicios/servicio_firebase.dart
// Capa de acceso a datos sobre Cloud Firestore.
// Gestiona favoritas, vistas, pendientes, valoraciones, reseñas,
// listas personalizadas, ranking comunitario y estadísticas del perfil.
//
// Estructura de Firestore:
//   usuarios/{uid}/favoritas/{movieId}
//   usuarios/{uid}/vistas/{movieId}
//   usuarios/{uid}/pendientes/{movieId}
//   usuarios/{uid}/valoraciones/{movieId}
//   usuarios/{uid}/resenas/{movieId}
//   usuarios/{uid}/listas_personalizadas/{listaId}
//   ranking/{movieId}   <- colección global compartida entre todos los usuarios

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelos/pelicula.dart';

class ServicioFirebase {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Caché local en memoria para consultas síncronas O(1).
  // Se carga una sola vez en inicializar() y se actualiza en cada operación
  // de escritura, evitando rondas de red en cada render de tarjeta.
  final Set<int> _idsFavoritas = {};
  final Set<int> _idsVistas = {};
  final Set<int> _idsPendientes = {};
  final Map<int, int> _valoraciones = {}; // movieId -> puntuacion (1-5)

  String? get _uid => _auth.currentUser?.uid;

  // Devuelve la referencia a una subcolección del usuario autenticado.
  // Retorna null si no hay sesión activa para evitar escrituras anónimas.
  CollectionReference<Map<String, dynamic>>? _coleccion(String nombre) {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('usuarios').doc(uid).collection(nombre);
  }

  // Precarga todos los IDs en memoria al iniciar la app.
  // Se llama desde PantallaShell.initState() para que las tarjetas
  // muestren el estado correcto sin esperar a Firestore en cada build.
  Future<void> inicializar() async {
    if (_uid == null) return;
    await Future.wait([
      _cargarIds('favoritas', _idsFavoritas),
      _cargarIds('vistas', _idsVistas),
      _cargarIds('pendientes', _idsPendientes),
      _cargarValoraciones(),
    ]);
  }

  // Lee todos los documentos de una colección y guarda sus IDs en el Set local.
  Future<void> _cargarIds(String coleccion, Set<int> conjunto) async {
    final col = _coleccion(coleccion);
    if (col == null) return;
    try {
      final docs = await col.get();
      conjunto.clear();
      for (final doc in docs.docs) {
        final id = int.tryParse(doc.id);
        if (id != null) conjunto.add(id);
      }
    } catch (_) {}
  }

  // Precarga el mapa de valoraciones propias (movieId -> puntuacion).
  Future<void> _cargarValoraciones() async {
    final col = _coleccion('valoraciones');
    if (col == null) return;
    try {
      final docs = await col.get();
      _valoraciones.clear();
      for (final doc in docs.docs) {
        final id = int.tryParse(doc.id);
        final puntuacion = doc.data()['puntuacion'] as int?;
        if (id != null && puntuacion != null) {
          _valoraciones[id] = puntuacion;
        }
      }
    } catch (_) {}
  }

  // Consultas síncronas sobre la caché local (sin red).
  bool estaGuardadaComoFavorita(int id) => _idsFavoritas.contains(id);
  bool estaVista(int id) => _idsVistas.contains(id);
  bool estaEnPendientes(int id) => _idsPendientes.contains(id);
  int obtenerValoracion(int id) => _valoraciones[id] ?? 0;

  // ── FAVORITAS ────────────────────────────────────────────────────────

  Future<List<Pelicula>> obtenerFavoritas() async {
    final col = _coleccion('favoritas');
    if (col == null) return [];
    try {
      final docs = await col.get();
      return docs.docs
          .map((d) => Pelicula.desdeFirebase(d.data()))
          .toList()
        ..sort((a, b) => a.titulo.compareTo(b.titulo));
    } catch (_) {
      return [];
    }
  }

  // Actualiza la caché y persiste en Firestore. El campo guardadaComoFavorita
  // se cambia directamente en el objeto para que la UI refleje el cambio inmediatamente.
  Future<void> guardarComoFavorita(Pelicula pelicula) async {
    final col = _coleccion('favoritas');
    if (col == null) return;
    _idsFavoritas.add(pelicula.identificador);
    pelicula.guardadaComoFavorita = true;
    try {
      await col
          .doc(pelicula.identificador.toString())
          .set(pelicula.aMapaFirebase());
    } catch (_) {}
  }

  Future<void> eliminarDeFavoritas(int id) async {
    final col = _coleccion('favoritas');
    if (col == null) return;
    _idsFavoritas.remove(id);
    try {
      await col.doc(id.toString()).delete();
    } catch (_) {}
  }

  // ── VISTAS ───────────────────────────────────────────────────────────

  Future<List<Pelicula>> obtenerVistas() async {
    final col = _coleccion('vistas');
    if (col == null) return [];
    try {
      final docs = await col.get();
      return docs.docs
          .map((d) => Pelicula.desdeFirebase(d.data()))
          .toList()
        ..sort((a, b) => a.titulo.compareTo(b.titulo));
    } catch (_) {
      return [];
    }
  }

  Future<void> marcarComoVista(Pelicula pelicula) async {
    final col = _coleccion('vistas');
    if (col == null) return;
    _idsVistas.add(pelicula.identificador);
    try {
      await col
          .doc(pelicula.identificador.toString())
          .set(pelicula.aMapaFirebase());
    } catch (_) {}
  }

  Future<void> quitarDeVistas(int id) async {
    final col = _coleccion('vistas');
    if (col == null) return;
    _idsVistas.remove(id);
    try {
      await col.doc(id.toString()).delete();
    } catch (_) {}
  }

  // ── PENDIENTES ───────────────────────────────────────────────────────

  Future<List<Pelicula>> obtenerPendientes() async {
    final col = _coleccion('pendientes');
    if (col == null) return [];
    try {
      final docs = await col.get();
      return docs.docs
          .map((d) => Pelicula.desdeFirebase(d.data()))
          .toList()
        ..sort((a, b) => a.titulo.compareTo(b.titulo));
    } catch (_) {
      return [];
    }
  }

  Future<void> agregarAPendientes(Pelicula pelicula) async {
    final col = _coleccion('pendientes');
    if (col == null) return;
    _idsPendientes.add(pelicula.identificador);
    try {
      await col
          .doc(pelicula.identificador.toString())
          .set(pelicula.aMapaFirebase());
    } catch (_) {}
  }

  Future<void> quitarDePendientes(int id) async {
    final col = _coleccion('pendientes');
    if (col == null) return;
    _idsPendientes.remove(id);
    try {
      await col.doc(id.toString()).delete();
    } catch (_) {}
  }

  // ── VALORACIONES PERSONALES (1-5 estrellas) ──────────────────────────

  // Guarda la valoración del usuario y actualiza el ranking comunitario global.
  // Si el usuario vuelve a pulsar la misma nota, se interpreta como "quitar valoración"
  // (eso lo gestiona PantallaDetalle antes de llamar aquí).
  Future<void> guardarValoracion(Pelicula pelicula, int puntuacion) async {
    final col = _coleccion('valoraciones');
    if (col == null) return;
    _valoraciones[pelicula.identificador] = puntuacion;
    try {
      await col.doc(pelicula.identificador.toString()).set({
        'identificador': pelicula.identificador,
        'titulo': pelicula.titulo,
        'urlCartel': pelicula.urlCartel,
        'puntuacion': puntuacion,
        'fechaValoracion': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    await _actualizarRankingComunitario(pelicula.identificador, puntuacion);
  }

  Future<void> eliminarValoracion(int id) async {
    final col = _coleccion('valoraciones');
    if (col == null) return;
    _valoraciones.remove(id);
    try {
      await col.doc(id.toString()).delete();
    } catch (_) {}
    await _eliminarDelRankingComunitario(id);
  }

  // ── RANKING COMUNITARIO ───────────────────────────────────────────────
  // El documento ranking/{movieId} tiene la estructura:
  //   { votos: { uid1: 4, uid2: 5, uid3: 3, ... } }
  // Cada usuario solo tiene un voto por película. La media se calcula en cliente.

  // Usa merge:true para no sobreescribir los votos de otros usuarios.
  Future<void> _actualizarRankingComunitario(int movieId, int puntuacion) async {
    if (_uid == null) return;
    try {
      await _db.collection('ranking').doc(movieId.toString()).set({
        'votos': {_uid!: puntuacion},
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // FieldValue.delete() elimina solo el campo del uid actual dentro del mapa de votos.
  Future<void> _eliminarDelRankingComunitario(int movieId) async {
    if (_uid == null) return;
    try {
      await _db.collection('ranking').doc(movieId.toString()).update({
        'votos.$_uid': FieldValue.delete(),
      });
    } catch (_) {}
  }

  // Devuelve la media comunitaria y el número de votos para una película concreta.
  Future<Map<String, dynamic>> obtenerRankingComunitario(int movieId) async {
    try {
      final doc = await _db
          .collection('ranking')
          .doc(movieId.toString())
          .get();
      if (!doc.exists) return {'media': 0.0, 'totalVotos': 0};
      final votos = Map<String, dynamic>.from(
          doc.data()?['votos'] as Map? ?? {});
      if (votos.isEmpty) return {'media': 0.0, 'totalVotos': 0};
      final valores =
          votos.values.map((v) => (v as num).toDouble()).toList();
      final media =
          valores.reduce((a, b) => a + b) / valores.length;
      return {
        'media': double.parse(media.toStringAsFixed(1)),
        'totalVotos': valores.length,
      };
    } catch (_) {
      return {'media': 0.0, 'totalVotos': 0};
    }
  }

  // Lee toda la colección global de ranking, calcula la media de cada película
  // y devuelve las [limite] mejores ordenadas de mayor a menor nota.
  Future<List<Map<String, dynamic>>> obtenerTopRanking({int limite = 10}) async {
    try {
      final snap = await _db.collection('ranking').get();
      final lista = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final votos = Map<String, dynamic>.from(
            doc.data()['votos'] as Map? ?? {});
        if (votos.isEmpty) continue;
        final valores = votos.values.map((v) => (v as num).toDouble()).toList();
        final media = valores.reduce((a, b) => a + b) / valores.length;
        lista.add({
          'movieId': int.tryParse(doc.id) ?? 0,
          'media': double.parse(media.toStringAsFixed(1)),
          'totalVotos': valores.length,
        });
      }
      lista.sort((a, b) =>
          (b['media'] as double).compareTo(a['media'] as double));
      return lista.take(limite).toList();
    } catch (_) {
      return [];
    }
  }

  // ── RESEÑAS DE TEXTO ─────────────────────────────────────────────────

  // Devuelve el texto de la reseña del usuario para una película, o '' si no existe.
  Future<String> obtenerResena(int movieId) async {
    final col = _coleccion('resenas');
    if (col == null) return '';
    try {
      final doc = await col.doc(movieId.toString()).get();
      return doc.data()?['texto'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  // Si el texto está vacío, elimina el documento. Si no, lo crea o sobreescribe.
  Future<void> guardarResena(Pelicula pelicula, String texto) async {
    final col = _coleccion('resenas');
    if (col == null) return;
    try {
      if (texto.trim().isEmpty) {
        await col.doc(pelicula.identificador.toString()).delete();
      } else {
        await col.doc(pelicula.identificador.toString()).set({
          'identificador': pelicula.identificador,
          'titulo': pelicula.titulo,
          'urlCartel': pelicula.urlCartel,
          'texto': texto.trim(),
          'fecha': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  // ── LISTAS PERSONALIZADAS ─────────────────────────────────────────────
  // Cada lista es un documento con un array embebido 'peliculas'.
  // Se usa arrayUnion para añadir y una reescritura del array para eliminar,
  // ya que Firestore no permite eliminar elementos específicos de un array por índice.

  Future<List<Map<String, dynamic>>> obtenerListasPersonalizadas() async {
    final col = _coleccion('listas_personalizadas');
    if (col == null) return [];
    try {
      final docs = await col.orderBy('fechaCreacion', descending: false).get();
      return docs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) { return []; }
  }

  Future<String> crearListaPersonalizada({
    required String nombre,
    required int color,
    required String emoji,
  }) async {
    final col = _coleccion('listas_personalizadas');
    if (col == null) return '';
    try {
      final doc = await col.add({
        'nombre': nombre,
        'color': color,
        'emoji': emoji,
        'peliculas': [],
        'fechaCreacion': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (_) { return ''; }
  }

  Future<void> eliminarListaPersonalizada(String listaId) async {
    final col = _coleccion('listas_personalizadas');
    if (col == null) return;
    try { await col.doc(listaId).delete(); } catch (_) {}
  }

  Future<void> renombrarLista(String listaId, String nuevoNombre) async {
    final col = _coleccion('listas_personalizadas');
    if (col == null) return;
    try { await col.doc(listaId).update({'nombre': nuevoNombre}); } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> obtenerPeliculasDeListaPersonalizada(
      String listaId) async {
    final col = _coleccion('listas_personalizadas');
    if (col == null) return [];
    try {
      final doc = await col.doc(listaId).get();
      final data = doc.data();
      if (data == null) return [];
      return List<Map<String, dynamic>>.from(data['peliculas'] ?? []);
    } catch (_) { return []; }
  }

  Future<void> agregarPeliculaALista(
      String listaId, Pelicula pelicula) async {
    final col = _coleccion('listas_personalizadas');
    if (col == null) return;
    try {
      await col.doc(listaId).update({
        'peliculas': FieldValue.arrayUnion([pelicula.aMapaFirebase()]),
      });
    } catch (_) {}
  }

  // Elimina una película del array: lee el array completo, filtra y reescribe.
  Future<void> quitarPeliculaDeLista(
      String listaId, int peliculaId) async {
    final col = _coleccion('listas_personalizadas');
    if (col == null) return;
    try {
      final doc = await col.doc(listaId).get();
      final peliculas = List<Map<String, dynamic>>.from(
          doc.data()?['peliculas'] ?? []);
      peliculas.removeWhere((p) => p['identificador'] == peliculaId);
      await col.doc(listaId).update({'peliculas': peliculas});
    } catch (_) {}
  }

  Future<bool> peliculaEstaEnLista(
      String listaId, int peliculaId) async {
    final peliculas = await obtenerPeliculasDeListaPersonalizada(listaId);
    return peliculas.any((p) => p['identificador'] == peliculaId);
  }

  // ── ESTADÍSTICAS DE PERFIL ────────────────────────────────────────────
  // Lanza las 5 consultas en paralelo con Future.wait para minimizar latencia.
  Future<Map<String, int>> obtenerEstadisticas() async {
    final resultados = await Future.wait([
      _coleccion('favoritas')?.get() ?? Future.value(null),
      _coleccion('vistas')?.get() ?? Future.value(null),
      _coleccion('pendientes')?.get() ?? Future.value(null),
      _coleccion('valoraciones')?.get() ?? Future.value(null),
      _coleccion('resenas')?.get() ?? Future.value(null),
    ]);
    return {
      'favoritas': resultados[0]?.docs.length ?? 0,
      'vistas': resultados[1]?.docs.length ?? 0,
      'pendientes': resultados[2]?.docs.length ?? 0,
      'valoraciones': resultados[3]?.docs.length ?? 0,
      'resenas': resultados[4]?.docs.length ?? 0,
    };
  }

  // ── LISTA DE RESEÑAS ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerListaResenas() async {
    final col = _coleccion('resenas');
    if (col == null) return [];
    try {
      final docs = await col.get();
      return docs.docs.map((d) => d.data()).toList();
    } catch (_) { return []; }
  }

  // ── LISTA DE VALORACIONES ─────────────────────────────────────────────

  // Devuelve las valoraciones del usuario ordenadas de mayor a menor puntuación.
  Future<List<Map<String, dynamic>>> obtenerListaValoraciones() async {
    final col = _coleccion('valoraciones');
    if (col == null) return [];
    try {
      final docs = await col.get();
      final lista = docs.docs.map((d) => d.data()).toList();
      lista.sort((a, b) =>
          (b['puntuacion'] as int).compareTo(a['puntuacion'] as int));
      return lista;
    } catch (_) { return []; }
  }
}
