#include <jni.h>
#include <string>
#include <android/log.h>
#include <cmath>
#include <vector>
#include <fstream>
#include "ImageCompare.h"

#define LOG_TAG "ImageCompare"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jdouble JNICALL
Java_com_example_flutter_1application_11_ImageCompare_computeSimilarity(
        JNIEnv *env, jobject /* this */,
        jbyteArray image1Pixels, jint image1Width, jint image1Height,
        jbyteArray image2Pixels, jint image2Width, jint image2Height) {

    jbyte* pixels1 = env->GetByteArrayElements(image1Pixels, NULL);
    jbyte* pixels2 = env->GetByteArrayElements(image2Pixels, NULL);

    // Use your stub Mat
    cv::Mat img1(image1Height, image1Width, 0);
    cv::Mat img2(image2Height, image2Width, 0);
    std::memcpy(img1.data, pixels1, image1Height * image1Width * 3);
    std::memcpy(img2.data, pixels2, image2Height * image2Width * 3);

    ImageComparator comp;
    int target_rows = std::min(img1.rows, img2.rows);
    int target_cols = std::min(img1.cols, img2.cols);

    cv::Mat img1_resized = comp.resizeToMatch(img1, target_rows, target_cols);
    cv::Mat img2_resized = comp.resizeToMatch(img2, target_rows, target_cols);

    double similarity = comp.computeSimilarity(img1_resized, img2_resized);

    env->ReleaseByteArrayElements(image1Pixels, pixels1, 0);
    env->ReleaseByteArrayElements(image2Pixels, pixels2, 0);

    return similarity;
}