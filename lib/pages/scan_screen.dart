import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String? _posterId;
  bool _useQr = false;

  ARSessionManager? _arSessionManager;

  void _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    _arSessionManager = sessionManager;
    _arSessionManager?.onInitialize(
      showAnimatedGuide: true,
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      handleTaps: false,
    );
  }

  @override
  void dispose() {
    _arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useQr) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan QR poster')),
        body: MobileScanner(
          onDetect: (capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            if (code == null) return;
            if (!mounted) return;
            setState(() => _posterId = code);
            Navigator.pop(context, code);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan poster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => setState(() => _useQr = true),
          ),
        ],
      ),
      body: Stack(
        children: [
          ARView(onARViewCreated: _onARViewCreated),
          if (_posterId == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Card(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'This plugin version does not expose image tracking. Use QR fallback from the top-right button.',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
