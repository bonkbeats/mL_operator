import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({Key? key}) : super(key: key);

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  final StorageService _storageService = StorageService();
  List<Map<String, dynamic>> _allUserImagesMetadata = [];
  bool _isLoading = true;
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _loadImages();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        _syncOfflineImages();
      }
    });
  }

  Future<void> _syncOfflineImages() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      await _storageService.syncOfflineImages(token);
      _loadImages(); // Reload images after sync
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing offline images: $e')),
        );
      }
    }
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception('No authentication token');

      List<Map<String, dynamic>> allImages = [];

      // Try to load images from backend if online
      if (await _storageService.isConnected()) {
        try {
          allImages = await _storageService.getLocalImages(token);
        } catch (e) {
          print('Error loading from backend: $e');
          // Continue with local images even if backend fails
        }
      }

      // Load offline images
      final offlineDataDir = await getApplicationDocumentsDirectory();
      final offlineDataFile =
          File('${offlineDataDir.path}/offline_images.json');
      List<Map<String, dynamic>> offlineImages = [];

      if (await offlineDataFile.exists()) {
        final content = await offlineDataFile.readAsString();
        offlineImages = List<Map<String, dynamic>>.from(json.decode(content));
      }

      // Load local images from documents directory
      final localDir = await getApplicationDocumentsDirectory();
      final localFiles = await localDir.list().toList();
      final localImages = localFiles
          .where((file) =>
              file.path.toLowerCase().endsWith('.jpg') ||
              file.path.toLowerCase().endsWith('.jpeg') ||
              file.path.toLowerCase().endsWith('.png'))
          .map((file) => {
                '_id': _uuid.v4(),
                'localPath': file.path,
                'isUploaded': false,
                'createdAt': DateTime.now().toIso8601String(),
                'isLocalOnly': true,
              })
          .toList();

      // Combine all images, ensuring no duplicates
      final Set<String> processedPaths = {};
      final List<Map<String, dynamic>> combinedImages = [];

      // Helper function to add image if not already processed
      void addIfNotProcessed(Map<String, dynamic> image) {
        final path = image['localPath'] as String?;
        if (path != null && !processedPaths.contains(path)) {
          processedPaths.add(path);
          combinedImages.add(image);
        }
      }

      // Add images in priority order: local files first, then offline metadata, then backend
      for (var image in localImages) {
        addIfNotProcessed(image);
      }
      for (var image in offlineImages) {
        addIfNotProcessed(image);
      }
      for (var image in allImages) {
        addIfNotProcessed(image);
      }

      setState(() {
        _allUserImagesMetadata = combinedImages;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading images: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSaveDialog(String imageUrl) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Image Locally'),
          content: const Text('Do you want to save this image locally?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // TODO: Implement download and local save from URL if needed
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Save locally from URL not implemented yet.')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update the filtering logic to properly handle local images
    final localOnlyImages = _allUserImagesMetadata
        .where((img) =>
            (img['localPath'] != null) &&
            (!(img['isUploaded'] ?? false) || img['isLocalOnly'] == true))
        .toList();

    final uploadedImages = _allUserImagesMetadata
        .where(
            (img) => (img['isUploaded'] ?? false) && img['supabaseUrl'] != null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Images'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _showClearLocalStorageDialog,
            tooltip: 'Clear Local Storage',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadImages,
            tooltip: 'Refresh Images',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Local Images'),
                      Tab(text: 'Cloud Images'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildImagesGrid(localOnlyImages, isLocalTab: true),
                        _buildImagesGrid(uploadedImages, isLocalTab: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildImagesGrid(List<Map<String, dynamic>> images,
      {required bool isLocalTab}) {
    if (images.isEmpty) {
      return Center(
          child: Text('No ${isLocalTab ? 'local' : 'cloud'} images found'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final localPath = image['localPath'] as String?;
        final supabaseUrl = image['supabaseUrl'] as String?;

        if (isLocalTab && localPath != null) {
          return _buildImageCard(image, File(localPath));
        } else if (!isLocalTab && supabaseUrl != null) {
          return _buildCloudImageCard(image, supabaseUrl);
        } else if (isLocalTab && supabaseUrl != null) {
          return _buildCloudImageCard(image, supabaseUrl);
        } else {
          return const Card(
            child: Center(child: Text('Invalid image data')),
          );
        }
      },
    );
  }

  Widget _buildImageCard(Map<String, dynamic> imageMetadata, File imageFile) {
    final imageId = imageMetadata['_id'] as String?;
    final isLocalOnly = imageMetadata['isLocalOnly'] as bool? ?? false;
    final isUploaded = imageMetadata['isUploaded'] as bool? ?? false;

    return GestureDetector(
      onTap: () => _showImagePreview(imageFile),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(imageFile, fit: BoxFit.cover),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (!isUploaded)
                      IconButton(
                        icon:
                            const Icon(Icons.cloud_upload, color: Colors.white),
                        onPressed: () => _uploadToCloud(imageFile),
                        tooltip: 'Upload to cloud',
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () => _deleteImage(imageId ?? ''),
                      tooltip: 'Delete image',
                    ),
                  ],
                ),
              ),
            ),
            if (isLocalOnly)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Local Only',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudImageCard(
      Map<String, dynamic> imageMetadata, String imageUrl) {
    final imageId = imageMetadata['_id'] as String?;
    if (imageId == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _showSaveDialog(imageUrl),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(imageUrl, fit: BoxFit.cover),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: () => _showSaveDialog(imageUrl),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () => _deleteImage(imageId),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(File imageFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(imageFile),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteImage(String imageId) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to delete images')),
        );
        return;
      }

      // Find the image metadata
      final imageMetadata = _allUserImagesMetadata
          .firstWhere((img) => img['_id'] == imageId, orElse: () => {});

      if (imageMetadata.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image not found')),
        );
        return;
      }

      // Delete local file if it exists
      final localPath = imageMetadata['localPath'] as String?;
      if (localPath != null) {
        final localFile = File(localPath);
        if (await localFile.exists()) {
          await localFile.delete();
        }
      }

      // If it's a cloud image, try to delete from backend
      if (imageMetadata['isUploaded'] == true) {
        try {
          await _storageService.deleteImage(imageId, token);
        } catch (e) {
          print('Error deleting from backend: $e');
          // Continue with local cleanup even if backend delete fails
        }
      }

      // Remove from offline images if it exists there
      final offlineDataDir = await getApplicationDocumentsDirectory();
      final offlineDataFile =
          File('${offlineDataDir.path}/offline_images.json');
      if (await offlineDataFile.exists()) {
        final content = await offlineDataFile.readAsString();
        final offlineImages =
            List<Map<String, dynamic>>.from(json.decode(content));
        final updatedOfflineImages =
            offlineImages.where((img) => img['_id'] != imageId).toList();
        await offlineDataFile.writeAsString(json.encode(updatedOfflineImages));
      }

      // Update UI
      if (mounted) {
        setState(() {
          _allUserImagesMetadata.removeWhere((img) => img['_id'] == imageId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting image: $e')),
        );
      }
    }
  }

  Future<void> _uploadToCloud(File imageFile) async {
    if (!await _storageService.isConnected()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No internet connection. Please try again when online.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to upload images')),
        );
        return;
      }

      // Save image metadata to MongoDB
      final result = await _storageService.saveImageLocally(imageFile, token);
      final metadata = result['metadata'];

      // Upload to Supabase
      final supabaseUrl = await _storageService.saveImageToSupabase(
        imageFile.path,
        metadata['userId'],
        metadata['_id'],
      );

      // Update MongoDB with Supabase URL
      await _storageService.updateImageUrl(
        imageId: metadata['_id'],
        supabaseUrl: supabaseUrl,
        token: token,
      );

      // Delete the local file after successful upload
      if (await imageFile.exists()) {
        await imageFile.delete();
        print('Deleted local file after successful upload: ${imageFile.path}');
      }

      // Remove from offline images if it exists there
      final offlineDataDir = await getApplicationDocumentsDirectory();
      final offlineDataFile =
          File('${offlineDataDir.path}/offline_images.json');
      if (await offlineDataFile.exists()) {
        final content = await offlineDataFile.readAsString();
        final offlineImages =
            List<Map<String, dynamic>>.from(json.decode(content));
        final updatedOfflineImages = offlineImages
            .where((img) => img['localPath'] != imageFile.path)
            .toList();
        await offlineDataFile.writeAsString(json.encode(updatedOfflineImages));
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Image uploaded successfully and removed from local storage')),
      );
      _loadImages(); // Reload images after upload
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  Future<void> _showClearLocalStorageDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Local Storage'),
          content: const Text(
            'This will delete all locally stored images that haven\'t been uploaded to the cloud. This action cannot be undone. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _clearLocalStorage();
    }
  }

  Future<void> _clearLocalStorage() async {
    try {
      setState(() => _isLoading = true);

      // Get the local directory
      final localDir = await getApplicationDocumentsDirectory();

      // Delete all image files
      final files = await localDir.list().toList();
      for (var file in files) {
        if (file.path.toLowerCase().endsWith('.jpg') ||
            file.path.toLowerCase().endsWith('.jpeg') ||
            file.path.toLowerCase().endsWith('.png')) {
          await File(file.path).delete();
        }
      }

      // Delete offline images metadata file
      final offlineDataFile = File('${localDir.path}/offline_images.json');
      if (await offlineDataFile.exists()) {
        await offlineDataFile.delete();
      }

      // Update the UI
      setState(() {
        _allUserImagesMetadata = _allUserImagesMetadata
            .where((img) => img['isUploaded'] == true)
            .toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local storage cleared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing local storage: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
