import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class QRGeneratorScreen extends StatefulWidget {
  final bool isEditing;

  const QRGeneratorScreen({
    super.key,
    this.isEditing = false, required eventName, required eventDate, required eventStatus, required eventId, // Default value added
  });

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  final GlobalKey qrKey = GlobalKey();
  final TextEditingController eventNameController = TextEditingController();
  DateTime? selectedDate;
  String selectedStatus = 'Upcoming Event';
  String? qrData;

  final List<String> statusOptions = ['Upcoming Event', 'Open'];

  Future<void> _generateAndSaveQR() async {
    if (eventNameController.text.isEmpty ||
        selectedDate == null ||
        selectedStatus.isEmpty) {
      return;
    }

    // ✅ Generate a fresh UUID each time
    final newUUID = const Uuid().v4();

    setState(() {
      qrData = newUUID;
    });
  }

  Future<Uint8List?> _captureQRImage() async {
    try {
      final boundary =
          qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print("Error capturing image: $e");
      return null;
    }
  }

  Future<void> _uploadQR() async {
    if (qrData == null || qrData!.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    try {
      final pngBytes = await _captureQRImage();
      if (pngBytes == null) return;

      final fileName =
          "${eventNameController.text}_${DateTime.now().millisecondsSinceEpoch}.png";
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('qrcodes/${currentUser.uid}/$fileName');

      await storageRef.putData(pngBytes);
      final downloadUrl = await storageRef.getDownloadURL();

      final dbRef = FirebaseDatabase.instance.ref("Event Gallery App/events");
      final eventDate =
          "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}";

      await dbRef.child(qrData!).set({
        "Event Name": eventNameController.text.trim(),
        "event date": eventDate,
        "Status": selectedStatus,
        "QRcode image": downloadUrl,
        "Event_id": qrData!,
        "Gallery": [],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("QR Code saved to database successfully")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving QR code: $e")),
      );
    }
  }

  Future<void> _shareQR() async {
    final pngBytes = await _captureQRImage();
    if (pngBytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/${eventNameController.text}.png')
        .create();
    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'QR Code for ${eventNameController.text}',
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = selectedDate == null
        ? "Pick a date"
        : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}";

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/eventbg.jpeg"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text("QR Generator"),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: eventNameController,
                    decoration: const InputDecoration(labelText: 'Event Name'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("Event Date:"),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _pickDate,
                        child: Text(formattedDate),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    items: statusOptions
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedStatus = value;
                        });
                      }
                    },
                    decoration:
                        const InputDecoration(labelText: 'Event Status'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _generateAndSaveQR,
                    child: const Text("Generate QR"),
                  ),
                  const SizedBox(height: 20),
                  if (qrData != null && qrData!.isNotEmpty)
                    RepaintBoundary(
                      key: qrKey,
                      child: QrImageView(
                        data: qrData!,
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (qrData != null && qrData!.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _uploadQR,
                          child: const Text("Upload QR"),
                        ),
                        ElevatedButton(
                          onPressed: _shareQR,
                          child: const Text("Share QR"),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
