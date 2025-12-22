import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'data_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'bg_service_channel_v2', 
    'Actualización en Segundo Plano', 
    description: 'Mantiene la descarga activa',
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, 
      isForegroundMode: true,
      notificationChannelId: 'bg_service_channel_v2',
      initialNotificationTitle: 'VoxGamer',
      initialNotificationContent: 'Servicio activo',
      foregroundServiceNotificationId: 888, // Notificación del sistema (fija)
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final DataService dataService = DataService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('startSync').listen((event) async {
    bool forceDownload = true;
    if (event != null && event.containsKey('forceDownload')) {
      forceDownload = event['forceDownload'];
    }

    try {
      await dataService.syncGames(
        forceDownload: forceDownload, 
        onProgress: (progress) async {
          final percent = (progress * 100).toInt();
          
          service.invoke('progress', {'percent': percent});

          if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
              // USAMOS UN ID DIFERENTE (889) PARA LA BARRA DE PROGRESO
              // Así no conflictos con la notificación 888 del sistema
              final notificationDetails = NotificationDetails(
                android: AndroidNotificationDetails(
                  'bg_service_channel_v2', 
                  'Actualización en Segundo Plano',
                  icon: 'ic_launcher',
                  ongoing: true,
                  onlyAlertOnce: true,
                  showProgress: true,
                  maxProgress: 100,
                  progress: percent,
                  indeterminate: false,
                ),
              );
              
              flutterLocalNotificationsPlugin.show(
                889, // ID DEDICADO A LA BARRA
                'Actualizando catálogo...',
                '$percent% completado',
                notificationDetails,
              );
              
              // Actualizamos también la notificación del sistema (888) solo con texto
              service.setForegroundNotificationInfo(
                title: "VoxGamer",
                content: "Procesando: $percent%",
              );
            }
          }
        },
      );

      service.invoke('success');
      
      // Limpiamos la barra de progreso
      flutterLocalNotificationsPlugin.cancel(889);
      
      flutterLocalNotificationsPlugin.show(
        999,
        '¡Actualización completada!',
        'La base de datos está lista.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_updates', 
            'Actualizaciones Completadas',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );

    } catch (e) {
      service.invoke('error', {'message': e.toString()});
    } finally {
      service.stopSelf();
    }
  });
}
