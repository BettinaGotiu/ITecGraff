import 'dart:async';

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

// ─────────────────────────────────────────────────────────────────────────────
// Stările ecranului (camera AR rămâne activă în toate stările)
// ─────────────────────────────────────────────────────────────────────────────
enum _AppState { scanning, popup, drawing }

/// Ecranul de scanare AR.
///
/// Flux:
///  1. Camera AR se deschide și caută oricare din cele 13 postere.
///  2. La detecție: pop-up cu două opțiuni:
///     - "Desenează aici" – rămâne pe acest ecran cu un canvas 2D ancorat pe poster.
///     - "Mergi la Canvas" – returnează ID-ul posterului la HomeScreen, care va
///       deschide ARCanvasScreen cu sesiune nouă.
///  3. Modul de desen: canvas 2D urmărește posterul în spațiu 3D prin polling
///     al pose-ului camerei la 30 FPS.
class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // ── Manageri AR ──────────────────────────────────────────────────────────
  ARSessionManager? _sessionMgr;
  ARObjectManager? _objectMgr;
  ARAnchorManager? _anchorMgr;

  // ── Stare ─────────────────────────────────────────────────────────────────
  _AppState _state = _AppState.scanning;
  String _detectedName = '';
  ARImageAnchor? _anchor;

  // ── Canvas de desen ───────────────────────────────────────────────────────
  final List<List<Offset>> _lines = [];
  List<Offset> _currentLine = [];

  double _cx = 0; // centrul canvas-ului pe ecran (X)
  double _cy = 0; // centrul canvas-ului pe ecran (Y)
  double _scale = 1.0;

  /// Dimensiunile canvas-ului în pixeli virtuali (derivate din dimensiunea fizică a posterului)
  double _canvasW = 300.0;
  double _canvasH = 420.0;

  /// Factorul de conversie pixeli/metru folosit la derivarea dimensiunii canvas-ului
  static const double _kPxPerMeter = 1000.0;

  /// Poziție mondială fixă a ancorei, capturată la momentul detecției
  vector.Vector3? _anchorWorldPos;
  Timer? _trackingTimer;

  // Tangenta semi-unghiului de câmp vizual (FOV) pentru o cameră mobilă tipică.
  // FOV orizontal ≈ 65°  →  tan(32.5°) ≈ 0.637
  // FOV vertical   ≈ 50°  →  tan(25°)   ≈ 0.466
  static const double _kTanHalfFovH = 0.637;
  static const double _kTanHalfFovV = 0.466;

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _trackingTimer?.cancel();
    _sessionMgr?.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  void _onARViewCreated(
    ARSessionManager s,
    ARObjectManager o,
    ARAnchorManager a,
    ARLocationManager l,
  ) {
    _sessionMgr = s;
    _objectMgr = o;
    _anchorMgr = a;

    _sessionMgr!.onInitialize(
      showAnimatedGuide: false,
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      handleTaps: false,
      handlePans: false,
      handleRotation: false,
    );
    _objectMgr!.onInitialize();
    _loadAllPosters();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Încărcăm toate cele 13 postere printr-un singur apel batch
  // (evităm cicluri multiple de pause/resume ARCore care blocau sesiunea)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadAllPosters() async {
    final images = [
      for (int i = 1; i <= 13; i++)
        {
          'name': 'afis$i',
          'path': 'assets/posters/afis$i.png',
          // Lățimea fizică estimată în metri – ajustați dacă cunoașteți dimensiunea reală
          'physicalWidth': 0.30,
        }
    ];

    await _sessionMgr?.addAllReferenceImages(images);

    // Activăm callback-ul DUPĂ ce toate imaginile sunt înregistrate
    _anchorMgr?.onAnchorDownloaded = (Map<String, dynamic> raw) {
      final anchor = ARAnchor.fromJson(raw);
      if (anchor is ARImageAnchor && _state == _AppState.scanning) {
        _onPosterDetected(anchor);
      }
      return anchor;
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  void _onPosterDetected(ARImageAnchor anchor) {
    setState(() {
      _detectedName = anchor.referenceImageName;
      _anchor = anchor;
      _state = _AppState.popup;
    });
  }

  // ── Intră în modul de desen în interiorul acestui ecran ─────────────────
  void _startDrawingHere() {
    if (_anchor == null) return;

    // Fixăm poziția mondială a ancorei (ARCore actualizează ancora intern,
    // dar pentru vizualizare 2D ne este suficient să o citim o singură dată)
    _anchorWorldPos = _anchor!.transformation.getTranslation().clone();

    // Derivăm dimensiunile canvas-ului din dimensiunea fizică a posterului
    _canvasW = (_anchor!.physicalSize.x * _kPxPerMeter).clamp(100.0, 600.0).toDouble();
    _canvasH = (_anchor!.physicalSize.y * _kPxPerMeter).clamp(100.0, 800.0).toDouble();

    final sz = MediaQuery.of(context).size;
    setState(() {
      _state = _AppState.drawing;
      _cx = sz.width / 2;
      _cy = sz.height / 2;
      _scale = 1.0;
    });

    _trackingTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _updateCanvas(),
    );
  }

  // ── Actualizăm poziția/scala canvas-ului pe baza pose-ului camerei ───────
  Future<void> _updateCanvas() async {
    if (_anchorWorldPos == null || _sessionMgr == null || !mounted) return;

    final camPose = await _sessionMgr!.getCameraPose();
    if (camPose == null || !mounted) return;

    final camPos = camPose.getTranslation();
    final camRot = camPose.getRotation();

    // Vectorul cameră → ancoră, transformat în spațiul camerei
    final diff = _anchorWorldPos! - camPos;
    final diffCam = camRot.transposed() * diff;

    if (diffCam.z >= 0) return; // ancora e în spatele camerei

    final depth = -diffCam.z;

    final sz = MediaQuery.of(context).size;
    final screenX =
        sz.width / 2 + (diffCam.x / depth) / _kTanHalfFovH * (sz.width / 2);
    final screenY =
        sz.height / 2 - (diffCam.y / depth) / _kTanHalfFovV * (sz.height / 2);
    final scale = (0.5 / depth).clamp(0.15, 4.0).toDouble();

    if (mounted) {
      setState(() {
        _cx = screenX;
        _cy = screenY;
        _scale = scale;
      });
    }
  }

  // ── Resetăm la scanare ───────────────────────────────────────────────────
  void _resetToScanning() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    setState(() {
      _state = _AppState.scanning;
      _anchor = null;
      _anchorWorldPos = null;
      _lines.clear();
      _currentLine.clear();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Camera AR (rulează în permanență)
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.none,
          ),

          // 2. Canvas de desen (vizibil doar în modul drawing)
          if (_state == _AppState.drawing) _buildCanvas(),

          // 3. UI suprapus
          _buildOverlay(),
        ],
      ),
    );
  }

  // ── Canvas 2D ancorat pe poster ──────────────────────────────────────────
  Widget _buildCanvas() {
    return Positioned(
      left: _cx - _canvasW * _scale / 2,
      top: _cy - _canvasH * _scale / 2,
      child: Transform.scale(
        scale: _scale,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _canvasW,
          height: _canvasH,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.pinkAccent, width: 3),
              color: Colors.white.withOpacity(0.06),
            ),
            child: ClipRect(
              child: GestureDetector(
                onPanStart: (d) =>
                    setState(() => _currentLine = [d.localPosition]),
                onPanUpdate: (d) =>
                    setState(() => _currentLine.add(d.localPosition)),
                onPanEnd: (_) => setState(() {
                  if (_currentLine.isNotEmpty) {
                    _lines.add(List.from(_currentLine));
                  }
                  _currentLine.clear();
                }),
                child: CustomPaint(
                  painter: _GraffitiPainter(
                    lines: _lines,
                    currentLine: _currentLine,
                  ),
                  size: Size(_canvasW, _canvasH),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── UI suprapus ──────────────────────────────────────────────────────────
  Widget _buildOverlay() {
    switch (_state) {
      case _AppState.scanning:
        return _scanningOverlay();
      case _AppState.popup:
        return _popupOverlay();
      case _AppState.drawing:
        return _drawingOverlay();
    }
  }

  Widget _scanningOverlay() {
    return Column(
      children: [
        SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.crop_free, color: Colors.white70, size: 28),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Îndreaptă camera spre un poster...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _popupOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.green, size: 56),
                const SizedBox(height: 14),
                const Text(
                  'Poster detectat!',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _detectedName,
                  style: const TextStyle(
                      fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Opțiunea 1: desenează direct în acest ecran
                    ElevatedButton.icon(
                      icon: const Icon(Icons.brush),
                      label: const Text('Desenează aici'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _startDrawingHere,
                    ),
                    const SizedBox(height: 10),
                    // Opțiunea 2: returnează ID-ul la HomeScreen → ARCanvasScreen
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Mergi la Canvas'),
                      onPressed: () =>
                          Navigator.of(context).pop(_detectedName),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resetToScanning,
                      child: const Text('Anulează'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawingOverlay() {
    return SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _resetToScanning,
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _detectedName,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () => setState(() {
              _lines.clear();
              _currentLine.clear();
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _GraffitiPainter extends CustomPainter {
  final List<List<Offset>> lines;
  final List<Offset> currentLine;

  const _GraffitiPainter({required this.lines, required this.currentLine});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void draw(List<Offset> pts) {
      if (pts.length > 1) {
        final p = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (var i = 1; i < pts.length; i++) {
          p.lineTo(pts[i].dx, pts[i].dy);
        }
        canvas.drawPath(p, paint);
      } else if (pts.isNotEmpty) {
        canvas.drawCircle(pts.first, paint.strokeWidth / 2, paint);
      }
    }

    for (final l in lines) {
      draw(l);
    }
    draw(currentLine);
  }

  @override
  bool shouldRepaint(_GraffitiPainter old) => true;
}
