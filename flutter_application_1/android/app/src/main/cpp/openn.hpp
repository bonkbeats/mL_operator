#pragma once

// Realistic OpenCV stub header replacement for use in non-OpenCV environments.
// This mimics loading, displaying, and basic manipulation of JPG images.
// Requires stb_image and stb_image_write for basic image handling (included below).

#include <string>
#include <iostream>
#include <vector>
#include <cassert>
#include <cstring>
#include <algorithm>
#include <cstdint>

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image.h"
#include "stb_image_write.h"

namespace cv {

struct Scalar {
    uint8_t val[3];
    Scalar(uint8_t v0, uint8_t v1, uint8_t v2) { val[0] = v0; val[1] = v1; val[2] = v2; }
};

struct Point {
    int x, y;
    Point(int _x, int _y) : x(_x), y(_y) {}
};

struct Rect {
    int x, y, width, height;
    Rect(int _x, int _y, int _width, int _height) : x(_x), y(_y), width(_width), height(_height) {}
};

class Mat {
public:
    int rows = 0, cols = 0, channels = 3;
    unsigned char *data = nullptr;

    Mat() = default;
    Mat(int r, int c, int type) : rows(r), cols(c), channels(3) {
        data = new unsigned char[r * c * channels]();
    }
    Mat(const Mat &other) {
        rows = other.rows; cols = other.cols; channels = other.channels;
        size_t size = rows * cols * channels;
        data = new unsigned char[size];
        std::memcpy(data, other.data, size);
    }
    Mat &operator=(const Mat &other) {
        if (this != &other) {
            delete[] data;
            rows = other.rows; cols = other.cols; channels = other.channels;
            size_t size = rows * cols * channels;
            data = new unsigned char[size];
            std::memcpy(data, other.data, size);
        }
        return *this;
    }
    ~Mat() { delete[] data; }

    bool empty() const { return data == nullptr; }

    Mat operator()(const Rect &r) const {
        Mat roi(r.height, r.width, 0);
        for (int y = 0; y < r.height; ++y) {
            std::memcpy(
                roi.data + y * r.width * channels,
                data + ((y + r.y) * cols + r.x) * channels,
                r.width * channels
            );
        }
        return roi;
    }

    void copyTo(Mat &dst) const {
        assert(dst.rows == rows && dst.cols == cols);
        std::memcpy(dst.data, data, rows * cols * channels);
    }
};

inline Mat imread(const std::string &path) {
    int w, h, c;
    unsigned char *img = stbi_load(path.c_str(), &w, &h, &c, 3);
    if (!img) {
        std::cerr << "Failed to load image: " << path << std::endl;
        return Mat();
    }
    Mat mat(h, w, 0);
    std::memcpy(mat.data, img, h * w * 3);
    stbi_image_free(img);
    return mat;
}

inline void imshow(const std::string &winname, const Mat &img) {
    std::string filename = winname + ".out.jpg";
    stbi_write_jpg(filename.c_str(), img.cols, img.rows, 3, img.data, 90);
    std::cout << "Saved display image to: " << filename << std::endl;
}

inline void namedWindow(const std::string &winname, int flags) {
    std::cout << "Creating window: " << winname << std::endl;
}

inline int waitKey(int delay) {
    std::cout << "Press key (+/-/d/ESC): ";
    char c;
    std::cin >> c;
    return static_cast<int>(c);
}

inline void destroyWindow(const std::string &winname) {
    std::cout << "Destroying window: " << winname << std::endl;
}

inline void line(Mat &img, const Point &p1, const Point &p2, const Scalar &color, int thickness, int lineType) {
    int midx = (p1.x + p2.x) / 2;
    int midy = (p1.y + p2.y) / 2;
    for (int dy = -thickness/2; dy <= thickness/2; ++dy) {
        for (int dx = -thickness/2; dx <= thickness/2; ++dx) {
            int x = midx + dx;
            int y = midy + dy;
            if (x >= 0 && x < img.cols && y >= 0 && y < img.rows) {
                unsigned char *pixel = img.data + (y * img.cols + x) * 3;
                pixel[0] = color.val[0];
                pixel[1] = color.val[1];
                pixel[2] = color.val[2];
            }
        }
    }
}

const int WINDOW_AUTOSIZE = 1;
const int LINE_4 = 4;
const int CV_8UC3 = 16;

} // namespace cv
