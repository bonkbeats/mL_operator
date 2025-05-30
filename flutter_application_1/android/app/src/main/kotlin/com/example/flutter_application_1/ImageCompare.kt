package com.example.flutter_application_1

class ImageCompare {
    companion object {
        init {
            System.loadLibrary("image_compare")
        }
    }

    external fun computeSimilarity(
        image1Pixels: ByteArray,
        image1Width: Int,
        image1Height: Int,
        image2Pixels: ByteArray,
        image2Width: Int,
        image2Height: Int
    ): Double

    external fun createComparisonImage(
        image1Pixels: ByteArray,
        image1Width: Int,
        image1Height: Int,
        image2Pixels: ByteArray,
        image2Width: Int,
        image2Height: Int,
        alpha: Double,
        verticalCut: Boolean
    ): String
} 