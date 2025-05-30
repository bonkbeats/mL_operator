#pragma once

#include <string>
#include <vector>
#include <cmath>

class ImageCompare {
public:
    static double computeSimilarity(const unsigned char* image1Pixels, int image1Width, int image1Height, const unsigned char* image2Pixels, int image2Width, int image2Height);
    static void createComparisonImage(const unsigned char* image1Pixels, int image1Width, int image1Height, const unsigned char* image2Pixels, int image2Width, int image2Height, double alpha, bool verticalCut, std::vector<unsigned char>& comparisonImage);

private:
    static inline double clamp(double v, double lo, double hi) {
        return (v < lo) ? lo : (v > hi) ? hi : v;
    }
}; 