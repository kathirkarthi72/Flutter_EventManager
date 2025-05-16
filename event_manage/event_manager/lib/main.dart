// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'screens/login_screen.dart';

// import 'firebase_options.dart';


// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//    await Firebase.initializeApp(
//         options: DefaultFirebaseOptions.currentPlatform,
//     );

//   runApp(const MyApp());
// }

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

import 'package:event_manager/screens/qr_generator_screen.dart';
import 'screens/home_screen.dart'; // 👈 Add this
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseDatabase.instance.setPersistenceEnabled(true);

  bool isPhysicalDevice = await _isPhysicalIOSDevice();
  print('Is this a physical device? $isPhysicalDevice');

  runApp(const MyApp());
}

Future<bool> _isPhysicalIOSDevice() async {
  const platform = MethodChannel('device_info');
  try {
    final String? device = await platform.invokeMethod('isPhysicalDevice');
    return device == 'true';
  } catch (_) {
    return false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event Manager App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(), // 👈 This shows the new screen with buttons
      routes: {
        '/qr': (_) => const QRGeneratorScreen(
              eventName: null,
              eventDate: null,
              eventStatus: null,
              eventId: null,
            ),
      },
    );
  }
}
