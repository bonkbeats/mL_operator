import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:edge_detection/edge_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:image/image.dart' as img_pkg;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edge Detection Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const EdgeDetectionScreen(),
    );
  }
}

class EdgeDetectionScreen extends StatefulWidget {
  const EdgeDetectionScreen({super.key});

  @override
  State<EdgeDetectionScreen> createState() => _EdgeDetectionScreenState();
}

class _EdgeDetectionScreenState extends State<EdgeDetectionScreen> {
  String? _imagePath;
  int? _imageWidth;
  int? _imageHeight;
  double? _aspectRatio;
  bool _isA4 = false; // Add this variable

  Future<void> detectEdgeImage({bool fromGallery = false}) async {
    bool isCameraGranted = await Permission.camera.request().isGranted;
    if (!isCameraGranted) {
      isCameraGranted =
          await Permission.camera.request() == PermissionStatus.granted;
    }

    if (!isCameraGranted) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
      return;
    }

    final directory = await getApplicationSupportDirectory();
    final imagePath =
        join(directory.path, "${DateTime.now().millisecondsSinceEpoch}.jpeg");

    bool success = false;
    try {
      if (fromGallery) {
        success = await EdgeDetection.detectEdgeFromGallery(
          imagePath,
          androidCropTitle: 'Crop',
          androidCropBlackWhiteTitle: 'Black White',
          androidCropReset: 'Reset',
        );
      } else {
        success = await EdgeDetection.detectEdge(
          imagePath,
          canUseGallery: true,
          androidScanTitle: 'Scanning',
          androidCropTitle: 'Crop',
          androidCropBlackWhiteTitle: 'Black White',
          androidCropReset: 'Reset',
        );
      }
    } catch (e) {
      debugPrint("Edge detection error: $e");
    }

    if (success) {
      // Get image bytes
      final bytes = await File(imagePath).readAsBytes();

      // Decode and process with image package
      img_pkg.Image? original = img_pkg.decodeImage(bytes);
      if (original != null) {
        // Apply Gaussian blur to reduce noise
        img_pkg.Image denoised = img_pkg.gaussianBlur(original, radius: 1);

        // Optionally, enhance contrast or sharpen
        img_pkg.Image enhanced = img_pkg.adjustColor(denoised, contrast: 1.2);
        // img_pkg.Image sharpened = img_pkg.sharpen(enhanced, amount: 1);

        // Encode back to JPEG
        final processedBytes = img_pkg.encodeJpg(enhanced);

        // Overwrite the file with the processed image
        await File(imagePath).writeAsBytes(processedBytes);

        // Now use the processed image for display and dimension calculation
        ui.decodeImageFromList(processedBytes, (ui.Image img) {
          final aspectRatio = img.width / img.height;
          final isA4 = aspectRatio >= .68 && aspectRatio <= .75;

          setState(() {
            _imagePath = imagePath;
            _imageWidth = img.width;
            _imageHeight = img.height;
            _aspectRatio = aspectRatio;
            _isA4 = isA4;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edge Detection")),
      body: Center(
        child: _imagePath != null && File(_imagePath!).existsSync()
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.file(File(_imagePath!)),
                  const SizedBox(height: 16),
                  if (_imageWidth != null && _imageHeight != null)
                    Column(
                      children: [
                        Text(
                          "Dimensions: ${_imageWidth} x ${_imageHeight}",
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (_aspectRatio != null)
                          Text(
                            "Aspect Ratio: ${_aspectRatio!.toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 16),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          _isA4
                              ? "This image is close to A4 size."
                              : "This image is NOT A4 size.",
                          style: TextStyle(
                            fontSize: 16,
                            color: _isA4 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              )
            : const Text("No image captured yet."),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'camera',
            onPressed: () => detectEdgeImage(fromGallery: false),
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: () => detectEdgeImage(fromGallery: true),
            child: const Icon(Icons.photo_library),
          ),
        ],
      ),
    );
  }
}
