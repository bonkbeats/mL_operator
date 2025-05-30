import 'dart:io';
import 'package:flutter/services.dart';

class ImageComparisonService {
  static const platform =
      MethodChannel('com.example.flutter_application_1/image_compare');

  // Compute similarity between two images
  Future<double> computeSimilarity(File image1, File image2) async {
    try {
      final double similarity =
          await platform.invokeMethod('computeSimilarity', {
        'image1Path': image1.path,
        'image2Path': image2.path,
      });
      return similarity;
    } on PlatformException catch (e) {
      print('Error computing similarity: ${e.message}');
      rethrow;
    }
  }

  // Create a comparison image with a slider
  Future<File> createComparisonImage(
      File image1, File image2, double alpha, bool verticalCut) async {
    try {
      final String outputPath =
          await platform.invokeMethod('createComparisonImage', {
        'image1Path': image1.path,
        'image2Path': image2.path,
        'alpha': alpha,
        'verticalCut': verticalCut,
      });
      return File(outputPath);
    } on PlatformException catch (e) {
      print('Error creating comparison image: ${e.message}');
      rethrow;
    }
  }
}
