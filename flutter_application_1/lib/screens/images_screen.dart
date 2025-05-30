import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({Key? key}) : super(key: key);

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  final StorageService _storageService = StorageService();
  List<Map<String, dynamic>> _allUserImagesMetadata = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception('No authentication token');

      // Fetch all user image metadata from backend
      final allImages = await _storageService.getLocalImages(token);
      setState(() {
        _allUserImagesMetadata = allImages; // Store all metadata
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading images: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSaveDialog(String imageUrl) async {
    // This dialog is typically for saving cloud images locally.
    // The logic here might need adjustment based on if the cloud image is already linked to a local file via metadata.
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
                // You would need to fetch the image bytes from the imageUrl
                // and then save them to a file, similar to the initial capture save.
                // This might require a new method in StorageService or handling here.
                // For now, let's just show a message that this functionality needs implementation.
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

  // The _saveImageLocally method here seems intended for saving a cloud image URL's content locally.
  // This is different from the saveImageLocally on the Home screen which saves a captured File.
  // Let's rename this or rethink this flow.
  // For now, I will comment out the body as the dialog has a placeholder message.
  /*
  Future<void> _saveImageLocallyFromUrl(String imageUrl) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception('No authentication token');

      // This method needs to fetch the image from the URL and save it as a new local file.
      // The existing saveImageLocally in StorageService saves a File object.
      // You would need to download the image bytes from imageUrl first.
      // await _storageService.saveImageLocally(File(imageUrl), token);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved successfully')), // This message is misleading now
      );
      _loadImages(); // Refresh the image list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e')), // This error message is misleading now
      );
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    // Filter images based on upload status for tabs
    final localOnlyImages = _allUserImagesMetadata
        .where(
            (img) => !(img['isUploaded'] ?? false) && img['localPath'] != null)
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadImages,
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
                        _buildImagesGrid(localOnlyImages,
                            isLocalTab: true), // Pass filtered list
                        _buildImagesGrid(uploadedImages,
                            isLocalTab: false), // Pass filtered list
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Unified method to build image grids for both tabs
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

        // Decide which image to display and what actions are available
        if (isLocalTab && localPath != null) {
          // Display local image and offer upload/delete local
          return _buildImageCard(image, File(localPath));
        } else if (!isLocalTab && supabaseUrl != null) {
          // Display cloud image and offer download/delete cloud (from metadata)
          return _buildCloudImageCard(image, supabaseUrl);
        } else if (isLocalTab && supabaseUrl != null) {
          // Local tab, but only cloud URL available (e.g., local deleted after sync)
          // Display cloud image (linked via metadata) and maybe offer download locally
          return _buildCloudImageCard(
              image, supabaseUrl); // Display cloud if local missing
        } else {
          // Should not happen often with correct data, but handle defensively
          return const Card(
            child: Center(
                child:
                    Text('Invalid image data')), // Placeholder for invalid data
          );
        }
      },
    );
  }

  // Updated to accept image metadata map and File
  Widget _buildImageCard(Map<String, dynamic> imageMetadata, File imageFile) {
    final imageId =
        imageMetadata['_id'] as String?; // Assuming _id is returned by backend
    if (imageId == null) {
      return const SizedBox.shrink(); // Cannot delete without ID
    }

    return GestureDetector(
      onTap: () => _showImagePreview(imageFile), // Preview local file
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(imageFile, fit: BoxFit.cover), // Display local file
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
                    // Option to upload if not already uploaded (check metadata?)
                    if (!(imageMetadata['isUploaded'] ?? false))
                      IconButton(
                        icon:
                            const Icon(Icons.cloud_upload, color: Colors.white),
                        onPressed: () => _uploadToCloud(
                            imageFile), // Use existing upload method
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () =>
                          _deleteImage(imageId), // Pass MongoDB ID for deletion
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

  // Updated to accept image metadata map and URL string
  Widget _buildCloudImageCard(
      Map<String, dynamic> imageMetadata, String imageUrl) {
    final imageId =
        imageMetadata['_id'] as String?; // Assuming _id is returned by backend
    if (imageId == null) {
      return const SizedBox.shrink(); // Cannot delete without ID
    }

    return GestureDetector(
      onTap: () =>
          _showSaveDialog(imageUrl), // Option to save cloud image locally
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(imageUrl, fit: BoxFit.cover), // Display network image
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
                      onPressed: () => _showSaveDialog(
                          imageUrl), // Trigger save locally dialog
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () =>
                          _deleteImage(imageId), // Pass MongoDB ID for deletion
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
              Image.file(imageFile), // Preview local file
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

  // Updated delete method to take MongoDB image ID
  Future<void> _deleteImage(String imageId) async {
    print('Attempting to delete image with ID: $imageId');
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      print('Delete failed: No authentication token.');
      return;
    }
    try {
      // Delete metadata from MongoDB via backend
      await _storageService.deleteImage(imageId, token);

      // Optionally, delete the file from Supabase if uploaded
      final imageMetadata = _allUserImagesMetadata
          .firstWhere((img) => img['_id'] == imageId, orElse: () => {});
      final supabaseUrl = imageMetadata['supabaseUrl'] as String?;
      if (supabaseUrl != null) {
        print('Deleting corresponding Supabase file for $imageId...');
        // You would need a method in StorageService to delete from Supabase by URL or path.
        // This might involve extracting the path from the URL.
        // For now, just log and indicate it needs implementation.
        print('Supabase file deletion not fully implemented yet.');
        // await _storageService.deleteSupabaseFile(supabaseUrl, token); // Needs implementation
      }

      // Optionally, delete the local file if it exists
      final localPath = imageMetadata['localPath'] as String?;
      if (localPath != null && await File(localPath).exists()) {
        print('Deleting local file for $imageId...');
        await File(localPath).delete();
        print('Local file deleted.');
      }

      // Update the local list of images metadata
      setState(() {
        _allUserImagesMetadata.removeWhere((img) => img['_id'] == imageId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Image deleted successfully')), // Confirm deletion
      );
      // No need to _loadImages() again as state is updated locally
    } catch (e) {
      print('Error deleting image $imageId: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting image: $e')),
      );
    }
  }

  // _deleteCloudImage is no longer needed as deletion is handled by _deleteImage based on metadata
  /*
  Future<void> _deleteCloudImage(String imageUrl) async {
    // Implement cloud image deletion
  }
  */

  Future<void> _uploadToCloud(File imageFile) async {
    print('Attempting to upload image from ImagesScreen...');

    // Show loading dialog
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
      final user = context.read<AuthProvider>().user;
      if (user == null) {
        print('Upload failed: User not authenticated.');
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to upload images')),
        );
        return;
      }

      // Check if file still exists
      if (!await imageFile.exists()) {
        print('Upload failed: Local file no longer exists');
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image file not found')),
        );
        return;
      }

      final isConnected = await _storageService.isConnected();
      if (!isConnected) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
        print('Upload failed: No internet connection.');
        return;
      }

      // Find the metadata for this local file to get its MongoDB ID
      final imageMetadata = _allUserImagesMetadata.firstWhere(
          (img) => img['localPath'] == imageFile.path,
          orElse: () => {});

      final imageId = imageMetadata['_id'] as String?;
      final userId = user['id'] as String?;

      if (imageId == null || userId == null) {
        Navigator.of(context).pop(); // Close loading dialog
        print(
            'Upload failed: Could not find metadata or userId for local file ${imageFile.path}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not find image metadata for upload.')),
        );
        return;
      }

      print('Found metadata $imageId. Uploading to Supabase...');
      final supabaseUrl = await _storageService.saveImageToSupabase(
        imageFile.path, // Pass the file path (String)
        userId,
        imageId, // Pass the imageId (String)
      );

      // Update metadata in MongoDB with Supabase URL and isUploaded: true
      print('Upload successful. Updating metadata $imageId...');
      await _storageService.updateImageUrl(
          imageId: imageId,
          supabaseUrl: supabaseUrl,
          token: context.read<AuthProvider>().token!);
      print('Metadata update successful.');

      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully')),
      );
      _loadImages(); // Refresh the image list to reflect upload status
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }
}
