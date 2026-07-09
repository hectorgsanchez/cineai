# CineAI

Trabajo de Fin de Grado del Ciclo Formativo de Grado Superior en Desarrollo de Aplicaciones Multiplataforma (DAM).

CineAI es una aplicación móvil de recomendación de películas que combina el catálogo de [TMDb](https://www.themoviedb.org/) con **CineBot**, un asistente conversacional basado en la API de OpenAI que ayuda al usuario a encontrar la película perfecta para cada momento.

Desarrollada con Flutter para Android e iOS.

## Funcionalidades

- **Autenticación** de usuarios (registro / inicio de sesión) con Firebase Auth
- **Catálogo de películas**: populares, en tendencia, búsqueda y recomendaciones (TMDb)
- **CineBot**: chat con IA que recomienda películas según lo que pide el usuario
- **Listas personales**: favoritas, pendientes, vistas y listas personalizadas
- **Valoraciones y reseñas** de películas
- **Notificaciones** push (Firebase Cloud Messaging + notificaciones locales)
- **Perfil de usuario** con actividad e historial

## Tecnologías

- [Flutter](https://flutter.dev/) / Dart
- [Firebase](https://firebase.google.com/): Auth, Cloud Firestore, Cloud Messaging
- [TMDb API](https://developer.themoviedb.org/) — datos de películas
- [OpenAI API](https://platform.openai.com/) — CineBot (gpt-4o-mini)

## Documentación

En la carpeta [`docs/`](./docs) están disponibles:

- Memoria del TFG
- Manual de usuario
- Manual de instalación

## Descargar la app

La última versión compilada (APK) está disponible en la sección [Releases](../../releases) de este repositorio.

## Puesta en marcha (desarrollo)

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado
- Una clave de API de [TMDb](https://www.themoviedb.org/settings/api)
- Una clave de API de [OpenAI](https://platform.openai.com/api-keys)
- Un proyecto de [Firebase](https://console.firebase.google.com/) propio (para `google-services.json` en `android/app/`)

### Configuración

Este proyecto no incluye ninguna clave en el código: se inyectan en tiempo de compilación para no exponerlas en el repositorio.

1. Copia `env.json.example` a `env.json` y rellena tus propias claves:

   ```json
   {
     "OPENAI_API_KEY": "tu-clave-de-openai",
     "TMDB_API_KEY": "tu-clave-de-tmdb"
   }
   ```

2. Instala las dependencias:

   ```
   flutter pub get
   ```

3. Ejecuta la app pasando las claves como `--dart-define-from-file`:

   ```
   flutter run --dart-define-from-file=env.json
   ```

### Compilar el APK de release

```
flutter build apk --release --dart-define-from-file=env.json
```

El APK se genera en `build/app/outputs/flutter-apk/app-release.apk`.

## Autor

Héctor Grande
