import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_comparison_service.dart';

class ImageComparisonScreen extends StatefulWidget {
  const ImageComparisonScreen({Key? key}) : super(key: key);

  @override
  _ImageComparisonScreenState createState() => _ImageComparisonScreenState();
}

class _ImageComparisonScreenState extends State<ImageComparisonScreen> {
  final ImageComparisonService _comparisonService = ImageComparisonService();
  final ImagePicker _picker = ImagePicker();

  File? _image1;
  File? _image2;
  File? _comparisonImage;
  double _sliderValue = 0.5;
  bool _verticalCut = true;
  double? _similarity;
  bool _isLoading = false;

  Future<void> _pickImage(bool isFirstImage) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isFirstImage) {
          _image1 = File(image.path);
        } else {
          _image2 = File(image.path);
        }
      });
      _updateComparison();
    }
  }

  Future<void> _updateComparison() async {
    if (_image1 == null || _image2 == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Compute similarity
      _similarity =
          await _comparisonService.computeSimilarity(_image1!, _image2!);

      // Create comparison image
      _comparisonImage = await _comparisonService.createComparisonImage(
        _image1!,
        _image2!,
        _sliderValue,
        _verticalCut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
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
        title: const Text('Image Comparison'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image selection buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(true),
                  icon: const Icon(Icons.image),
                  label: const Text('Select Image 1'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(false),
                  icon: const Icon(Icons.image),
                  label: const Text('Select Image 2'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Display selected images
            if (_image1 != null && _image2 != null) ...[
              // Comparison image
              if (_comparisonImage != null) Image.file(_comparisonImage!),

              const SizedBox(height: 16),

              // Similarity percentage
              if (_similarity != null)
                Text(
                  'Similarity: ${(_similarity! * 100).toStringAsFixed(2)}%',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: 16),

              // Slider
              Slider(
                value: _sliderValue,
                onChanged: (value) {
                  setState(() {
                    _sliderValue = value;
                  });
                  _updateComparison();
                },
              ),

              // Direction toggle
              SwitchListTile(
                title: const Text('Vertical Cut'),
                value: _verticalCut,
                onChanged: (value) {
                  setState(() {
                    _verticalCut = value;
                  });
                  _updateComparison();
                },
              ),
            ],

            // Loading indicator
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
