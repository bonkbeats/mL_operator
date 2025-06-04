#pragma once

#include "openn.hpp"
#include <iostream>
#include <cassert>
#include <cmath>
#include <algorithm>

inline double clamp(double v, double lo, double hi) {
    return (v < lo) ? lo : (v > hi) ? hi : v;
}

class ImageComparator {
private:
    bool vertical_cut = true;
    cv::Mat bigImg;

public:
    ImageComparator() {}

    double computeSimilarity(const cv::Mat &img1, const cv::Mat &img2) {
        assert(img1.rows == img2.rows);
        assert(img1.cols == img2.cols);
        assert(img1.channels == img2.channels);

        int total_pixels = img1.rows * img1.cols * img1.channels;
        int similar_pixels = 0;

        for (int i = 0; i < total_pixels; ++i) {
            if (std::abs(img1.data[i] - img2.data[i]) < 10)
                ++similar_pixels;
        }
        return static_cast<double>(similar_pixels) / total_pixels;
    }

    cv::Mat resizeToMatch(const cv::Mat &src, int new_rows, int new_cols) {
        cv::Mat resized(new_rows, new_cols, 0);
        for (int y = 0; y < new_rows; ++y) {
            for (int x = 0; x < new_cols; ++x) {
                int src_y = y * src.rows / new_rows;
                int src_x = x * src.cols / new_cols;
                for (int c = 0; c < src.channels; ++c) {
                    resized.data[(y * new_cols + x) * src.channels + c] =
                        src.data[(src_y * src.cols + src_x) * src.channels + c];
                }
            }
        }
        return resized;
    }
};