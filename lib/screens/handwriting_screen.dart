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
  static const int requiredConsecutiveDetections = 2;

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
      imageQuality: 90,
    );

    if (image != null) {
      try {
        final bytes = await image.readAsBytes();
        cv.Mat mat = cv.imdecode(bytes, cv.IMREAD_COLOR);

        // Aspect-ratio-aware resizing (max 1024)
        if (mat.width > 1024 || mat.height > 1024) {
          double factor = 1024 / (mat.width > mat.height ? mat.width : mat.height);
          mat = await cv.resizeAsync(
            mat,
            ((mat.width * factor).toInt(), (mat.height * factor).toInt()),
            interpolation: cv.INTER_AREA,
          );
        }

        final detection = await _analyzeMatForSpiral(mat);
        if (detection.isSpiralDetected) {
          setState(() {
            _capturedFilePath = image.path;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("No spirals detected in this photo"),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        mat.release();
      } catch (e) {
        print('Error processing gallery image: $e');
      }
    }
  }

  /// Unified spiral analysis logic used by both camera and gallery paths.
  Future<({bool isSpiralDetected, String bestShapeType, cv.Mat? annotated})>
      _analyzeMatForSpiral(cv.Mat mat, {bool returnAnnotated = false}) async {
    final gray = await cv.cvtColorAsync(mat, cv.COLOR_BGR2GRAY);
    final blurred = await cv.gaussianBlurAsync(gray, (3, 3), 0);
    // Lowered thresholds for better sensitivity on gallery images
    final edges = await cv.cannyAsync(blurred, 100, 200);
    final contoursResult = await cv.findContoursAsync(
      edges,
      cv.RETR_EXTERNAL,
      cv.CHAIN_APPROX_SIMPLE,
    );

    final contours = contoursResult.$1;
    bool spiralDetected = false;
    String bestShape = "None";

    print("DEBUG: Analysis started. Contours found: ${contours.length}");

    cv.Mat? overlay;
    if (returnAnnotated) {
      overlay = cv.Mat.zeros(mat.rows, mat.cols, cv.MatType.CV_8UC4);
    }

    // Filter and analyze contours
    for (int i = 0; i < contours.length; i++) {
      final contour = contours[i];
      final area = await cv.contourAreaAsync(contour);
      if (area < 1000) continue; // Ignore small noise

      final peri = await cv.arcLengthAsync(contour, true);
      final approx = await cv.approxPolyDPAsync(contour, 0.02 * peri, true);
      final rect = await cv.boundingRectAsync(approx);

      String currentShape = "Other";
      final vertices = approx.length;

      final circularity = (4 * 3.1415926535 * area) / (peri * peri);
      final boundingArea = rect.width * rect.height;
      final density = area / boundingArea;

      print("DEBUG: Contour index: $i, Area: ${area.toInt()}, Vertices: $vertices, Circularity: ${circularity.toStringAsFixed(3)}, Density: ${density.toStringAsFixed(3)}");

      if (vertices == 3) {
        currentShape = "Triangle";
      } else if (vertices == 4) {
        final aspect = rect.width / rect.height;
        currentShape = (aspect >= 0.9 && aspect <= 1.1) ? "Square" : "Rectangle";
      } else if (vertices == 5) {
        currentShape = "Pentagon";
      } else {
        if (circularity > 0.75) {
          currentShape = "Circle";
        } else {
          // Spiral heuristic: low density relative to bounds, many vertices
          if (density < 0.85 && approx.length >= 8) {
            currentShape = "Spiral";
            spiralDetected = true;
          } else {
            currentShape = "Ellipse";
          }
        }
      }

      print("DEBUG: Detected as: $currentShape");

      if (currentShape == "Spiral") {
        bestShape = "Spiral";
      } else if (bestShape == "None") {
        bestShape = currentShape;
      }

      if (returnAnnotated && overlay != null) {
        await cv.drawContoursAsync(
          overlay,
          contours,
          i,
          cv.Scalar(0, 255, 0, 255),
          thickness: 2,
        );
        await cv.putTextAsync(
          overlay,
          currentShape,
          cv.Point(rect.x, rect.y - 5),
          cv.FONT_HERSHEY_SIMPLEX,
          0.6,
          cv.Scalar(0, 0, 255, 255),
          thickness: 2,
        );
      }
    }

    gray.release();
    blurred.release();
    edges.release();

    return (
      isSpiralDetected: spiralDetected,
      bestShapeType: bestShape,
      annotated: overlay
    );
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

      final analysis = await _analyzeMatForSpiral(rotatedMat, returnAnnotated: true);
      
      _updateSpiralDetectionState(analysis.isSpiralDetected);

      if (analysis.annotated != null && mounted) {
        final (success, pngBytes) = await cv.imencodeAsync(".png", analysis.annotated!);
        if (success) {
          setState(() {
            _overlayBytes = pngBytes;
          });
        }
      }

      srcMat.release();
      rotatedMat.release();
      analysis.annotated?.release();
    } catch (e) {
      print('Camera processing error: $e');
    }

    _isProcessing = false;
  }

  void _updateSpiralDetectionState(bool detected) {
    if (detected) {
      _spiralDetectionCount++;
      _spiralDisappearTimer?.cancel();
      _spiralDisappearTimer = null;

      if (_spiralDetectionCount >= requiredConsecutiveDetections &&
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
