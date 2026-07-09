// main.dart
// Punto de entrada de la aplicación CineAI.
// Inicializa Firebase y el servicio de notificaciones antes de arrancar la UI.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pantallas/pantalla_shell.dart';
import 'pantallas/pantalla_login.dart';
import 'servicios/servicio_notificaciones.dart';

void main() async {
  // Garantiza que los bindings de Flutter estén listos antes de llamadas async
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await ServicioNotificaciones().inicializar();
  runApp(const CineAIApp());
}

// Widget raíz de la aplicación. Define el tema global (Material 3, Nunito, paleta oscura)
// y decide qué pantalla mostrar según el estado de autenticación.
class CineAIApp extends StatelessWidget {
  const CineAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme =
        GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme);

    return MaterialApp(
      title: 'CineAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: baseTextTheme.copyWith(
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: Colors.white),
          bodyMedium:
              baseTextTheme.bodyMedium?.copyWith(color: Colors.white70),
          bodySmall: baseTextTheme.bodySmall?.copyWith(color: Colors.white54),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2E75B6),   // azul principal
          secondary: Color(0xFFFFD700), // dorado para estrellas y ratings
          surface: Color(0xFF161625),   // fondo de tarjetas
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D14),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0D0D14),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF161625),
          hintStyle: GoogleFonts.nunito(color: Colors.white38),
          prefixIconColor: Colors.white38,
          suffixIconColor: Colors.white38,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF161625),
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF161625),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          elevation: 4,
        ),
        useMaterial3: true,
      ),
      // StreamBuilder escucha authStateChanges() de Firebase.
      // Navega automáticamente a PantallaShell si hay sesión activa,
      // o a PantallaLogin si no la hay, sin necesidad de Navigator manual.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PantallaCarga();
          }
          if (snapshot.hasData) {
            return const PantallaShell();
          }
          return const PantallaLogin();
        },
      ),
    );
  }
}

// Pantalla de carga mostrada mientras Firebase verifica la sesión al arrancar.
class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D14),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_rounded, size: 64, color: Color(0xFF2E75B6)),
            SizedBox(height: 24),
            CircularProgressIndicator(
              color: Color(0xFF2E75B6),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
