import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:edge_detection/edge_detection.dart';

class DocumentScanningScreen extends StatefulWidget {
  const DocumentScanningScreen({super.key});

  @override
  State<DocumentScanningScreen> createState() => _DocumentScanningScreenState();
}

class _DocumentScanningScreenState extends State<DocumentScanningScreen> {
  File? _scannedImage;
  bool _isLoading = false;

  Future<void> _scanDocument() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw Exception('Camera permission not granted');
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final String imagePath = path.join(
          directory.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Scan document using edge_detection
      final bool success = await EdgeDetection.detectEdge(
        imagePath,
        canUseGallery: false,
        androidScanTitle: 'Scan Document',
        androidCropTitle: 'Crop Document',
        androidCropBlackWhiteTitle: 'Black & White',
        androidCropReset: 'Reset',
      );

      if (success) {
        setState(() {
          _scannedImage = File(imagePath);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning document: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_scannedImage != null) ...[
                    Image.file(
                      _scannedImage!,
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                  ],
                  ElevatedButton(
                    onPressed: _scanDocument,
                    child: const Text('Scan Document'),
                  ),
                ],
              ),
      ),
    );
  }
}
