// servicios/servicio_openai.dart
// Cliente para la API de OpenAI (chat completions).
// Implementa CineBot: el asistente de inteligencia artificial de CineAI.
// Solo recomienda películas, nunca series.

import 'dart:convert';
import 'package:http/http.dart' as http;

// Representa un mensaje individual dentro de la conversación con CineBot.
// remitente puede ser 'user' o 'assistant', que son los roles que espera la API.
class MensajeConversacion {
  final String remitente;
  final String contenido;

  const MensajeConversacion({
    required this.remitente,
    required this.contenido,
  });

  // Serializa el mensaje al formato que espera la API de OpenAI.
  Map<String, String> aFormatoApi() => {
        'role': remitente,
        'content': contenido,
      };
}

class ServicioOpenAI {
  // La clave se inyecta en tiempo de compilación, nunca se escribe aquí.
  // Ver env.json.example / README para cómo configurarla.
  static const String _claveApi = String.fromEnvironment('OPENAI_API_KEY');

  static const String _urlApi = 'https://api.openai.com/v1/chat/completions';

  // gpt-4o-mini: equilibrio entre calidad de respuesta y coste de tokens.
  static const String _modeloIA = 'gpt-4o-mini';

  // System prompt que define el comportamiento de CineBot.
  // Establece el tono, el idioma, el formato de respuesta y el bloque
  // especial CINEAI_PELICULAS:[...] que la app parsea para mostrar tarjetas.
  static const String _instruccionesAsistente = '''
Eres CineBot, el asistente de inteligencia artificial de la app CineAI.
Tu misión es ayudar al usuario a encontrar la película perfecta para cada momento.

CÓMO RESPONDER:
- Responde SIEMPRE en español, con tono cercano, natural y entusiasta.
- Recomienda ÚNICAMENTE películas. Nunca recomiendes series, documentales de TV ni miniseries.
- Cuando el usuario pida recomendaciones, sugiere entre 3 y 5 películas.
- Para cada película escribe: título (año) — una frase corta explicando por qué encaja.
- Termina siempre con una pregunta corta para afinar más la búsqueda.
- Si el usuario saluda o hace preguntas generales sobre cine, responde de forma natural.
- Si el usuario menciona actores, directores o sagas, úsalo para personalizar la recomendación.
- Nunca repitas las mismas películas en la misma conversación.
- Mantén las respuestas concisas, no más de 6-8 líneas.

FORMATO OBLIGATORIO CUANDO RECOMIENDAS PELÍCULAS:
Al final de tu respuesta, si recomiendas películas, añade SIEMPRE este bloque exacto (sin espacios extra, en una sola línea):
CINEAI_PELICULAS:[{"titulo":"Título exacto en inglés o español","anio":YYYY},{"titulo":"Otro título","anio":YYYY}]

Usa el título original o el más conocido internacionalmente para que se pueda buscar correctamente.
Si no hay recomendaciones concretas (solo charla), NO incluyas el bloque.
''';

