import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart' as qr;
import 'package:zxing2/qrcode.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  qr.QRViewController? controller;
  bool showCamera = true;
  bool isProcessing = false;

  void _onQRViewCreated(qr.QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (isProcessing) return;
      isProcessing = true;
      controller.pauseCamera();

      final scannedCode = scanData.code ?? '';
      if (scannedCode.isNotEmpty) {
        await _fetchEventAndNavigate(scannedCode);
      } else {
        isProcessing = false;
        controller.resumeCamera();
      }
    });
  }

  Future<void> _fetchEventAndNavigate(String eventUUID) async {
    final dbRef = FirebaseDatabase.instance.ref('events/$eventUUID');
    try {
      final snapshot = await dbRef.get();
      if (snapshot.exists) {
        final eventData = Map<String, dynamic>.from(snapshot.value as Map);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(eventData: eventData),
          ),
        );
      } else {
        _showError('Event not found for this QR code.');
        controller?.resumeCamera();
      }
    } catch (e) {
      _showError('Error fetching event details.');
      controller?.resumeCamera();
    } finally {
      isProcessing = false;
    }
  }

  Future<void> _pickImageAndScan() async {
    if (isProcessing) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      showCamera = false;
      isProcessing = true;
    });

    try {
      final Uint8List imageBytes = await pickedFile.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        _showError('Could not decode image.');
        setState(() => showCamera = true);
        return;
      }

      final luminanceSource = RGBLuminanceSource(
        decodedImage.width,
        decodedImage.height,
        decodedImage.getBytes().buffer.asInt32List(), // ✅ Corrected line
      );

      final bitmap = BinaryBitmap(HybridBinarizer(luminanceSource));
      final result = QRCodeReader().decode(bitmap);

      final scannedCode = result.text;
      if (scannedCode.isNotEmpty) {
        await _fetchEventAndNavigate(scannedCode);
      } else {
        _showError('No QR code found in the selected image.');
        setState(() => showCamera = true);
      }
    } catch (e) {
      _showError('Failed to scan QR from image.');
      setState(() => showCamera = true);
    } finally {
      isProcessing = false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event QR Scanner')),
      body: Column(
        children: [
          if (showCamera)
            Expanded(
              flex: 5,
              child: qr.QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: qr.QrScannerOverlayShape(
                  borderColor: Colors.green,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: 250,
                ),
              ),
            )
          else
            const Expanded(
              flex: 5,
              child: Center(child: Text('Image scanned from gallery')),
            ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImageAndScan,
                  icon: const Icon(Icons.image),
                  label: const Text('Upload QR from Gallery'),
                ),
                if (!showCamera)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showCamera = true;
                      });
                      controller?.resumeCamera();
                    },
                    child: const Text('Switch back to Camera'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
