import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoCaptureScreen extends StatefulWidget {
  final String eventId;
  const PhotoCaptureScreen({super.key, required this.eventId});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  final picker = ImagePicker();

  Future<void> _capturePhoto() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final file = File(pickedFile.path);

      // ✅ Save to device gallery using gallery_saver
      await GallerySaver.saveImage(file.path);

      // ✅ Upload to Firebase Storage
      final user = FirebaseAuth.instance.currentUser;
      final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref('events/${widget.eventId}/${user!.uid}/$filename');
      await ref.putFile(file);

      final imageUrl = await ref.getDownloadURL();

      // ✅ Store metadata in Firestore
      await FirebaseFirestore.instance.collection('photos').add({
        'eventId': widget.eventId,
        'userId': user.uid,
        'url': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo saved & uploaded')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Photos')),
      body: Center(
        child: ElevatedButton(
          onPressed: _capturePhoto,
          child: const Text('Capture Photo'),
        ),
      ),
    );
  }
}
