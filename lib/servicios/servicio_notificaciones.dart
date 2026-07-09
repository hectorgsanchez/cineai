// servicios/servicio_notificaciones.dart
// Gestiona las notificaciones push mediante Firebase Cloud Messaging

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// Handler para mensajes en segundo plano (debe ser función top-level)
@pragma('vm:entry-point')
Future<void> _manejarMensajeFondo(RemoteMessage mensaje) async {
  debugPrint('Notificación en fondo: ${mensaje.notification?.title}');
}

class ServicioNotificaciones {
  static final ServicioNotificaciones _instancia =
      ServicioNotificaciones._interno();
  factory ServicioNotificaciones() => _instancia;
  ServicioNotificaciones._interno();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Canal de notificaciones para Android
  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'cineai_canal',
    'Notificaciones CineAI',
    description: 'Notificaciones de recomendaciones y novedades de CineAI',
    importance: Importance.max, // max = banner flotante heads-up visible
    showBadge: true,
    playSound: true,
  );

  Future<void> inicializar() async {
    // Registrar handler de fondo
    FirebaseMessaging.onBackgroundMessage(_manejarMensajeFondo);

    // Configurar plugin de notificaciones locales
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    // Crear canal en Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);

    // Solicitar permisos al usuario
    final configuracion = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        'Permiso de notificaciones: ${configuracion.authorizationStatus}');

    // Obtener token FCM (para enviar notificaciones específicas)
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');

    // Manejar notificaciones cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen(_mostrarNotificacionForeground);

    // Manejar tap en notificación cuando la app estaba en fondo
    FirebaseMessaging.onMessageOpenedApp.listen((mensaje) {
      debugPrint('Notificación abierta: ${mensaje.notification?.title}');
    });
  }

  void _mostrarNotificacionForeground(RemoteMessage mensaje) {
    final notificacion = mensaje.notification;
    final android = mensaje.notification?.android;
    if (notificacion != null && android != null) {
      _localNotifications.show(
        notificacion.hashCode,
        notificacion.title,
        notificacion.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _canal.id,
            _canal.name,
            channelDescription: _canal.description,
            importance: Importance.max,
            priority: Priority.max,
            visibility: NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }

  // Obtener el token FCM del dispositivo actual
  Future<String?> obtenerToken() async {
    return await _messaging.getToken();
  }

  // Lanza una notificación local inmediata (visible aunque la app esté abierta)
  Future<void> notificarLocal({
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      titulo,
      cuerpo,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canal.id,
          _canal.name,
          channelDescription: _canal.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(cuerpo),
          color: const Color(0xFF2E75B6),
        ),
      ),
      payload: payload,
    );
  }

  // Notificación al recibir recomendación del bot
  Future<void> notificarRecomendacionIA(List<String> titulos) async {
    if (titulos.isEmpty) return;
    final lista = titulos.take(3).join(', ');
    await notificarLocal(
      titulo: 'CineBot tiene algo para ti',
      cuerpo: titulos.length == 1
          ? 'Te recomiendo: $lista'
          : 'Te recomiendo: $lista${titulos.length > 3 ? ' y más...' : ''}',
      payload: 'recomendacion',
    );
  }

  // Notificación de bienvenida / prueba para la demo
  Future<void> notificarBienvenida(String nombre) async {
    await notificarLocal(
      titulo: 'Bienvenido a CineAI, $nombre',
      cuerpo:
          'Descubre películas con IA, crea listas y comparte tus valoraciones con la comunidad.',
      payload: 'bienvenida',
    );
  }

  // Notificación de nueva película tendencia
  Future<void> notificarTendencia(String tituloPelicula) async {
    await notificarLocal(
      titulo: 'Tendencia ahora',
      cuerpo: '"$tituloPelicula" está arrasando hoy. ¡Descúbrela en CineAI!',
      payload: 'tendencia',
    );
  }
}
