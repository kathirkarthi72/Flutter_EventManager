// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'qr_scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Event Manager App")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text("Admin Login"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen(eventData: {},)),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("User Login (Scan QR)"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => QRScannerScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
