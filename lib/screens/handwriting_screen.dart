import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path_provider/path_provider.dart';

class LiveShapeDetectionScreen extends StatefulWidget {
  const LiveShapeDetectionScreen({super.key});

  @override
  State<LiveShapeDetectionScreen> createState() =>
      _LiveShapeDetectionScreenState();
}

class _LiveShapeDetectionScreenState extends State<LiveShapeDetectionScreen> {
  CameraController? _controller;
  Uint8List? _overlayBytes; // overlay for shapes
  bool _isProcessing = false;
  int _frameCounter = 0;

  // Spiral detection state
  bool _isSpiralDetected = false;
  int _spiralDetectionCount = 0;
  Timer? _spiralDisappearTimer;
  static const int REQUIRED_CONSECUTIVE_DETECTIONS =
      2; // Need 2 consecutive detections to enable
  static const int DISABLE_AFTER_FRAMES =
      5; // Disable after 5 frames without detection

  // Flash state
  bool _isFlashAvailable = false;
  bool _isFlashOn = false;

  // Capture state
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Try to find back camera
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    // Check if flash is available by testing if we can set flash mode
    try {
      await _controller!.setFlashMode(FlashMode.off);

      _isFlashAvailable = true;

      _toggleFlash();
    } catch (e) {
      _isFlashAvailable = false;
      debugPrint("Flash not available: $e");
    }
    if (!mounted) return;
    setState(() {});

    _controller!.startImageStream(_processCameraImage);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;

    _frameCounter++;
    if (_frameCounter % 3 != 0) return; // throttle processing (every 3rd frame)

    _isProcessing = true;

    try {
      final width = image.width;
      final height = image.height;

      final bgrBytes = _convertYUV420toBGR(image);

      final srcMat = cv.Mat.fromList(
        height,
        width,
        cv.MatType.CV_8UC3,
        bgrBytes,
      );

      if (srcMat.rows == 0 || srcMat.cols == 0) {
        debugPrint("Empty Mat received");
        _isProcessing = false;
        return;
      }

      // Rotate if needed
      final rotatedMat = await cv.rotateAsync(srcMat, cv.ROTATE_90_CLOCKWISE);

      // Clone for overlay
      final overlayMat = cv.Mat.zeros(
        rotatedMat.rows,
        rotatedMat.cols,
        cv.MatType.CV_8UC4,
      );

      // Process overlay
      final gray = await cv.cvtColorAsync(rotatedMat, cv.COLOR_BGR2GRAY);
      final blurred = await cv.gaussianBlurAsync(gray, (1, 1), 0);
      final edges = await cv.cannyAsync(blurred, 190, 190);
      final contoursResult = await cv.findContoursAsync(
        edges,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );

      final contours = contoursResult.$1;
      bool spiralDetectedInThisFrame = false;
      int numberOfShapes = 0;

      for (int i = 0; i < contours.length; i++) {
        final contour = contours[i];

        final area = await cv.contourAreaAsync(contour);
        if (area < 1000) continue;

        numberOfShapes++;

        final peri = await cv.arcLengthAsync(contour, true);
        final approx = await cv.approxPolyDPAsync(contour, 0.02 * peri, true);
        final rect = await cv.boundingRectAsync(approx);

        String shapeType = "";
        final vertices = approx.length;

        if (vertices == 3) {
          shapeType = "Triangle";
        } else if (vertices == 4) {
          final aspect = rect.width / rect.height;
          shapeType = (aspect >= 0.95 && aspect <= 1.05)
              ? "Square"
              : "Rectangle";
        } else if (vertices == 5) {
          shapeType = "Pentagon";
        } else {
          final circularity = (4 * 3.1415926535 * area) / (peri * peri);

          if (circularity > 0.75) {
            shapeType = "Circle";
          } else {
            final boundingArea = rect.width * rect.height;
            final density = area / boundingArea;

            if (density < 0.8 && approx.length >= 10) {
              shapeType = "Spiral";

              spiralDetectedInThisFrame = true;
            } else {
              shapeType = "Ellipse";
            }
          }
        }

        await cv.drawContoursAsync(
          overlayMat,
          contours,
          i,
          cv.Scalar(0, 255, 0, 255),
          thickness: 2,
        );

        await cv.putTextAsync(
          overlayMat,
          shapeType,
          cv.Point(rect.x, rect.y - 5),
          cv.FONT_HERSHEY_SIMPLEX,
          0.6,
          cv.Scalar(0, 0, 255, 255),
          thickness: 2,
        );
      }

      // Update spiral detection state

      _updateSpiralDetectionState((numberOfShapes == 1)?spiralDetectedInThisFrame: false, null);

      final (success, pngBytes) = await cv.imencodeAsync(".png", overlayMat);
      if (success) {
        if (mounted) {
          setState(() {
            _overlayBytes = pngBytes;
          });
        }
      }

      // Dispose
      srcMat.dispose();
      rotatedMat.dispose();
      overlayMat.dispose();
      gray.dispose();
      blurred.dispose();
      edges.dispose();
    } catch (e) {
      debugPrint("Processing error: $e");
    }

