import 'dart:async';
import 'dart:ui';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:flutter/material.dart';

class ARCanvasScreen extends StatefulWidget {
  final String roomId; // ID-ul posterului (ex: "afis1", "afis2", ...)

  const ARCanvasScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<ARCanvasScreen> createState() => _ARCanvasScreenState();
}

class _ARCanvasScreenState extends State<ARCanvasScreen>
    with SingleTickerProviderStateMixin {
  // ── Manageri AR ──────────────────────────────────────────────────────────
  ARSessionManager? _sessionMgr;
  ARObjectManager? _objectMgr;
  ARAnchorManager? _anchorMgr;

  // ── Ancora detecatată ─────────────────────────────────────────────────────
  ARImageAnchor? _anchor;
  bool _posterDetected = false;
  bool _posterVisible = false;

  // ── Canvas de desen ───────────────────────────────────────────────────────
  final List<List<Offset>> _lines = [];
  List<Offset> _currentLine = [];

  double _cx = 0;
  double _cy = 0;
  double _scale = 1.0;

  double _canvasW = 300.0;
  double _canvasH = 420.0;

  Timer? _trackingTimer;

  // Tangenta semi-unghiului de câmp vizual (FOV) pentru o cameră mobilă tipică.
  // FOV orizontal ≈ 65°  →  tan(32.5°) ≈ 0.637
  // FOV vertical   ≈ 50°  →  tan(25°)   ≈ 0.466
  static const double _kTanHalfFovH = 0.637;
  static const double _kTanHalfFovV = 0.466;

  static const double _kPxPerMeter = 1000.0;
  static const double _kDefaultPosterWidth = 0.30; // lățime fizică implicită (metri)
  static const double _kA4AspectRatio = 1.414;

  /// Factor de acoperire: canvas-ul este cu atât mai mare decât posterul,
  /// compensând variațiile de FOV între dispozitive (1.0 = exact, 1.1 = 10% mai mare).
  static const double _kCanvasCoverage = 1.1;

  // ── Animație scanare ──────────────────────────────────────────────────────
  late AnimationController _scanAnimCtrl;
  late Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scanAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _sessionMgr?.dispose();
    _scanAnimCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    _sessionMgr = sessionManager;
    _objectMgr = objectManager;
    _anchorMgr = anchorManager;

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
    _loadPoster();
  }

  // ── Încărcăm posterul corespunzător acestui room și așteptăm detecția ────
  Future<void> _loadPoster() async {
    // Încărcăm toate posterele ca să detectăm oricare dintre ele;
    // vom reacționa doar la cel care corespunde roomId-ului curent.
    final images = [
      for (int i = 1; i <= 13; i++)
        {
          'name': 'afis$i',
          'path': 'assets/posters/afis$i.png',
          'physicalWidth': _kDefaultPosterWidth,
        }
    ];

    await _sessionMgr?.addAllReferenceImages(images);

    _anchorMgr?.onAnchorDownloaded = (Map<String, dynamic> raw) {
      final anchor = ARAnchor.fromJson(raw);
      if (anchor is ARImageAnchor) {
        if (!_posterDetected) {
          // Detecție inițială
          final matchesRoom = anchor.referenceImageName == widget.roomId;
          // Dacă roomId nu are formatul "afis$i" (e.g. e un ID Firebase), acceptăm
          // primul poster recunoscut ca fallback.
          final roomIdIsNotPosterName =
              !RegExp(r'^afis\d+$').hasMatch(widget.roomId);
          if (matchesRoom || roomIdIsNotPosterName) {
            _onPosterDetected(anchor);
          }
        } else if (_anchor != null &&
            anchor.referenceImageName == _anchor!.referenceImageName &&
            mounted) {
          // Re-detecție în modul desen: actualizăm ancora pentru tracking mai precis.
          // Folosim setState direct (nu _onPosterDetected) ca să nu restartăm timer-ul.
          setState(() => _anchor = anchor);
        }
      }
      return anchor;
    };
  }

  // ── Posterul a fost detectat – inițializăm canvas-ul ────────────────────
  void _onPosterDetected(ARImageAnchor anchor) {
    final physW = anchor.physicalSize.x > 0
        ? anchor.physicalSize.x
        : _kDefaultPosterWidth;
    final physH = anchor.physicalSize.y > 0
        ? anchor.physicalSize.y
        : physW * _kA4AspectRatio;
    _canvasW = (physW * _kPxPerMeter).clamp(150.0, 600.0).toDouble();
    _canvasH = (physH * _kPxPerMeter).clamp(150.0, 800.0).toDouble();

    final sz = MediaQuery.of(context).size;
    setState(() {
      _anchor = anchor;
      _posterDetected = true;
      _posterVisible = false;
      _cx = sz.width / 2;
      _cy = sz.height / 2;
      _scale = 1.0;
    });

    // Pornim timer-ul care urmărește ancora în timp real (~30 FPS)
    _trackingTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _updateCanvas(),
    );
  }

  // ── Actualizăm poziția/scala canvas-ului folosind pose-ul live al ancorei ─
  Future<void> _updateCanvas() async {
    if (_anchor == null || _sessionMgr == null || !mounted) return;

    final anchorPose = await _sessionMgr!.getPose(_anchor!);
    if (anchorPose == null) {
      // ARCore a pierdut ancora – ascundem canvas-ul imediat
      if (mounted) setState(() => _posterVisible = false);
      return;
    }
    if (!mounted) return;

    final camPose = await _sessionMgr!.getCameraPose();
    if (camPose == null || !mounted) return;

    final anchorPos = anchorPose.getTranslation();
    final camPos = camPose.getTranslation();
    final camRot = camPose.getRotation();

    // Vectorul cameră → ancoră, transformat în spațiul camerei
    final diff = anchorPos - camPos;
    final diffCam = camRot.transposed() * diff;

    if (diffCam.z >= 0) {
      // Ancora e în spatele camerei – ascundem canvas-ul
      if (mounted) setState(() => _posterVisible = false);
      return;
    }

    final depth = -diffCam.z;
    final sz = MediaQuery.of(context).size;

    final screenX =
        sz.width / 2 + (diffCam.x / depth) / _kTanHalfFovH * (sz.width / 2);
    final screenY =
        sz.height / 2 - (diffCam.y / depth) / _kTanHalfFovV * (sz.height / 2);

    // Scala cu factor de acoperire: canvas-ul este _kCanvasCoverage ori mai mare decât
    // proiecția teoretică a posterului, compensând variațiile de FOV între dispozitive.
    // Formula: scale × canvasW = physW × sz.width × coverage / (2 × depth × tanHalfFov)
    // ceea ce înseamnă că lățimea canvas-ului = lățimea proiectată a posterului × coverage.
    final scale =
        (sz.width * _kCanvasCoverage / (2.0 * depth * _kTanHalfFovH * _kPxPerMeter))
            .clamp(0.05, 8.0)
            .toDouble();

    // Ascundem canvas-ul dacă posterul a ieșit complet din câmpul vizual
    // (verificăm dacă întreg canvas-ul e în afara ecranului)
    final halfW = _canvasW * scale / 2;
    final halfH = _canvasH * scale / 2;
    if (screenX + halfW < 0 ||
        screenX - halfW > sz.width ||
        screenY + halfH < 0 ||
        screenY - halfH > sz.height) {
      if (mounted) setState(() => _posterVisible = false);
      return;
    }

    if (mounted) {
      setState(() {
        _cx = screenX;
        _cy = screenY;
        _scale = scale;
        _posterVisible = true;
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Graffiti: ${widget.roomId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Șterge desenul',
            onPressed: () => setState(() {
              _lines.clear();
              _currentLine.clear();
            }),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. FUNDALUL VIDEO AR (camera activă permanent)
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.none,
          ),

          // 2. CHENARUL DE DESEN – apare DOAR când posterul e detectat și vizibil
          if (_posterDetected && _posterVisible) _buildCanvas(),

          // 3. UI SUPRAPUS
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
    if (!_posterDetected) {
      // Ecran de scanare – așteptăm detecția posterului
      return _scanningOverlay();
    }
    // Modul desen – banner de avertizare dacă posterul nu mai e vizibil
    if (!_posterVisible) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Posterul nu este vizibil – îndreaptă camera spre el',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _scanningOverlay() {
    return Stack(
      children: [
        // Cadru de scanare animat
        Center(
          child: AnimatedBuilder(
            animation: _scanAnim,
            builder: (context, child) {
              return Container(
                width: 230,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(_scanAnim.value),
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
        ),
        // Banner informativ
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _scanAnim,
                    builder: (_, child) =>
                        Opacity(opacity: _scanAnim.value, child: child),
                    child: const Icon(Icons.crop_free,
                        color: Colors.white70, size: 26),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Se scanează... Îndreaptă camera spre poster',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Clasa responsabilă exclusiv cu desenarea liniilor (graffiti-ul propriu-zis)
class _GraffitiPainter extends CustomPainter {
  final List<List<Offset>> lines;
  final List<Offset> currentLine;

  _GraffitiPainter({required this.lines, required this.currentLine});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors
          .pinkAccent // Culoarea spray-ului
      ..strokeWidth =
          6.0 // Grosimea liniei
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Desenăm absolut toate liniile salvate anterior
    for (var line in lines) {
      if (line.length > 1) {
        // Dacă e o linie continuă, o tragem segment cu segment
        for (int i = 0; i < line.length - 1; i++) {
          canvas.drawLine(line[i], line[i + 1], paint);
        }
      } else if (line.isNotEmpty) {
        // Dacă e doar un "Tap" (un punct)
        canvas.drawPoints(PointMode.points, [line.first], paint);
      }
    }

    // Desenăm linia pe care o tragi efectiv cu degetul ACUM (în timp real)
    if (currentLine.length > 1) {
      for (int i = 0; i < currentLine.length - 1; i++) {
        canvas.drawLine(currentLine[i], currentLine[i + 1], paint);
      }
    } else if (currentLine.isNotEmpty) {
      canvas.drawPoints(PointMode.points, [currentLine.first], paint);
    }
  }

  // Optimizează performanța, spune framework-ului să redeseneze când chemăm setState()
  @override
  bool shouldRepaint(covariant _GraffitiPainter oldDelegate) => true;
}
