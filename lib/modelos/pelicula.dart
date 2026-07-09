// modelos/pelicula.dart
// Modelo de datos central de la aplicación.
// Representa una película con todos sus atributos y ofrece tres constructores:
//   - desdeRespuestaTMDb: a partir del JSON que devuelve la API de TMDb
//   - desdeFirebase: a partir del mapa almacenado en Firestore
//   - constructor estándar: para crear objetos manualmente o en tests

class Pelicula {
  final int identificador;      // ID único de TMDb (se usa como clave en Firestore)
  final String titulo;
  final String descripcion;
  final String urlCartel;       // URL completa a la imagen de TMDb (tamaño w500)
  final double puntuacion;      // Nota media de TMDb (0.0 - 10.0)
  final String fechaEstreno;    // Formato ISO: "YYYY-MM-DD"
  final List<String> generos;
  final int duracion;           // minutos
  final List<String> reparto;   // nombres de los 6 primeros actores del crédito
  final String director;
  bool guardadaComoFavorita;    // mutable para actualizar el icono del corazón sin recargar
  final String idiomaOriginal;  // código ISO 639-1 (en, es, fr, ...)

  Pelicula({
    required this.identificador,
    required this.titulo,
    required this.descripcion,
    required this.urlCartel,
    required this.puntuacion,
    required this.fechaEstreno,
    required this.generos,
    this.duracion = 0,
    this.reparto = const [],
    this.director = '',
    this.guardadaComoFavorita = false,
    this.idiomaOriginal = 'en',
  });

  // Construye una Pelicula desde el JSON de /movie/popular, /trending o /search.
  // El campo 'poster_path' de TMDb viene solo con el sufijo (/xxxx.jpg),
  // por eso se concatena la URL base con el tamaño w500.
  factory Pelicula.desdeRespuestaTMDb(Map<String, dynamic> json) {
    return Pelicula(
      identificador: json['id'] ?? 0,
      titulo: json['title'] ?? json['original_title'] ?? 'Sin título',
      descripcion: json['overview'] ?? 'Sin descripción disponible.',
      urlCartel: json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${json['poster_path']}'
          : '',
      puntuacion: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      fechaEstreno: json['release_date'] ?? '',
      generos: [],
      idiomaOriginal: json['original_language'] as String? ?? 'en',
    );
  }

  // Serializa la película para guardarla en Firestore
  // (favoritas, vistas, pendientes y listas personalizadas).
  Map<String, dynamic> aMapaFirebase() {
    return {
      'identificador': identificador,
      'titulo': titulo,
      'descripcion': descripcion,
      'urlCartel': urlCartel,
      'puntuacion': puntuacion,
      'fechaEstreno': fechaEstreno,
      'generos': generos,
      'duracion': duracion,
      'reparto': reparto,
      'director': director,
    };
  }

  // Reconstruye una Pelicula a partir del documento guardado en Firestore.
  // guardadaComoFavorita se fuerza a true porque si está en la colección, es favorita.
  factory Pelicula.desdeFirebase(Map<String, dynamic> datos) {
    return Pelicula(
      identificador: datos['identificador'] ?? 0,
      titulo: datos['titulo'] ?? '',
      descripcion: datos['descripcion'] ?? '',
      urlCartel: datos['urlCartel'] ?? '',
      puntuacion: (datos['puntuacion'] as num?)?.toDouble() ?? 0.0,
      fechaEstreno: datos['fechaEstreno'] ?? '',
      generos: List<String>.from(datos['generos'] ?? []),
      duracion: datos['duracion'] ?? 0,
      reparto: List<String>.from(datos['reparto'] ?? []),
      director: datos['director'] ?? '',
      guardadaComoFavorita: true,
    );
  }

  // Datos de ejemplo usados como fallback cuando la API de TMDb no está disponible.
  static List<Pelicula> obtenerListaEjemplo() {
    return [
      Pelicula(
        identificador: 157336,
        titulo: 'Interstellar',
        descripcion:
            'Un equipo de exploradores viaja a través de un agujero de gusano en busca de un nuevo hogar para la humanidad.',
        urlCartel: '',
        puntuacion: 8.6,
        fechaEstreno: '2014-11-07',
        generos: ['Ciencia ficción', 'Aventura', 'Drama'],
      ),
      Pelicula(
        identificador: 27205,
        titulo: 'Inception',
        descripcion:
            'Un ladrón que roba secretos a través de los sueños recibe la tarea de plantar una idea en la mente de un CEO.',
        urlCartel: '',
        puntuacion: 8.8,
        fechaEstreno: '2010-07-16',
        generos: ['Acción', 'Ciencia ficción', 'Thriller'],
      ),
      Pelicula(
        identificador: 155,
        titulo: 'El Caballero Oscuro',
        descripcion:
            'Batman se enfrenta al Joker, quien siembra el caos en la ciudad de Gotham.',
        urlCartel: '',
        puntuacion: 9.0,
        fechaEstreno: '2008-07-18',
        generos: ['Acción', 'Crimen', 'Drama'],
      ),
      Pelicula(
        identificador: 19995,
        titulo: 'Avatar',
        descripcion:
            'Un marine en silla de ruedas viaja a la luna Pandora y se debate entre su misión y la protección de sus habitantes.',
        urlCartel: '',
        puntuacion: 7.9,
        fechaEstreno: '2009-12-18',
        generos: ['Acción', 'Aventura', 'Ciencia ficción'],
      ),
      Pelicula(
        identificador: 98,
        titulo: 'Gladiator',
        descripcion:
            'Un general romano es traicionado y reducido a la esclavitud. Lucha para convertirse en el mejor gladiador del Imperio.',
        urlCartel: '',
        puntuacion: 8.5,
        fechaEstreno: '2000-05-05',
        generos: ['Acción', 'Aventura', 'Drama'],
      ),
      Pelicula(
        identificador: 603,
        titulo: 'Matrix',
        descripcion:
            'Un programador descubre que la realidad es una simulación creada por máquinas que esclavizaron a la humanidad.',
        urlCartel: '',
        puntuacion: 8.7,
        fechaEstreno: '1999-03-31',
        generos: ['Acción', 'Ciencia ficción'],
      ),
    ];
  }
}
