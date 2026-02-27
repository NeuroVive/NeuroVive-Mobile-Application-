import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:neurovive/icons/neurovive_icons.dart';
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
  Uint8List? _overlayBytes;
  bool _isProcessing = false;
  int _frameCounter = 0;

  bool _isSpiralDetected = false;
  int _spiralDetectionCount = 0;
  Timer? _spiralDisappearTimer;
  static const int REQUIRED_CONSECUTIVE_DETECTIONS = 2;
  static const int DISABLE_AFTER_FRAMES = 5;

  bool _isFlashAvailable = false;
  bool _isFlashOn = false;

  bool _isCapturing = false;

  // NEW → confirmation state
  String? _capturedFilePath;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

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

    try {
      await _controller!.setFlashMode(FlashMode.off);
      _isFlashAvailable = true;
      _toggleFlash();
    } catch (e) {
      _isFlashAvailable = false;
    }

    if (!mounted) return;
    setState(() {});

    _controller!.startImageStream(_processCameraImage);
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      try {
        final bytes = await image.readAsBytes();
        final mat = cv.imdecode(bytes, cv.IMREAD_COLOR);
        cv.Mat resized = cv.resize(
          mat,
          (1000, 1600), // target size (width, height)
          interpolation: cv.INTER_LINEAR,
        );
        if (await _checkSpiral(resized)) {
          setState(() {
            _capturedFilePath = image.path;

          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                //
                "no spirals detected in this photo",
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
        mat.release();
      } catch (e) {
        print('Error converting image bytes to Mat: $e');
      }
    }
  }

  Future<bool> _checkSpiral(cv.Mat mat) async {
    final gray = await cv.cvtColorAsync(mat, cv.COLOR_BGR2GRAY);
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
      if (numberOfShapes > 1) {
        print("miore than one shape detected");
        return false;
      }

      final peri = await cv.arcLengthAsync(contour, true);
      final approx = await cv.approxPolyDPAsync(contour, 0.02 * peri, true);
      final rect = await cv.boundingRectAsync(approx);

      String shapeType = "";
      final vertices = approx.length;

      print("styarted detecting");
      if (vertices == 3) {
        shapeType = "Triangle";
      } else if (vertices == 4) {
        final aspect = rect.width / rect.height;
        shapeType = (aspect >= 0.95 && aspect <= 1.05) ? "Square" : "Rectangle";
      } else if (vertices == 5) {
        shapeType = "Pentagon";
      } else {
        final circularity = (4 * 3.1415926535 * area) / (peri * peri);

        if (circularity > 0.75) {
          shapeType = "Circle";
        } else {
          final boundingArea = rect.width * rect.height;
          final density = area / boundingArea;
          print("denisty: $density, lenght : ${approx.length}");
          if (density < 0.8 && approx.length >= 10) {
            shapeType = "Spiral";

            spiralDetectedInThisFrame = true;
          } else {
            shapeType = "Ellipse";
          }
        }
      }

      print("shape type: $shapeType");
    }
    print("outside the loop now");
    return spiralDetectedInThisFrame;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _capturedFilePath != null) return;

    _frameCounter++;
    if (_frameCounter % 3 != 0) return;

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
        _isProcessing = false;
        return;
      }

      final rotatedMat = await cv.rotateAsync(srcMat, cv.ROTATE_90_CLOCKWISE);

      final overlayMat = cv.Mat.zeros(
        rotatedMat.rows,
        rotatedMat.cols,
        cv.MatType.CV_8UC4,
      );

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

      _updateSpiralDetectionState(
        (numberOfShapes == 1) ? spiralDetectedInThisFrame : false,
      );

      final (success, pngBytes) = await cv.imencodeAsync(".png", overlayMat);

      if (success && mounted) {
        setState(() {
          _overlayBytes = pngBytes;
        });
      }

      srcMat.dispose();
      rotatedMat.dispose();
      overlayMat.dispose();
      gray.dispose();
      blurred.dispose();
      edges.dispose();
    } catch (_) {}

    _isProcessing = false;
  }

  void _updateSpiralDetectionState(bool detected) {
    if (detected) {
      _spiralDetectionCount++;
      _spiralDisappearTimer?.cancel();
      _spiralDisappearTimer = null;

      if (_spiralDetectionCount >= REQUIRED_CONSECUTIVE_DETECTIONS &&
          !_isSpiralDetected) {
        setState(() => _isSpiralDetected = true);
      }
    } else {
      if (_isSpiralDetected) {
        _spiralDisappearTimer ??= Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isSpiralDetected = false;
              _spiralDetectionCount = 0;
            });
          }
        });
      } else {
        _spiralDetectionCount = 0;
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isFlashAvailable) return;

    if (_isFlashOn) {
      await _controller!.setFlashMode(FlashMode.off);
    } else {
      await _controller!.setFlashMode(FlashMode.torch);
    }

    setState(() => _isFlashOn = !_isFlashOn);
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_isSpiralDetected || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile image = await _controller!.takePicture();
      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedFile = File('${dir.path}/spiral_$timestamp.jpg');
      await savedFile.writeAsBytes(imageBytes);

      if (mounted) {
        setState(() {
          _capturedFilePath = savedFile.path;
        });
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capture failed'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
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

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isSpiralDetected && !_isCapturing ? _captureImage : null,
      child: AnimatedContainer(
        padding: EdgeInsetsGeometry.all(16),
        duration: const Duration(milliseconds: 200),
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isSpiralDetected
              ? Color.fromRGBO(70, 209, 192, 1)
              : Color.fromRGBO(162, 162, 162, 1),
          boxShadow: _isSpiralDetected
              ? [
                  const BoxShadow(
                    color: Color.fromRGBO(70, 209, 192, 1),
                    blurRadius: 5.4,
                    spreadRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Image.asset("assets/images/camera.png"),
      ),
    );
  }

  Widget _buildConfirmationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel
        GestureDetector(
          onTap: () {
            setState(() {
              _capturedFilePath = null;
            });
          },
          child: Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Neurovive.close,
              size: 32,
              color: Color.fromRGBO(35, 68, 116, 1),
            ),
          ),
        ),

        // Confirm
        GestureDetector(
          onTap: () {
            if (_capturedFilePath != null) {
              context.go('/sendvoice', extra: _capturedFilePath);
            }
          },
          child: Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color.fromRGBO(70, 209, 192, 1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Neurovive.check, size: 32, color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: CameraPreview(_controller!)),

              if (_capturedFilePath != null)
                Positioned.fill(
                  child: Image.file(
                    File(_capturedFilePath!),
                    fit: BoxFit.cover,
                  ),
                )
              else if (_overlayBytes != null)
                Positioned.fill(
                  child: Image.memory(_overlayBytes!, fit: BoxFit.cover),
                ),

              // Flash Button
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  onTap: _toggleFlash,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isFlashOn
                          ? Color.fromRGBO(249, 248, 113, 1)
                          : Color.fromRGBO(162, 162, 162, 1),
                      boxShadow: _isFlashOn
                          ? [
                              const BoxShadow(
                                color: Color.fromRGBO(249, 248, 113, .53),
                                blurRadius: 4,
                                spreadRadius: 4,
                              ),
                            ]
                          : [],
                    ),
                    child: Image.asset("assets/images/flash.png"),
                  ),
                ),
              ),
              // Gallery Button
              Positioned(
                bottom: 20,
                right: 20,
                child: GestureDetector(
                  onTap: _pickFromGallery,
                  child: Container(
                    padding: EdgeInsets.all(5),
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white70,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset("assets/images/multimedia.png"),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ===== BOTTOM AREA =====
        Container(
          height: 120,
          color: Color.fromRGBO(35, 68, 116, 1),
          child: Center(
            child: _capturedFilePath != null
                ? _buildConfirmationButtons()
                : _buildCaptureButton(),
          ),
        ),
      ],
    );
  }
}
