#include <jni.h>
#include <string>
#include <android/log.h>
#include <cmath>
#include <vector>
#include <fstream>
#include "ImageCompare.h"

#define LOG_TAG "ImageCompare"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

// Helper function from original code
inline double clamp(double v, double lo, double hi) {
    return (v < lo) ? lo : (v > hi) ? hi : v;
}

extern "C" {

JNIEXPORT jdouble JNICALL
Java_com_example_flutter_1application_11_ImageCompare_computeSimilarity(
        JNIEnv *env, jobject thiz,
        jbyteArray image1Pixels, jint image1Width, jint image1Height,
        jbyteArray image2Pixels, jint image2Width, jint image2Height) {

    jbyte* pixels1 = env->GetByteArrayElements(image1Pixels, NULL);
    jbyte* pixels2 = env->GetByteArrayElements(image2Pixels, NULL);

    // Call your C++ function with pixel data and dimensions
    double similarity = ImageCompare::computeSimilarity(
        reinterpret_cast<unsigned char*>(pixels1), image1Width, image1Height,
        reinterpret_cast<unsigned char*>(pixels2), image2Width, image2Height
    );

    env->ReleaseByteArrayElements(image1Pixels, pixels1, 0);
    env->ReleaseByteArrayElements(image2Pixels, pixels2, 0);

    return similarity;
}

JNIEXPORT jstring JNICALL
Java_com_example_flutter_1application_11_ImageCompare_createComparisonImage(
        JNIEnv *env, jobject thiz,
        jbyteArray image1Pixels, jint image1Width, jint image1Height,
        jbyteArray image2Pixels, jint image2Width, jint image2Height,
        jdouble alpha, jboolean verticalCut) {

    jbyte* pixels1 = env->GetByteArrayElements(image1Pixels, NULL);
    jbyte* pixels2 = env->GetByteArrayElements(image2Pixels, NULL);

    // Call your C++ function with pixel data and dimensions
    std::vector<unsigned char> comparisonImage;
    ImageCompare::createComparisonImage(
        reinterpret_cast<unsigned char*>(pixels1), image1Width, image1Height,
        reinterpret_cast<unsigned char*>(pixels2), image2Width, image2Height,
        alpha, verticalCut, comparisonImage
    );

    env->ReleaseByteArrayElements(image1Pixels, pixels1, 0);
    env->ReleaseByteArrayElements(image2Pixels, pixels2, 0);

    // Save comparison image to a temporary file and return the path
    std::string output_path = "/data/data/com.example.flutter_application_1/files/comparison.jpg"; // Use a suitable path
    std::ofstream outfile(output_path, std::ios::binary);
    if (outfile.is_open()) {
        outfile.write(reinterpret_cast<char*>(comparisonImage.data()), comparisonImage.size());
        outfile.close();
        return env->NewStringUTF(output_path.c_str());
    } else {
        LOGI("Failed to save comparison image");
        return env->NewStringUTF("");
    }
}

} // extern "C" 