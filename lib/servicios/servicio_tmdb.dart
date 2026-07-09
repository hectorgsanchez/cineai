// servicios/servicio_tmdb.dart
// Cliente REST para la API de The Movie Database (TMDb).
// Todos los endpoints devuelven resultados en español (es-ES).
// Si la petición falla, los métodos devuelven una lista vacía o datos de ejemplo
// para que la app funcione aunque no haya conexión.

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../modelos/pelicula.dart';

class ServicioTMDb {
  // La clave se inyecta en tiempo de compilación, nunca se escribe aquí.
  // Ver env.json.example / README para cómo configurarla.
  static const String _claveApi = String.fromEnvironment('TMDB_API_KEY');
  static const String _urlBase = 'https://api.themoviedb.org/3';
  static const String _idioma = 'es-ES';

  // Filtro de idiomas: solo se muestran películas en estos idiomas originales
  // para evitar contenido en idiomas sin traducción al español.
  static const Set<String> _idiomasPermitidos = {
    'en', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko', 'zh',
  };

  List<Pelicula> _filtrarIdioma(List<Pelicula> lista) =>
      lista.where((p) => _idiomasPermitidos.contains(p.idiomaOriginal)).toList();

  // GET /movie/popular — películas más populares del momento.
  // En caso de error devuelve la lista de ejemplo estática.
  Future<List<Pelicula>> obtenerPeliculasPopulares() async {
    final direccion = Uri.parse(
      '$_urlBase/movie/popular?api_key=$_claveApi&language=$_idioma&page=1',
    );
    try {
      final respuesta = await http.get(direccion);
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        final resultados = datos['results'] as List;
        return resultados
            .map((pelicula) => Pelicula.desdeRespuestaTMDb(pelicula))
            .toList();
      } else {
        throw Exception('Error al conectar con TMDb: ${respuesta.statusCode}');
      }
    } catch (error) {
      return Pelicula.obtenerListaEjemplo();
    }
  }

  // GET /search/movie — búsqueda por texto libre en español.
  Future<List<Pelicula>> buscarPeliculas(String textoBusqueda) async {
    final textoCodificado = Uri.encodeComponent(textoBusqueda);
    final direccion = Uri.parse(
      '$_urlBase/search/movie?api_key=$_claveApi&language=$_idioma&query=$textoCodificado',
    );
    try {
      final respuesta = await http.get(direccion);
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        final resultados = datos['results'] as List;
        return resultados
            .map((pelicula) => Pelicula.desdeRespuestaTMDb(pelicula))
            .toList();
      } else {
        throw Exception('Error en la búsqueda: ${respuesta.statusCode}');
      }
    } catch (error) {
      return [];
    }
  }

  // GET /movie/{id}?append_to_response=credits
  // Obtiene el detalle completo: géneros, duración, reparto (6 actores) y director.
  // append_to_response evita una segunda petición al endpoint /credits.
  Future<Pelicula?> obtenerDetallePelicula(int identificadorPelicula) async {
    final direccion = Uri.parse(
      '$_urlBase/movie/$identificadorPelicula?api_key=$_claveApi&language=$_idioma&append_to_response=credits',
    );
    try {
      final respuesta = await http.get(direccion);
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);

        // Géneros
        final listaGeneros = datos['genres'] as List? ?? [];
        final generos = listaGeneros.map((g) => g['name'].toString()).toList();

        // Duración
        final duracion = (datos['runtime'] as num?)?.toInt() ?? 0;

        // Reparto: primeros 6 actores del crédito
        final creditos = datos['credits'] as Map<String, dynamic>? ?? {};
        final listaCast = creditos['cast'] as List? ?? [];
        final reparto = listaCast
            .take(6)
            .map((actor) => actor['name'].toString())
            .toList();

        // Director: primer miembro del equipo con job == 'Director'
        final listaEquipo = creditos['crew'] as List? ?? [];
        final directorObj = listaEquipo.firstWhere(
          (p) => p['job'] == 'Director',
          orElse: () => {'name': ''},
        );
        final director = directorObj['name']?.toString() ?? '';

        return Pelicula(
          identificador: datos['id'] ?? 0,
          titulo: datos['title'] ?? datos['original_title'] ?? 'Sin título',
          descripcion: datos['overview'] ?? 'Sin descripción disponible.',
          urlCartel: datos['poster_path'] != null
              ? 'https://image.tmdb.org/t/p/w500${datos['poster_path']}'
              : '',
          puntuacion: (datos['vote_average'] as num?)?.toDouble() ?? 0.0,
          fechaEstreno: datos['release_date'] ?? '',
          generos: generos,
          duracion: duracion,
          reparto: reparto,
          director: director,
        );
      }
    } catch (error) {
      return null;
    }
    return null;
  }

  // GET /trending/movie/day — películas en tendencia hoy a nivel mundial.
  Future<List<Pelicula>> obtenerTendencias() async {
    final direccion = Uri.parse(
      '$_urlBase/trending/movie/day?api_key=$_claveApi&language=$_idioma',
    );
    try {
      final respuesta = await http.get(direccion);
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        return _filtrarIdioma((datos['results'] as List)
            .map((p) => Pelicula.desdeRespuestaTMDb(p))
            .toList());
      }
    } catch (_) {}
    return [];
  }

  // GET /movie/{id}/recommendations — películas similares a una dada.
  // Usado en PantallaInicio para la sección "Recomendadas para ti",
  // basada en las favoritas del usuario.
  Future<List<Pelicula>> obtenerRecomendaciones(int idPelicula) async {
    final direccion = Uri.parse(
      '$_urlBase/movie/$idPelicula/recommendations?api_key=$_claveApi&language=$_idioma',
    );
    try {
      final respuesta = await http.get(direccion);
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        return _filtrarIdioma((datos['results'] as List)
            .map((p) => Pelicula.desdeRespuestaTMDb(p))
            .toList());
      }
    } catch (_) {}
    return [];
  }

  // Descarga dos páginas aleatorias de populares y las mezcla,
  // para que la sección "Más populares" muestre contenido diferente en cada sesión.
  Future<List<Pelicula>> obtenerPopularesAleatorios() async {
    final pagina = Random().nextInt(3) + 1;
    final pagina2 = (pagina % 3) + 1;
    try {
      // Las dos peticiones se lanzan en paralelo con Future.wait
      final resultados = await Future.wait([
        http.get(Uri.parse('$_urlBase/movie/popular?api_key=$_claveApi&language=$_idioma&page=$pagina')),
        http.get(Uri.parse('$_urlBase/movie/popular?api_key=$_claveApi&language=$_idioma&page=$pagina2')),
      ]);
      final lista = <Pelicula>[];
      for (final r in resultados) {
        if (r.statusCode == 200) {
          final datos = jsonDecode(r.body);
          lista.addAll((datos['results'] as List)
              .map((p) => Pelicula.desdeRespuestaTMDb(p)));
        }
      }
      lista.shuffle(Random());
      return _filtrarIdioma(lista);
    } catch (_) {
      return obtenerPeliculasPopulares();
    }
  }

  // Busca una película por título y año exactos para CineBot.
  // La búsqueda se hace SIN language para que TMDb encuentre películas
  // por su título original (en inglés u otro idioma) sin restricciones de localización.
  // Luego se obtiene el detalle en español por separado cuando el usuario abre el detalle.
  // Si no hay resultado con año, reintenta sin el filtro de año como fallback.
  Future<Pelicula?> buscarPorTituloAnio(String titulo, int anio) async {
    final q = Uri.encodeComponent(titulo);
    final uri = Uri.parse(
        '$_urlBase/search/movie?api_key=$_claveApi&query=$q&year=$anio');
    try {
      final r = await http.get(uri);
      if (r.statusCode == 200) {
        final datos = jsonDecode(r.body);
        final resultados = datos['results'] as List;
        if (resultados.isNotEmpty) {
          return Pelicula.desdeRespuestaTMDb(resultados.first);
        }
        // Fallback sin año si la búsqueda con año no devuelve resultados
        final uri2 = Uri.parse(
            '$_urlBase/search/movie?api_key=$_claveApi&query=$q');
        final r2 = await http.get(uri2);
        if (r2.statusCode == 200) {
          final d2 = jsonDecode(r2.body);
          final res2 = d2['results'] as List;
          if (res2.isNotEmpty) return Pelicula.desdeRespuestaTMDb(res2.first);
        }
      }
    } catch (_) {}
    return null;
  }

  // GET /discover/movie?with_genres={id} — películas de un género concreto.
  Future<List<Pelicula>> obtenerPeliculasPorGenero(int identificadorGenero) async {
    final direccion = Uri.parse(
      '$_urlBase/discover/movie?api_key=$_claveApi&language=$_idioma'
      '&with_genres=$identificadorGenero&sort_by=popularity.desc',
    );
    try {
      final respuesta = await http.get(direccion);
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        final resultados = datos['results'] as List;
        return resultados
            .map((pelicula) => Pelicula.desdeRespuestaTMDb(pelicula))
            .toList();
      }
    } catch (error) {
      return Pelicula.obtenerListaEjemplo();
    }
    return [];
  }

  // Tabla de correspondencia entre nombres de género en español e IDs de TMDb.
  static const Map<String, int> idsGeneros = {
    'Acción': 28,
    'Aventura': 12,
    'Comedia': 35,
    'Drama': 18,
    'Terror': 27,
    'Ciencia ficción': 878,
    'Animación': 16,
    'Romance': 10749,
    'Thriller': 53,
    'Crimen': 80,
  };

  // GET /discover/movie con filtros combinados (género, año, puntuación mínima).
  // Los filtros se construyen dinámicamente: solo se añaden los parámetros
  // que el usuario ha especificado. vote_count.gte=50 evita resultados con
  // muy pocos votos que inflen artificialmente la nota.
  Future<List<Pelicula>> descubrirPeliculas({
    Set<String> generos = const {},
    int anioDesde = 0,
    double puntuacionMinima = 0.0,
  }) async {
    final params = StringBuffer(
      '$_urlBase/discover/movie?api_key=$_claveApi&language=$_idioma'
      '&sort_by=popularity.desc&include_adult=false',
    );

    if (generos.isNotEmpty) {
      final ids = generos
          .map((g) => idsGeneros[g])
          .whereType<int>()
          .map((id) => id.toString())
          .join(',');
      if (ids.isNotEmpty) params.write('&with_genres=$ids');
    }

    if (anioDesde > 0) {
      params.write('&primary_release_date.gte=$anioDesde-01-01');
    }

    if (puntuacionMinima > 0) {
      params.write('&vote_average.gte=$puntuacionMinima');
      params.write('&vote_count.gte=50');
    }

    try {
      final respuesta = await http.get(Uri.parse(params.toString()));
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        return _filtrarIdioma((datos['results'] as List)
            .map((p) => Pelicula.desdeRespuestaTMDb(p))
            .toList());
      }
    } catch (_) {}
    return [];
  }
}
