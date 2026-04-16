import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:monster_money_manager/service/ollama_service.dart';
import 'package:monster_money_manager/screens/receipts_screen.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    _controller = CameraController(backCamera, ResolutionPreset.medium);

    _initializeControllerFuture = _controller!.initialize();
    setState(() {});
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      // Process the image with OCR
      await recognizeText(image.path);
    }
  }

  Future<void> recognizeText(String imagePath) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Run OCR with Tesseract
      final ocrText = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'eng', // you can add more languages if needed
      );

      // Send to Ollama LLM
      final parsedJson = await OllamaService.parseReceipt(ocrText);
      print('Parsed receipt data: $parsedJson');

      // Navigate to receipts screen and pass parsed data
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MyReceiptsScreen(incomingReceiptData: parsedJson),
          ),
        );
      }
    } catch (e) {
      print('Error processing receipt: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing receipt: $e')));
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Camera preview area
            Align(
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.only(top: 50, bottom: 80),
                child: _controller != null
                    ? FutureBuilder(
                        future: _initializeControllerFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CameraPreview(_controller!),
                            );
                          } else {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                        },
                      )
                    : const Center(
                        child: Text(
                          'Loading camera...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
              ),
            ),

            // Top controls
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Icon(Icons.flash_on, color: Colors.white, size: 22),
                  Text(
                    'HDR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.filter_center_focus,
                    color: Colors.white,
                    size: 22,
                  ),
                  Icon(Icons.menu, color: Colors.white, size: 24),
                ],
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: IconButton(
                      onPressed: _pickFromGallery,
                      icon: const Icon(
                        Icons.image,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Center(
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.sync, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Loading spinner overlay
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