    _isProcessing = false;
  }

  void _updateSpiralDetectionState(bool detected, String? message) {
    if (detected) {
      // Spiral detected in this frame
      _spiralDetectionCount++;

      // Cancel any pending disable timer
      _spiralDisappearTimer?.cancel();
      _spiralDisappearTimer = null;

      // Enable if we've had enough consecutive detections
      if (_spiralDetectionCount >= REQUIRED_CONSECUTIVE_DETECTIONS &&
          !_isSpiralDetected) {
        setState(() {
          _isSpiralDetected = true;
        });


      }
    } else {
      // No spiral detected in this frame
      if (_isSpiralDetected) {
        ///todo:  make it depand on the number of fialed detection, to use "DISABLE_AFTER_FRAMES"
        _spiralDisappearTimer ??= Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isSpiralDetected = false;
              _spiralDetectionCount = 0;
            });


          }
        });
      } else {
        // Reset counter if no detection streak
        _spiralDetectionCount = 0;
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isFlashAvailable) return;

    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
      }

      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint("Flash error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Flash error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_isSpiralDetected || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {


      // Capture image
      final XFile image = await _controller!.takePicture();

      // Read the image file
      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Save with timestamp
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedFile = File('${dir.path}/spiral_$timestamp.png');
      await savedFile.writeAsBytes(imageBytes);

      debugPrint("Image saved at: ${savedFile.path}");



      // Navigate to next screen
      context.go('/sendvoice', extra: savedFile.path);
    } catch (e) {
      debugPrint("Capture error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Capture failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Uint8List _convertYUV420toBGR(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel!;

    final bgr = Uint8List(width * height * 3);
    int index = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yp = image.planes[0].bytes[y * image.planes[0].bytesPerRow + x];
        final up = image
            .planes[1]
            .bytes[(y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride];
        final vp = image
            .planes[2]
            .bytes[(y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride];

        final r = (yp + 1.402 * (vp - 128)).clamp(0, 255).toInt();
        final g = (yp - 0.34414 * (up - 128) - 0.71414 * (vp - 128))
            .clamp(0, 255)
            .toInt();
        final b = (yp + 1.772 * (up - 128)).clamp(0, 255).toInt();

        bgr[index++] = b;
        bgr[index++] = g;
        bgr[index++] = r;
      }
    }
    return bgr;
  }

  @override
  void dispose() {
    _spiralDisappearTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview
          CameraPreview(_controller!),

          // Detection overlay
          if (_overlayBytes != null)
            Positioned.fill(
              child: Image.memory(_overlayBytes!, fit: BoxFit.cover),
            ),

          // Top status bar
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isSpiralDetected ? Colors.green : Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isSpiralDetected
                        ? 'Spiral Detected'
                        : 'Looking for an alone spiral...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_spiralDetectionCount > 0 && !_isSpiralDetected)
                    Text(
                      '$_spiralDetectionCount/${REQUIRED_CONSECUTIVE_DETECTIONS}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Flash button
                if (_isFlashAvailable)
                  FloatingActionButton(
                    onPressed: _toggleFlash,
                    backgroundColor: _isFlashOn ? Colors.yellow : Colors.grey,
                    mini: true,
                    child: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: _isFlashOn ? Colors.black : Colors.white,
                    ),
                  ),

                // Capture button
                FloatingActionButton.extended(
                  onPressed: _isSpiralDetected && !_isCapturing
                      ? _captureImage
                      : null,
                  backgroundColor: _isSpiralDetected
                      ? Colors.green
                      : Colors.grey,
                  icon: _isCapturing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(
                    _isCapturing
                        ? 'Capturing...'
                        : _isSpiralDetected
                        ? 'Capture Spiral'
                        : 'No alone Spiral',
                  ),
                ),

                // Placeholder for symmetry
                const SizedBox(width: 56),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
