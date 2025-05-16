import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

class EventGalleryScreen extends StatefulWidget {
  final String eventId;

  const EventGalleryScreen({super.key, required this.eventId});

  @override
  State<EventGalleryScreen> createState() => _EventGalleryScreenState();
}

class _EventGalleryScreenState extends State<EventGalleryScreen> {
  final dbRef = FirebaseDatabase.instance.ref("Event Gallery App/events");
  final storageRef = FirebaseStorage.instance.ref();
  final ImagePicker _picker = ImagePicker();

  List<String> galleryImages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGalleryImages();
  }

  Future<void> _fetchGalleryImages() async {
    final snapshot = await dbRef.child(widget.eventId).child("gallery").get();

    if (snapshot.exists) {
      final Map<dynamic, dynamic> data = snapshot.value as Map;
      final images = data.values.map((e) => e.toString()).toList();
      setState(() {
        galleryImages = images;
        isLoading = false;
      });
    } else {
      setState(() {
        galleryImages = [];
        isLoading = false;
      });
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      final fileId = const Uuid().v4();
      final ref = storageRef.child("gallery/${widget.eventId}/$fileId.jpg");

      final uploadTask = await ref.putFile(imageFile);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      await dbRef.child(widget.eventId).child("gallery").push().set(imageUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image uploaded successfully!")),
      );

      _fetchGalleryImages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final isRealDevice = await _isPhysicalIOSDevice();
      if (!isRealDevice) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera not supported on iOS Simulator")),
        );
        return;
      }

      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        await _uploadImage(imageFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Camera error: $e")),
      );
    }
  }

  Future<void> _uploadFromGallery() async {
  try {
    List<XFile> pickedFiles = [];

    // Try multi-image
    try {
      pickedFiles = await _picker.pickMultiImage();
    } catch (e) {
      // Fallback to single image
      final single = await _picker.pickImage(source: ImageSource.gallery);
      if (single != null) pickedFiles = [single];
    }

    if (pickedFiles.isNotEmpty) {
      for (var pickedFile in pickedFiles) {
        final imageFile = File(pickedFile.path);
        if (await imageFile.exists()) {
          await _uploadImage(imageFile);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No images selected.")),
      );
    }
  } catch (e) {
    debugPrint("Gallery upload error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Gallery upload error: $e")),
    );
  }
}





  Future<bool> _isPhysicalIOSDevice() async {
    if (Platform.isIOS) {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.isPhysicalDevice;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Event Gallery"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : galleryImages.isEmpty
                    ? const Center(child: Text("No images in gallery"))
                    : GridView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: galleryImages.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              galleryImages[index],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(child: Icon(Icons.broken_image)),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Take Photo"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 223, 220, 228),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _uploadFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text("Upload from Gallery"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 224, 222, 227),
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
