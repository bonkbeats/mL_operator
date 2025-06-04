// Modified ImageCompare.h to allow automatic resizing before comparison
#pragma once

#include "openn.hpp"
#include <iostream>
#include <cassert>
#include <cmath>

inline double clamp(double v, double lo, double hi) {
    return (v < lo) ? lo : (v > hi) ? hi : v;
}

class ImageComparator {
private:
    bool vertical_cut = true;
    cv::Mat bigImg;

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
        cv::Mat resized(new_rows, new_cols, cv::CV_8UC3);
        for (int y = 0; y < new_rows; ++y) {
            for (int x = 0; x < new_cols; ++x) {
                int src_y = y * src.rows / new_rows;
                int src_x = x * src.cols / new_cols;
                for (int c = 0; c < 3; ++c) {
                    resized.data[(y * new_cols + x) * 3 + c] = src.data[(src_y * src.cols + src_x) * 3 + c];
                }
            }
        }
        return resized;
    }

public:
    ImageComparator() {}

    void showImages(cv::Mat &img1, cv::Mat &img2, double alpha) {
        if (img1.empty() || img2.empty()) return;

        alpha = clamp(alpha, 0.0, 1.0);

        assert(img1.rows == img2.rows);
        assert(img1.cols == img2.cols);

        if (alpha > 0.0 && alpha < 1.0) {
            if (vertical_cut) {
                int colcut = img1.cols * alpha;
                cv::Rect r1(0, 0, colcut, img1.rows);
                cv::Mat ap = img1(r1);
                cv::Mat roi1 = bigImg(r1);
                ap.copyTo(roi1);

                cv::Rect r2(colcut, 0, img1.cols - colcut, img1.rows);
                cv::Mat bp = img2(r2);
                cv::Mat roi2 = bigImg(r2);
                bp.copyTo(roi2);
                cv::line(bigImg, {colcut, 0}, {colcut, img1.rows}, cv::Scalar(255, 255, 255), 2, cv::LINE_4);
            } else {
                int rowcut = img1.rows * alpha;
                cv::Rect r1(0, 0, img1.cols, rowcut);
                cv::Mat ap = img1(r1);
                cv::Mat roi1 = bigImg(r1);
                ap.copyTo(roi1);

                cv::Rect r2(0, rowcut, img1.cols, img1.rows - rowcut);
                cv::Mat bp = img2(r2);
                cv::Mat roi2 = bigImg(r2);
                bp.copyTo(roi2);
                cv::line(bigImg, {0, rowcut}, {img1.cols, rowcut}, cv::Scalar(255, 255, 255), 2, cv::LINE_4);
            }
            cv::imshow("ImageCompare", bigImg);
        }

        if (alpha == 0.0) {
            cv::imshow("ImageCompare", img2);
        }

        if (alpha == 1.0) {
            cv::imshow("ImageCompare", img1);
        }
    }

    void run(const std::string &path1, const std::string &path2) {
        std::cout << "Key + : Increase clipping value" << std::endl;
        std::cout << "Key - : Decrease clipping value" << std::endl;
        std::cout << "Key d : Change direction of clipping" << std::endl;

        cv::Mat img1 = cv::imread(path1);
        cv::Mat img2 = cv::imread(path2);

        if (img1.empty() || img2.empty()) {
            std::cerr << "One or both images failed to load." << std::endl;
            return;
        }

        int target_rows = std::min(img1.rows, img2.rows);
        int target_cols = std::min(img1.cols, img2.cols);

        img1 = resizeToMatch(img1, target_rows, target_cols);
        img2 = resizeToMatch(img2, target_rows, target_cols);

        double similarity = computeSimilarity(img1, img2);
        std::cout << "Image similarity: " << similarity * 100 << "%" << std::endl;
        if (similarity >= 0.90) {
            std::cout << "Images are sufficiently similar (>= 90%)." << std::endl;
            return;
        }

        std::string winname = "ImageCompare";
        cv::namedWindow(winname, cv::WINDOW_AUTOSIZE);
        bigImg = cv::Mat(target_rows, target_cols, cv::CV_8UC3);

        double dl = 1.0 / 100.0;
        double alpha = 0.5;
        while (1) {
            showImages(img1, img2, alpha);
            int key = cv::waitKey(0);
            if ('d' == key) {
                vertical_cut = !vertical_cut;
            }
            if ('+' == key) {
                alpha += dl;
            }
            if ('-' == key) {
                alpha -= dl;
            }

            if (key == 27) {
                break;
            }

            alpha = clamp(alpha, 0.0, 1.0);
        }

        cv::destroyWindow(winname);
    }
};