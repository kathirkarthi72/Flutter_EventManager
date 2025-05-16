import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserLoginScreen extends StatefulWidget {
  final String eventUUID;
  UserLoginScreen({required this.eventUUID});

  @override
  _UserLoginScreenState createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  String? eventName;

  @override
  void initState() {
    super.initState();
    _fetchEventDetails();
  }

  void _fetchEventDetails() async {
    final dbRef = FirebaseDatabase.instance.ref();
    final snapshot = await dbRef
        .child('Event Gallery App/events/${widget.eventUUID}/Event Name')
        .get();
    if (snapshot.exists) {
      setState(() {
        eventName = snapshot.value.toString();
      });
    } else {
      setState(() {
        eventName = 'Unknown Event';
      });
    }
  }

  void _loginUser() async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Successful for $eventName')),
      );

      // Navigate to user dashboard
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (eventName != null)
              Text('Event: $eventName', style: TextStyle(fontSize: 18)),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _loginUser, child: Text('Login')),
          ],
        ),
      ),
    );
  }
}