  // Envía el historial completo de la conversación a OpenAI y devuelve la respuesta.
  // El system prompt siempre va primero para que el modelo respete el rol de CineBot.
  Future<String> enviarMensaje(
      List<MensajeConversacion> historialConversacion) async {
    if (_claveApi == 'TU_CLAVE_API_OPENAI_AQUI') {
      // Modo demo: respuestas pregeneradas sin llamada a red
      return _generarRespuestaEjemplo(historialConversacion.last.contenido);
    }

    try {
      final listaMensajes = [
        {'role': 'system', 'content': _instruccionesAsistente},
        ...historialConversacion.map((mensaje) => mensaje.aFormatoApi()),
      ];

      final respuesta = await http.post(
        Uri.parse(_urlApi),
        headers: {
          'Authorization': 'Bearer $_claveApi',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _modeloIA,
          'messages': listaMensajes,
          'max_tokens': 500,
          'temperature': 0.8, // algo de creatividad sin perder coherencia
        }),
      );

      if (respuesta.statusCode == 200) {
        // Decodifica con utf8 explícito para conservar tildes y caracteres especiales
        final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
        return datos['choices'][0]['message']['content'] as String;
      } else {
        return 'No se pudo conectar con la inteligencia artificial (${respuesta.statusCode}). '
            'Comprueba tu clave de API de OpenAI.';
      }
    } catch (error) {
      return 'Error de conexión. Comprueba que tienes internet y vuelve a intentarlo.';
    }
  }

  // Separa el texto visible del bloque JSON de películas incrustado en la respuesta.
  // Devuelve una tupla (textoLimpio, listaDePeliculas).
  //
  // GPT a veces añade texto después del JSON, por eso se busca el primer '['
  // y el último ']' en lugar de parsear directamente desde la marca.
  // Esto hace el parser robusto ante variaciones en el formato de la respuesta.
  static (String, List<Map<String, dynamic>>) parsearRespuesta(String raw) {
    const marca = 'CINEAI_PELICULAS:';
    final idx = raw.indexOf(marca);
    if (idx == -1) return (raw.trim(), []);

    final texto = raw.substring(0, idx).trim();
    final resto = raw.substring(idx + marca.length).trim();
    // Extraemos solo el array [...] aunque haya texto extra después
    final inicio = resto.indexOf('[');
    final fin = resto.lastIndexOf(']');
    if (inicio == -1 || fin == -1 || fin <= inicio) return (texto, []);
    final jsonStr = resto.substring(inicio, fin + 1);
    try {
      final lista = jsonDecode(jsonStr) as List;
      return (texto, lista.cast<Map<String, dynamic>>());
    } catch (_) {
      return (texto, []);
    }
  }

  // Respuestas de ejemplo usadas cuando no hay clave de OpenAI configurada.
  // Permiten demostrar el flujo del chat sin coste de API.
  String _generarRespuestaEjemplo(String mensajeUsuario) {
    final mensajeEnMinusculas = mensajeUsuario.toLowerCase();

    if (mensajeEnMinusculas.contains('acción') ||
        mensajeEnMinusculas.contains('accion')) {
      return '¡Aquí van mis recomendaciones de acción!\n\n'
          '• Mad Max: Furia en la carretera (2015) — Acción pura y dura, una obra maestra visual.\n'
          '• John Wick (2014) — Coreografía de lucha increíble y un ritmo frenético.\n'
          '• Mission: Impossible - Fallout (2018) — Las mejores escenas de acción de la saga.\n\n'
          '¿Prefieres algo más reciente o te gustan los clásicos?';
    } else if (mensajeEnMinusculas.contains('terror') ||
        mensajeEnMinusculas.contains('miedo')) {
      return '¡Vamos a pasar miedo!\n\n'
          '• Hereditary (2018) — Terror psicológico y familiar que no olvidarás.\n'
          '• El Conjuro (2013) — Basada en hechos reales, muy efectiva y perturbadora.\n'
          '• Midsommar (2019) — Terror a plena luz del día, una experiencia única.\n\n'
          '¿Prefieres más sustos directos o algo más psicológico?';
    } else if (mensajeEnMinusculas.contains('comedia') ||
        mensajeEnMinusculas.contains('reír') ||
        mensajeEnMinusculas.contains('reir')) {
      return '¡A reírnos!\n\n'
          '• El Gran Lebowski (1998) — Humor absurdo y personajes inolvidables.\n'
          '• Entre copas (2004) — Comedia adulta con una actuación brillante.\n'
          '• Superbad (2007) — Humor adolescente muy bien escrito y divertidísimo.\n\n'
          '¿Te gustan más las comedias de situación o el humor absurdo?';
    } else if (mensajeEnMinusculas.contains('romance') ||
        mensajeEnMinusculas.contains('amor')) {
      return '¡Para ponerse romántico!\n\n'
          '• Antes del amanecer (1995) — Los diálogos más bonitos de la historia del cine.\n'
          '• La La Land (2016) — Amor, sueños y música, visualmente preciosa.\n'
          '• Eterno resplandor de una mente sin recuerdos (2004) — Amor y memoria, única en su género.\n\n'
          '¿Prefieres final feliz o algo más agridulce?';
    } else if (mensajeEnMinusculas.contains('ciencia ficción') ||
        mensajeEnMinusculas.contains('ciencia ficcion') ||
        mensajeEnMinusculas.contains('scifi')) {
      return '¡Viajamos al futuro!\n\n'
          '• Interstellar (2014) — Viaje espacial emocionante y muy bien explicado.\n'
          '• Arrival (2016) — Ciencia ficción inteligente sobre la comunicación con alienígenas.\n'
          '• Blade Runner 2049 (2017) — Visualmente impresionante y con una historia profunda.\n\n'
          '¿Prefieres algo más de aventura espacial o más reflexivo?';
    } else {
      return '¡Hola! Soy CineBot.\n\n'
          'Puedo ayudarte a encontrar la película perfecta. Cuéntame qué te apetece ver:\n\n'
          '• "Quiero acción con mucho ritmo"\n'
          '• "Busco una comedia para ver en familia"\n'
          '• "Algo de ciencia ficción que haga pensar"\n'
          '• "Una película romántica para esta noche"\n\n'
          '¿Qué te pide el cuerpo hoy?';
    }
  }
}
