package com.example.flutter_application_1

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.flutter_application_1.ImageCompare
import android.graphics.BitmapFactory
import java.io.File
import java.nio.ByteBuffer

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.flutter_application_1/image_compare"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            // This method is invoked on the main thread.
            when (call.method) {
                "computeSimilarity" -> {
                    val image1Path = call.argument<String>("image1Path")
                    val image2Path = call.argument<String>("image2Path")

                    if (image1Path != null && image2Path != null) {
                        try {
                            val file1 = File(image1Path)
                            val file2 = File(image2Path)

                            if (!file1.exists() || !file2.exists()) {
                                result.error("FILE_NOT_FOUND", "One or both image files not found", null)
                                return@setMethodCallHandler
                            }

                            val bitmap1 = BitmapFactory.decodeFile(image1Path)
                            val bitmap2 = BitmapFactory.decodeFile(image2Path)

                            if (bitmap1 == null || bitmap2 == null) {
                                result.error("DECODING_ERROR", "Failed to decode one or both images", null)
                                return@setMethodCallHandler
                            }

                            // Removed image size check here

                            val buffer1 = ByteBuffer.allocate(bitmap1.byteCount)
                            bitmap1.copyPixelsToBuffer(buffer1)
                            val pixels1 = buffer1.array()

                            val buffer2 = ByteBuffer.allocate(bitmap2.byteCount)
                            bitmap2.copyPixelsToBuffer(buffer2)
                            val pixels2 = buffer2.array()

                            // Pass pixel data and dimensions to Java bridge
                            val similarity = ImageCompare().computeSimilarity(
                                pixels1,
                                bitmap1.width,
                                bitmap1.height,
                                pixels2,
                                bitmap2.width,
                                bitmap2.height
                            )
                            result.success(similarity)

                            bitmap1.recycle()
                            bitmap2.recycle()

                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Error computing similarity: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Image paths cannot be null", null)
                    }
                }
                "createComparisonImage" -> {
                    val image1Path = call.argument<String>("image1Path")
                    val image2Path = call.argument<String>("image2Path")
                    val alpha = call.argument<Double>("alpha")
                    val verticalCut = call.argument<Boolean>("verticalCut")

                    if (image1Path != null && image2Path != null && alpha != null && verticalCut != null) {
                         try {
                            val file1 = File(image1Path)
                            val file2 = File(image2Path)

                            if (!file1.exists() || !file2.exists()) {
                                result.error("FILE_NOT_FOUND", "One or both image files not found", null)
                                return@setMethodCallHandler
                            }

                            val bitmap1 = BitmapFactory.decodeFile(image1Path)
                            val bitmap2 = BitmapFactory.decodeFile(image2Path)

                            if (bitmap1 == null || bitmap2 == null) {
                                result.error("DECODING_ERROR", "Failed to decode one or both images", null)
                                return@setMethodCallHandler
                            }

                            // Removed image size check here

                            val buffer1 = ByteBuffer.allocate(bitmap1.byteCount)
                            bitmap1.copyPixelsToBuffer(buffer1)
                            val pixels1 = buffer1.array()

                            val buffer2 = ByteBuffer.allocate(bitmap2.byteCount)
                            bitmap2.copyPixelsToBuffer(buffer2)
                            val pixels2 = buffer2.array()

                            // Pass pixel data and dimensions to Java bridge
                            val outputPath = ImageCompare().createComparisonImage(
                                pixels1,
                                bitmap1.width,
                                bitmap1.height,
                                pixels2,
                                bitmap2.width,
                                bitmap2.height,
                                alpha,
                                verticalCut
                            )
                           result.success(outputPath)

                           bitmap1.recycle()
                           bitmap2.recycle()

                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Error creating comparison image: ${e.message}", null)
                        }
                    } else {
                         result.error("INVALID_ARGUMENTS", "Arguments cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}