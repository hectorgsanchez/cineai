# CineAI

Final degree project (TFG) for the Higher Vocational Training (CFGS) in Multiplatform Application Development (DAM).

CineAI is a mobile movie-recommendation app combining the [TMDb](https://www.themoviedb.org/) catalog with **CineBot**, an AI chat assistant powered by the OpenAI API that helps users find the perfect movie for any moment.

Built with Flutter for Android and iOS.

## Features

- **Authentication** (sign up / log in) with Firebase Auth
- **Movie catalog**: popular, trending, search and recommendations (TMDb)
- **CineBot**: AI chat that recommends movies based on what the user asks for
- **Personal lists**: favorites, watchlist, watched and custom lists
- **Ratings and reviews**
- **Push notifications** (Firebase Cloud Messaging + local notifications)
- **User profile** with activity history

## Tech stack

- [Flutter](https://flutter.dev/) / Dart
- [Firebase](https://firebase.google.com/): Auth, Cloud Firestore, Cloud Messaging
- [TMDb API](https://developer.themoviedb.org/) — movie data
- [OpenAI API](https://platform.openai.com/) — CineBot (gpt-4o-mini)

## Documentation

Available in [`docs/`](./docs):

- Final project report (Memoria)
- User manual
- Installation manual

## Download the app

The latest compiled APK is available under [Releases](../../releases).

## Getting started (development)

### Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- A [TMDb](https://www.themoviedb.org/settings/api) API key
- An [OpenAI](https://platform.openai.com/api-keys) API key
- Your own [Firebase](https://console.firebase.google.com/) project (for `google-services.json` in `android/app/`)

### Configuration

No API keys are hardcoded in this repository — they're injected at build time.

1. Copy `env.json.example` to `env.json` and fill in your own keys:

   ```json
   {
     "OPENAI_API_KEY": "your-openai-key",
     "TMDB_API_KEY": "your-tmdb-key"
   }
