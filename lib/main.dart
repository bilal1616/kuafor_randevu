import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kuafor_salon_randevu/screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Arka planda mesaj alındı: ${message.data}");
}

void setupFirebaseMessagingListeners() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      // Firebase'den gelen verileri al
      final String username = message.data['username'] ?? 'Bilinmiyor';
      final String formattedDate = message.data['date'] ??
          'Belirtilmedi'; // TR formatında tarih direkt alınıyor
      final String time = message.data['time'] ?? 'Belirtilmedi';
      final String services = message.data['services'] ?? 'Belirtilmedi';

      // Genişletilmiş bildirim içeriği
      final bigTextStyleInformation = BigTextStyleInformation(
        'Ad: $username\n'
        'Tarih: $formattedDate\n'
        'Saat: $time\n'
        'Hizmetler: $services',
        contentTitle: notification.title,
        summaryText: 'Yeni Randevu Detayları',
      );

      _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        'Ad: $username\nTarih: $formattedDate\nSaat: $time\nHizmetler: $services',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'Bu kanal önemli bildirimler için kullanılır.',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            styleInformation: bigTextStyleInformation,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            ticker: 'Yeni Randevu Bildirimi',
            showWhen: true,
            ongoing: false,
          ),
        ),
      );
    }
  });
}

Future<void> requestNotificationPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("Bildirim izni verildi.");
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print("Provisional bildirim izni verildi.");
  } else {
    print("Bildirim izni reddedildi.");
  }
}

Future<void> requestAndroidPermissions() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting(
      'tr_TR', null); // Türkçe locale verisini başlat

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  setupFirebaseMessagingListeners();
  await requestNotificationPermission();
  await requestAndroidPermissions();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
