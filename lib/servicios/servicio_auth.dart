// servicios/servicio_auth.dart
// Encapsula todas las operaciones de Firebase Authentication:
// inicio de sesión, registro, cierre de sesión y traducción de códigos de error.

import 'package:firebase_auth/firebase_auth.dart';

class ServicioAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Usuario autenticado en este momento (null si no hay sesión).
  User? get usuarioActual => _auth.currentUser;

  // Stream que emite un nuevo evento cada vez que el estado de sesión cambia.
  // Lo escucha el StreamBuilder de main.dart para navegar automáticamente.
  Stream<User?> get cambiosEstadoAuth => _auth.authStateChanges();

  // Inicia sesión con correo y contraseña.
  // Lanza FirebaseAuthException si las credenciales son incorrectas.
  Future<UserCredential> iniciarSesion({
    required String email,
    required String contrasena,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: contrasena,
    );
  }

  // Crea una cuenta nueva y actualiza el displayName del usuario en Firebase
  // en la misma llamada, para que aparezca el nombre desde el primer login.
  Future<UserCredential> registrarse({
    required String nombre,
    required String email,
    required String contrasena,
  }) async {
    final credencial = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: contrasena,
    );
    await credencial.user?.updateDisplayName(nombre.trim());
    return credencial;
  }

  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }

  // Convierte los códigos de error de Firebase Auth en mensajes legibles en español.
  // Se muestra directamente al usuario en la pantalla de login/registro.
  String traducirError(String codigo) {
    switch (codigo) {
      case 'user-not-found':
        return 'No existe ninguna cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'El formato del correo no es válido.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      default:
        return 'Se produjo un error. Inténtalo de nuevo.';
    }
  }
}
