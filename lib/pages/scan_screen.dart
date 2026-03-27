import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan poster QR')),
      body: MobileScanner(
        controller: MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
        ),
        onDetect: (capture) {
          if (_handled) return;
          final code = capture.barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            _handled = true;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Success: $code')));
            Navigator.pop(context, code); // return posterId/roomId
          }
        },
      ),
    );
  }
}
