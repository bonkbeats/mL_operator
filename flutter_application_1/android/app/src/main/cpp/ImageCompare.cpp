#include "ImageCompare.h"
#include <vector>
#include <cmath>
#include <cstring>
#include <stdexcept>
#include <android/log.h>
#include <numeric>

#define LOG_TAG "ImageCompare"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

double ImageCompare::computeSimilarity(const unsigned char* image1Pixels, int image1Width, int image1Height, const unsigned char* image2Pixels, int image2Width, int image2Height) {
    if (image1Width != image2Width || image1Height != image2Height) {
        LOGI("Images must be the same size");
        throw std::runtime_error("Images must be the same size");
    }

    // Assuming ARGB_8888 format (4 bytes per pixel) from Android Bitmap
    int bytesPerPixel = 4;
    int totalBytes = image1Width * image1Height * bytesPerPixel;
    int similarBytes = 0;

    // Compare pixel data byte by byte
    for (int i = 0; i < totalBytes; ++i) {
        // Simple absolute difference comparison
        if (std::abs(image1Pixels[i] - image2Pixels[i]) < 10) {
            ++similarBytes;
        }
    }

    // Calculate similarity based on the ratio of similar bytes
    return static_cast<double>(similarBytes) / totalBytes;
}

void ImageCompare::createComparisonImage(const unsigned char* image1Pixels, int image1Width, int image1Height, const unsigned char* image2Pixels, int image2Width, int image2Height, double alpha, bool verticalCut, std::vector<unsigned char>& comparisonImage) {
    if (image1Width != image2Width || image1Height != image2Height) {
        LOGI("Images must be the same size");
        throw std::runtime_error("Images must be the same size");
    }

    // Assuming ARGB_8888 format (4 bytes per pixel)
    int bytesPerPixel = 4;
    int rowBytes = image1Width * bytesPerPixel;
    int totalBytes = image1Width * image1Height * bytesPerPixel;

    comparisonImage.resize(totalBytes);

    // Ensure alpha is clamped between 0.0 and 1.0
    alpha = clamp(alpha, 0.0, 1.0);

    if (verticalCut) {
        int cutCol = image1Width * alpha;
        int cutByteOffset = cutCol * bytesPerPixel;

        // Copy left part from image1
        for (int i = 0; i < image1Height; ++i) {
            memcpy(comparisonImage.data() + i * rowBytes,
                   image1Pixels + i * rowBytes,
                   cutByteOffset);
        }

        // Copy right part from image2
        for (int i = 0; i < image1Height; ++i) {
            memcpy(comparisonImage.data() + i * rowBytes + cutByteOffset,
                   image2Pixels + i * rowBytes + cutByteOffset,
                   rowBytes - cutByteOffset);
        }

        // Draw vertical white line (ARGB: 255, 255, 255, 255)
        // Adjusting for ARGB format (A=255, R=255, G=255, B=255)
        if (cutCol > 0 && cutCol < image1Width) {
             for (int i = 0; i < image1Height; ++i) {
                int pixelIndex = i * image1Width + cutCol; // Index of the pixel in the row
                int byteIndex = pixelIndex * bytesPerPixel; // Starting byte index for the pixel
                comparisonImage[byteIndex] = 255;     // A
                comparisonImage[byteIndex + 1] = 255; // R
                comparisonImage[byteIndex + 2] = 255; // G
                comparisonImage[byteIndex + 3] = 255; // B
            }
        }

    } else { // Horizontal cut
        int cutRow = image1Height * alpha;
        int cutByteOffset = cutRow * rowBytes;

        // Copy top part from image1
        memcpy(comparisonImage.data(), image1Pixels, cutByteOffset);

        // Copy bottom part from image2
        memcpy(comparisonImage.data() + cutByteOffset,
               image2Pixels + cutByteOffset,
               totalBytes - cutByteOffset);

        // Draw horizontal white line (ARGB: 255, 255, 255, 255)
        // Adjusting for ARGB format (A=255, R=255, G=255, B=255)
        if (cutRow > 0 && cutRow < image1Height) {
            for (int i = 0; i < image1Width; ++i) {
                int pixelIndex = cutRow * image1Width + i; // Index of the pixel in the column
                int byteIndex = pixelIndex * bytesPerPixel; // Starting byte index for the pixel
                comparisonImage[byteIndex] = 255;     // A
                comparisonImage[byteIndex + 1] = 255; // R
                comparisonImage[byteIndex + 2] = 255; // G
                comparisonImage[byteIndex + 3] = 255; // B
            }
        }
    }
    // The comparisonImage vector now contains the pixel data for the resulting image.
    // It will be handled (e.g., saved to a file) in the JNI bridge (image_compare.cpp).
} 