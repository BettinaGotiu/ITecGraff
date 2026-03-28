import 'dart:async';

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stările ecranului (camera AR rămâne activă în toate stările)
// ─────────────────────────────────────────────────────────────────────────────
enum _AppState { scanning, popup, drawing }

/// Ecranul de scanare AR.
///
/// Flux:
///  1. Camera AR se deschide și caută oricare din cele 13 postere.
///  2. La detecție: pop-up cu o singură opțiune "Mergi la Canvas" care activează
///     modul de desen direct pe acest ecran (fără a naviga la un nou ecran).
///  3. Modul de desen: canvas 2D urmărește posterul în spațiu 3D prin polling
///     al pose-ului ancorei la ~30 FPS. Canvas-ul este ascuns dacă posterul
///     iese din câmpul vizual.
class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
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

  /// Vizibilitate poster: canvas apare doar când posterul este în câmpul vizual
  bool _posterVisible = false;

  /// Dimensiunile canvas-ului în pixeli virtuali (derivate din dimensiunea fizică a posterului)
  double _canvasW = 300.0;
  double _canvasH = 420.0;

  /// Factorul de conversie pixeli/metru folosit la derivarea dimensiunii canvas-ului
  static const double _kPxPerMeter = 1000.0;

  Timer? _trackingTimer;

  // Tangenta semi-unghiului de câmp vizual (FOV) pentru o cameră mobilă tipică.
  // FOV orizontal ≈ 65°  →  tan(32.5°) ≈ 0.637
  // FOV vertical   ≈ 50°  →  tan(25°)   ≈ 0.466
  static const double _kTanHalfFovH = 0.637;
  static const double _kTanHalfFovV = 0.466;

  /// Proporție A4 (√2 ≈ 1.414) – fallback dacă ARCore nu raportează înălțimea
  static const double _kA4AspectRatio = 1.414;

  /// Marginea (în pixeli) față de marginea ecranului dincolo de care canvas-ul
  /// este considerat „în afara câmpului vizual" și este ascuns.
  static const double _kOffscreenMargin = 200.0;

  /// Dimensiunile colțurilor decorative ale cadrului de scanare.
  static const double _kCornerBracketSize = 28.0;
  static const double _kCornerBracketThickness = 3.5;

  // ── Animație scanare ──────────────────────────────────────────────────────
  late AnimationController _scanAnimCtrl;
  late Animation<double> _scanAnim;

  // ──────────────────────────────────────────────────────────────────────────
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

    // Derivăm dimensiunile canvas-ului din dimensiunea fizică a posterului
    // cu fallback la 30cm lățime și proporție A4 dacă nu e raportată dimensiunea
    final physW =
        _anchor!.physicalSize.x > 0 ? _anchor!.physicalSize.x : 0.30;
    final physH =
        _anchor!.physicalSize.y > 0 ? _anchor!.physicalSize.y : physW * _kA4AspectRatio;
    _canvasW = (physW * _kPxPerMeter).clamp(150.0, 600.0).toDouble();
    _canvasH = (physH * _kPxPerMeter).clamp(150.0, 800.0).toDouble();

    final sz = MediaQuery.of(context).size;
    setState(() {
      _state = _AppState.drawing;
      _posterVisible = false;
      _cx = sz.width / 2;
      _cy = sz.height / 2;
      _scale = 1.0;
    });

    _trackingTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _updateCanvas(),
    );
  }

  // ── Actualizăm poziția/scala canvas-ului folosind pose-ul live al ancorei ─
  Future<void> _updateCanvas() async {
    if (_anchor == null || _sessionMgr == null || !mounted) return;

    // Obținem pose-ul curent al ancorei direct din ARCore (tracking live)
    final anchorPose = await _sessionMgr!.getPose(_anchor!);
    if (anchorPose == null || !mounted) return;

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

    // Ascundem canvas-ul dacă posterul a ieșit complet din câmpul vizual
    if (screenX < -_kOffscreenMargin ||
        screenX > sz.width + _kOffscreenMargin ||
        screenY < -_kOffscreenMargin ||
        screenY > sz.height + _kOffscreenMargin) {
      if (mounted) setState(() => _posterVisible = false);
      return;
    }

    // Scala corectă: canvas-ul acoperă exact dimensiunea fizică a posterului.
    // physW se simplifică (canvasW = physW * kPxPerMeter), deci:
    //   scale = screenWidth / (2 * depth * tanHalfFovH * kPxPerMeter)
    final scale =
        (sz.width / (2.0 * depth * _kTanHalfFovH * _kPxPerMeter))
            .clamp(0.05, 8.0)
            .toDouble();

    if (mounted) {
      setState(() {
        _cx = screenX;
        _cy = screenY;
        _scale = scale;
        _posterVisible = true;
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
      _posterVisible = false;
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

          // 2. Canvas de desen (vizibil doar în modul drawing ȘI posterul e în câmp)
          if (_state == _AppState.drawing && _posterVisible) _buildCanvas(),

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
    return Stack(
      children: [
        // Buton de navigare înapoi
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),

        // Cadru de scanare animat (pulsează pentru a indica activitate)
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
                child: Stack(
                  children: [
                    _cornerBracket(Alignment.topLeft),
                    _cornerBracket(Alignment.topRight),
                    _cornerBracket(Alignment.bottomLeft),
                    _cornerBracket(Alignment.bottomRight),
                  ],
                ),
              );
            },
          ),
        ),

        // Banner de informare la baza ecranului
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
                    builder: (_, child) => Opacity(
                      opacity: _scanAnim.value,
                      child: child,
                    ),
                    child: const Icon(Icons.crop_free,
                        color: Colors.white70, size: 26),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Se scanează... Îndreaptă camera spre un poster',
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

  /// Colț decorativ al cadrului de scanare.
  Widget _cornerBracket(Alignment alignment) {
    final isLeft = alignment == Alignment.topLeft ||
        alignment == Alignment.bottomLeft;
    final isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;
    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      child: AnimatedBuilder(
        animation: _scanAnim,
        builder: (_, child) =>
            Opacity(opacity: (_scanAnim.value * 0.5 + 0.5), child: child),
        child: CustomPaint(
          size: const Size(_kCornerBracketSize, _kCornerBracketSize),
          painter: _CornerPainter(
              isLeft: isLeft,
              isTop: isTop,
              thickness: _kCornerBracketThickness),
        ),
      ),
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
                    // Singura opțiune: deschide canvas-ul direct pe acest ecran
                    ElevatedButton.icon(
                      icon: const Icon(Icons.brush),
                      label: const Text('Mergi la Canvas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _startDrawingHere,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          // Banner de avertizare dacă posterul nu mai e vizibil
          if (!_posterVisible)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desenează colțul cadrului de scanare (L-shape)
// ─────────────────────────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final bool isLeft;
  final bool isTop;
  final double thickness;

  const _CornerPainter({
    required this.isLeft,
    required this.isTop,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Linie orizontală
    canvas.drawLine(
      Offset(isLeft ? 0 : w, isTop ? 0 : h),
      Offset(isLeft ? w : 0, isTop ? 0 : h),
      paint,
    );
    // Linie verticală
    canvas.drawLine(
      Offset(isLeft ? 0 : w, isTop ? 0 : h),
      Offset(isLeft ? 0 : w, isTop ? h : 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
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
