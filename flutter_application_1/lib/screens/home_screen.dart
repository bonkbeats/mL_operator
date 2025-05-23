import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edge_detection/edge_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:image/image.dart' as img_pkg;
import 'dart:io';
import 'dart:ui' as ui;
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';
import 'images_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _imagePath;
  int? _imageWidth;
  int? _imageHeight;
  double? _aspectRatio;
  bool _isA4 = false;
  final StorageService _storageService = StorageService();

  Future<void> detectEdgeImage({bool fromGallery = false}) async {
    bool isCameraGranted = await Permission.camera.request().isGranted;
    if (!isCameraGranted) {
      isCameraGranted =
          await Permission.camera.request() == PermissionStatus.granted;
    }

    if (!isCameraGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission denied')),
        );
      }
      return;
    }

    final directory = await getApplicationSupportDirectory();
    final imagePath = path_util.join(
        directory.path, "${DateTime.now().millisecondsSinceEpoch}.jpeg");

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
      final bytes = await File(imagePath).readAsBytes();
      img_pkg.Image? original = img_pkg.decodeImage(bytes);
      if (original != null) {
        img_pkg.Image denoised = img_pkg.gaussianBlur(original, radius: 1);
        img_pkg.Image enhanced = img_pkg.adjustColor(denoised, contrast: 1.2);

        final processedBytes = img_pkg.encodeJpg(enhanced);
        await File(imagePath).writeAsBytes(processedBytes);

        ui.decodeImageFromList(processedBytes, (ui.Image img) {
          final aspectRatio = img.width / img.height;
          final isA4 = aspectRatio >= .68 && aspectRatio <= .75;

          if (mounted) {
            setState(() {
              _imagePath = imagePath;
              _imageWidth = img.width;
              _imageHeight = img.height;
              _aspectRatio = aspectRatio;
              _isA4 = isA4;
            });
          }
        });
      }
    }
  }

  Future<void> _saveImage() async {
    if (_imagePath == null) return;

    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) return;

      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      final result = await _storageService.saveImageLocally(
        File(_imagePath!),
        token,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved successfully')),
      );

      // Try to sync to cloud if online
      await _storageService.syncImagesToCloud(token);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImagesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      drawer: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final user = auth.user;
          if (user == null) {
            return const Drawer(
              child: Center(child: Text('No user data available')),
            );
          }

          return Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(user['username'] ?? ''),
                  accountEmail: Text(user['email'] ?? ''),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      (user['username'] ?? '')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profile'),
                  subtitle: Text('Role: ${user['role']}'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('My Images'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ImagesScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    // TODO: Implement settings screen
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () async {
                    Navigator.pop(context);
                    await context.read<AuthProvider>().logout();
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Document Scanner',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_imagePath != null && File(_imagePath!).existsSync())
              Column(
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
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _saveImage,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Image'),
                  ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No image captured yet."),
              ),
          ],
        ),
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
