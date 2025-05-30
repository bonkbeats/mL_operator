import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:image/image.dart' as img_pkg;
import 'package:image_picker/image_picker.dart';
import 'package:edge_detection/edge_detection.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import '../services/image_comparison_service.dart';
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
  final ImageComparisonService _comparisonService = ImageComparisonService();
  final bool _isLoading = false;
  String? _tempStoredImagePath;
  double? _similarity;

  Future<void> detectEdgeImage({bool fromGallery = false}) async {
    if (fromGallery) {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        img_pkg.Image? original = img_pkg.decodeImage(bytes);
        if (original != null) {
          final processedBytes = img_pkg.encodeJpg(original);
          final directory = await getApplicationSupportDirectory();
          final imagePath = path_util.join(
              directory.path, "${DateTime.now().millisecondsSinceEpoch}.jpeg");
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
                _similarity = null;
              });
            }
          });
        }
      }
      return;
    }

    // Camera capture with document scanner
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

    final directory = await getTemporaryDirectory();
    final String imagePath = path_util.join(
        directory.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");

    final bool success = await EdgeDetection.detectEdge(
      imagePath,
      canUseGallery: false,
      androidScanTitle: 'Scan Document',
      androidCropTitle: 'Crop Document',
      androidCropBlackWhiteTitle: 'Black & White',
      androidCropReset: 'Reset',
    );

    if (success == true) {
      final bytes = await File(imagePath).readAsBytes();
      img_pkg.Image? original = img_pkg.decodeImage(bytes);

      if (original != null) {
        final processedBytes = img_pkg.encodeJpg(original);
        final directory = await getApplicationSupportDirectory();
        final imagePath = path_util.join(
            directory.path, "${DateTime.now().millisecondsSinceEpoch}.jpeg");
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
              _similarity = null;
            });
          }
        });
      }
    }
  }

  Future<void> _setAsReferenceImage() async {
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture or pick an image first.')),
      );
      return;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = path_util.basename(_imagePath!);
      final newTempPath = path_util.join(tempDir.path, 'ref_$fileName');
      final File tempFile = File(newTempPath);
      await File(_imagePath!).copy(tempFile.path);
      setState(() {
        _tempStoredImagePath = tempFile.path;
        _similarity = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image set as reference for comparison.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error setting image as reference: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteReferenceImage() async {
    if (_tempStoredImagePath == null) return;
    try {
      final fileToDelete = File(_tempStoredImagePath!);
      if (await fileToDelete.exists()) {
        await fileToDelete.delete();
        setState(() {
          _tempStoredImagePath = null;
          _similarity = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reference image deleted.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error deleting reference image: ${e.toString()}')),
      );
    }
  }

  Future<void> _compareImages() async {
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture or pick an image first.')),
      );
      return;
    }
    if (_tempStoredImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please set a reference image for comparison first.')),
      );
      return;
    }
    try {
      final similarity = await _comparisonService.computeSimilarity(
        File(_imagePath!),
        File(_tempStoredImagePath!),
      );
      setState(() {
        _similarity = similarity;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error comparing images: ${e.toString()}')),
      );
      setState(() {
        _similarity = null;
      });
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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          if (_imagePath != null) ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () async => await _saveImage(),
            ),
            IconButton(
              icon: const Icon(Icons.compare),
              onPressed: () async => await _compareImages(),
            ),
            IconButton(
              icon: const Icon(Icons.star),
              onPressed: () async => await _setAsReferenceImage(),
            ),
            if (_tempStoredImagePath != null)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async => await _deleteReferenceImage(),
              ),
          ],
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                                "Dimensions: $_imageWidth x $_imageHeight",
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
                        if (_similarity != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Similarity: ${(_similarity! * 100).toStringAsFixed(2)}%',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
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
