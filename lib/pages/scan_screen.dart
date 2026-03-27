import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/poster_ml_recognizer.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  bool _busy = false;
  bool _camReady = false;
  bool _modelReady = false;
  String? _error;
  final recognizer = PosterMlRecognizer();

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await Future.wait([_initCamera(), _initModel()]);
    if (mounted) setState(() {});
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _error = 'Camera permission denied';
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        _error = 'No camera found';
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      _controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();
      _camReady = true;
    } catch (e) {
      _error = 'Camera init failed: $e';
    }
  }

  Future<void> _initModel() async {
    try {
      await recognizer.init(
        modelPath: 'assets/models/mobilenet_v3_small.tflite',
      );
      _modelReady = true;
    } catch (e) {
      _error = 'Model init failed: $e';
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndMatch() async {
    if (!_camReady ||
        !_modelReady ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        _busy)
      return;
    setState(() => _busy = true);
    try {
      final file = await _controller!.takePicture();
      final bytes = await File(file.path).readAsBytes();
      final match = await recognizer.match(bytes, threshold: 0.75);
      if (!mounted) return;

      if (match != null) {
        final numOnly = match.posterId.replaceAll(RegExp(r'[^0-9]'), '');
        final label = 'you are joining canvas $numOnly';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(label)));
        Navigator.pop(context, match.posterId); // ex: 'afis3'
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No poster match. Try again closer / front-on.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan poster')),
        body: Center(child: Text(_error!)),
      );
    }

    final ready = _camReady && _modelReady;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan poster')),
      body: Stack(
        children: [
          if (_camReady && _controller != null)
            CameraPreview(_controller!)
          else
            const Center(child: CircularProgressIndicator()),
          if (!ready)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Text(
                  'Loading camera/model...',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          if (_busy)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture & match'),
                onPressed: ready && !_busy ? _captureAndMatch : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
