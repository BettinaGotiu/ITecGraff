import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/poster_recognizer.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  bool _busy = false;
  bool _ready = false;
  String? _error;
  final recognizer = PosterRecognizer();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // cerere permisiune
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _error = 'Camera permission denied';
          _ready = true;
        });
        return;
      }

      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() {
          _error = 'No camera found';
          _ready = true;
        });
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
      await recognizer.preload();

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Camera init failed: $e';
          _ready = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndMatch() async {
    if (_controller == null || !_controller!.value.isInitialized || _busy)
      return;
    setState(() => _busy = true);
    try {
      final file = await _controller!.takePicture();
      final bytes = await File(file.path).readAsBytes();
      final match = await recognizer.match(bytes, threshold: 10);
      if (!mounted) return;

      if (match != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(match.canvasLabel)));
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
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan poster')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan poster')),
      body: Stack(
        children: [
          CameraPreview(_controller!),
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
                onPressed: _captureAndMatch,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
