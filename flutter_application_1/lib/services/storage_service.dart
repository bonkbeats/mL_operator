import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class StorageService {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get bucketName => dotenv.env['SUPABASE_BUCKET_NAME'] ?? '';
  static String get apiUrl => dotenv.env['API_URL'] ?? '';

  final SupabaseClient _supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);
  final _uuid = const Uuid();

  // Initialize Supabase
  static Future<void> initialize() async {
    await dotenv.load();
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Save image locally and create metadata entry in MongoDB
  Future<Map<String, dynamic>> saveImageLocally(
      File imageFile, String token) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${_uuid.v4()}.jpg';
    final savedImage = File('${directory.path}/$fileName');
    await imageFile.copy(savedImage.path);

    // Create metadata entry in MongoDB
    final response = await http.post(
      Uri.parse('$apiUrl/images'), // Use /images route for metadata
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'localPath': savedImage.path,
        // isUploaded will default to false in the backend model
      }),
    );

    if (response.statusCode != 201) {
      // If backend saving fails, we still saved locally. Maybe log the error.
      print(
          'Backend metadata save failed: ${response.statusCode} - ${response.body}');
      // Optionally, throw an exception or return a result indicating partial failure
      throw Exception('Failed to save image metadata to backend');
    }
    final metadata = json.decode(response.body);

    return {
      'localPath': savedImage.path,
      'metadata': metadata,
    };
  }

  // Sync non-uploaded local images to Supabase and update metadata in MongoDB
  Future<void> syncImagesToCloud(String token) async {
    print('Attempting to sync images to cloud...');
    if (!await isConnected()) {
      print('Offline. Skipping cloud sync.');
      return;
    }
    print('Online. Proceeding with cloud sync.');

    try {
      // Get all user images from MongoDB via backend
      // We need images that are NOT uploaded to Supabase.
      // Assuming backend GET /api/images/user returns all images and we filter here.
      // Ideally, your backend would have an endpoint to get non-uploaded images.
      final allUserImagesResponse = await http.get(
        Uri.parse('$apiUrl/images/user'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (allUserImagesResponse.statusCode != 200) {
        print(
            'Failed to fetch user images for sync: ${allUserImagesResponse.statusCode} - ${allUserImagesResponse.body}');
        return; // Cannot sync if we can't get the list
      }

      final List<dynamic> imagesData = json.decode(allUserImagesResponse.body);
      final nonUploadedImages =
          imagesData.where((image) => !(image['isUploaded'] ?? false)).toList();

      print('Found ${nonUploadedImages.length} non-uploaded images.');

      for (var image in nonUploadedImages) {
        final localPath = image['localPath'];
        final imageId = image['_id']; // Assuming your backend returns _id
        final userId = image['userId']; // Assuming your backend returns userId

        if (localPath == null || imageId == null || userId == null) {
          print('Skipping sync for image with missing metadata: $image');
          continue;
        }

        final file = File(localPath);
        if (!await file.exists()) {
          print('Local file not found for sync: $localPath');
          // Optionally, update backend to mark this as failed sync or remove the metadata entry
          continue;
        }

        try {
          print('Uploading image $imageId to Supabase...');
          final supabaseUrl =
              await saveImageToSupabase(localPath, userId, imageId);
          print('Upload successful: $supabaseUrl');

          // Update MongoDB with Supabase URL and set isUploaded to true
          print('Updating metadata for image $imageId in MongoDB...');
          final updateResponse = await http.put(
            Uri.parse('$apiUrl/images/url'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'imageId': imageId,
              'supabaseUrl': supabaseUrl,
            }),
          );

          if (updateResponse.statusCode == 200) {
            print('Metadata update successful for $imageId');
            // Optionally delete local file after successful sync
            // await file.delete();
            // print('Deleted local file: $localPath');
          } else {
            print(
                'Failed to update metadata for $imageId: ${updateResponse.statusCode} - ${updateResponse.body}');
          }
        } catch (e) {
          print('Error during sync process for $imageId: $e');
          // Continue with next image even if one fails
        }
      }
      print('Cloud sync process finished.');
    } catch (e) {
      print('Error fetching non-uploaded images for sync: $e');
    }
  }

  // Method to upload image to Supabase Storage
  Future<String> saveImageToSupabase(
      String localPath, String userId, String imageId) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Local image file not found at $localPath');
    }

    final fileName =
        '${userId}_${imageId}_${DateTime.now().millisecondsSinceEpoch}.${file.path.split('.').last}';
    final storagePath = 'user_images/$userId/$fileName';

    try {
      // The upload method throws StorageException on error
      await _supabase.storage
          .from(bucketName)
          .upload(storagePath, file, retryAttempts: 3);

      // getPublicUrl returns a String (the URL) directly
      final publicUrl =
          _supabase.storage.from(bucketName).getPublicUrl(storagePath);
      print('Upload successful, public URL: $publicUrl');
      return publicUrl;
    } on StorageException catch (e) {
      print('Supabase upload StorageException: ${e.message}');
      rethrow;
    } catch (e) {
      print('Supabase upload generic exception: $e');
      rethrow;
    }
  }

  // Check internet connectivity
  Future<bool> isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Connectivity check error: $e');
      return false;
    }
  }

  // Get all user images metadata from MongoDB via backend
  Future<List<Map<String, dynamic>>> getLocalImages(String token) async {
    print('Fetching user images from backend...');
    final response = await http.get(
      Uri.parse('$apiUrl/images/user'), // Use /images/user route
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      print(
          'Failed to load images from backend: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to load images');
    }
    print('Successfully fetched user images metadata.');
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  // Admin function to get all users metadata from MongoDB via backend
  Future<List<Map<String, dynamic>>> getAllUsers(String token) async {
    print('Fetching all users from backend...');
    final response = await http.get(
      Uri.parse('$apiUrl/auth/users'), // Use /auth/users route
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      print(
          'Failed to load users from backend: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to load users');
    }
    print('Successfully fetched all users metadata.');
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  // Admin function to get images for admin view from MongoDB via backend
  Future<List<Map<String, dynamic>>> getAdminImages(String token,
      {String? userId}) async {
    print('Fetching admin images from backend...');
    String url = '$apiUrl/images/admin';
    if (userId != null) {
      url += '?userId=$userId';
    }

    final response = await http.get(
      Uri.parse(url), // Use /images/admin route
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      print(
          'Failed to load admin images from backend: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to load admin images');
    }
    print('Successfully fetched admin images metadata.');
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  // Delete image metadata from MongoDB via backend
  Future<void> deleteImage(String imageId, String token) async {
    print('Attempting to delete image metadata $imageId...');
    final response = await http.delete(
      Uri.parse('$apiUrl/images/$imageId'), // Use /images/:id route
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      print(
          'Failed to delete image metadata $imageId: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to delete image');
    }
    print('Successfully deleted image metadata $imageId');
  }

  // Get images from Supabase (This might not be needed if you always get URLs from MongoDB)
  // Keeping for now, but consider if your app needs to list directly from Supabase.
  Future<List<Map<String, dynamic>>> getSupabaseImages() async {
    print('Fetching images directly from Supabase bucket...');
    // Note: This lists ALL files in the bucket, not just the current user's.
    // Consider listing only user-specific paths if you use userId in filePath.
    try {
      // The list method returns a Future<List<FileObject>>
      final listResult = await _supabase.storage.from(bucketName).list();
      // Supabase list does not seem to have a direct '.error' property on the result.
      // Errors are typically thrown as StorageException.
      // So if listResult is successfully returned, assume no error here.

      return listResult
          .map((file) => {
                'url':
                    _supabase.storage.from(bucketName).getPublicUrl(file.name),
                'name': file.name,
              })
          .toList();
    } on StorageException catch (e) {
      print('Supabase list StorageException: ${e.message}');
      rethrow;
    } catch (e) {
      print('Supabase list generic exception: $e');
      rethrow;
    }
  }

  // Method to update image URL in MongoDB via backend PUT /api/images/url
  Future<void> updateImageUrl(
      {required String imageId,
      required String supabaseUrl,
      required String token}) async {
    print('Attempting to update image URL $imageId in MongoDB...');
    final response = await http.put(
      Uri.parse('$apiUrl/images/url'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'imageId': imageId,
        'supabaseUrl': supabaseUrl,
      }),
    );

    if (response.statusCode != 200) {
      print(
          'Failed to update image URL $imageId: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to update image URL');
    }
    print('Successfully updated image URL $imageId');
  }
}
