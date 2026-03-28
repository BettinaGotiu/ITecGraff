import 'dart:async';
import 'dart:ui';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class ARCanvasScreen extends StatefulWidget {
  final String roomId; // Primim ID-ul posterului din ecranul anterior

  const ARCanvasScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<ARCanvasScreen> createState() => _ARCanvasScreenState();
}

class _ARCanvasScreenState extends State<ARCanvasScreen> {
  ARSessionManager? arSessionManager;

  // Variabile pentru desenul 2D
  List<List<Offset>> _lines = [];
  List<Offset> _currentLine = [];

  // Controlează dacă am plasat deja chenarul în spațiul AR
  bool _isPosterLocked = false;

  // Variabile matematice pentru iluzia 3D (Floating Anchor)
  vector.Vector3? _posterWorldPosition;
  double _posterScreenX = 0.0;
  double _posterScreenY = 0.0;
  double _scaleFactor = 1.0;

  Timer? _arTrackingTimer;

  // Dimensiunea virtuală a zonei în care poți desena (proporția posterului)
  // Dacă posterul din viața reală are alt format (ex: e mai lat decât înalt), inversează aceste valori.
  final double canvasWidth = 280;
  final double canvasHeight = 400;

  @override
  void dispose() {
    _arTrackingTimer?.cancel();
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Graffiti: ${widget.roomId}'),
        actions: [
          // Buton pentru a șterge desenul curent și a o lua de la capăt
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() {
              _lines.clear();
              _currentLine.clear();
            }),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. FUNDALUL VIDEO AR
          // Folosim camera pluginului fără să-i cerem să mai caute planuri (fără triunghiuri albe)
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.none,
          ),

          // 2. CHENARUL DE DESEN (Apare doar DUPĂ ce ai apăsat FIXEAZĂ POSTERUL)
          // Acest bloc se va mișca pe ecran ca să compenseze pașii tăi în lumea reală
          if (_isPosterLocked)
            Positioned(
              left: _posterScreenX - ((canvasWidth * _scaleFactor) / 2),
              top: _posterScreenY - ((canvasHeight * _scaleFactor) / 2),
              child: Transform.scale(
                scale: _scaleFactor,
                child: Container(
                  width: canvasWidth,
                  height: canvasHeight,
                  decoration: BoxDecoration(
                    // Un chenar ușor ca să știi până unde ai voie să desenezi
                    border: Border.all(color: Colors.pinkAccent, width: 3),
                    color: Colors.white.withOpacity(
                      0.05,
                    ), // Tentă albă transparentă
                  ),
                  // ClipRect "taie" desenul dacă încerci să ieși cu degetul din chenar!
                  child: ClipRect(
                    child: GestureDetector(
                      // Logica clasică de desen (Pan)
                      onPanStart: (details) => setState(
                        () => _currentLine = [details.localPosition],
                      ),
                      onPanUpdate: (details) => setState(
                        () => _currentLine.add(details.localPosition),
                      ),
                      onPanEnd: (details) => setState(() {
                        _lines.add(List.from(_currentLine));
                        _currentLine.clear();
                      }),
                      // Randăm liniile folosind CustomPainter
                      child: CustomPaint(
                        painter: _GraffitiPainter(
                          lines: _lines,
                          currentLine: _currentLine,
                        ),
                        size: Size(canvasWidth, canvasHeight),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 3. ECRANUL DE INIȚIALIZARE
          if (!_isPosterLocked)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(20),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Privește spre doza/posterul tău real\npână îl încadrezi pe centrul ecranului.\nApoi apasă butonul pentru a-i bloca poziția!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                      onPressed: _forceLockPosterToCamera,
                      child: const Text(
                        "FIXEAZĂ POSTERUL",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;

    // Inițializăm mediul 3D cât mai curat posibil
    arSessionManager!.onInitialize(
      showAnimatedGuide: false,
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      handleTaps: false,
    );
  }

  // Funcția apelată când apeși pe "FIXEAZĂ POSTERUL"
  Future<void> _forceLockPosterToCamera() async {
    // Obținem unde se află telefonul în spațiu în milisecunda asta
    var cameraPose = await arSessionManager!.getCameraPose();
    if (cameraPose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Așteaptă 1-2 secunde să se inițializeze ARCore și mai apasă o dată.',
          ),
        ),
      );
      return;
    }

    // Extragem poziția camerei și cum e înclinată (rotația)
    vector.Vector3 camPos = cameraPose.getTranslation();
    vector.Matrix3 camRot = cameraPose.getRotation();

    // Creăm un punct matematic la EXACT 0.6 metri (60 cm) în fața camerei!
    vector.Vector3 forwardVector = vector.Vector3(0.0, 0.0, -0.6);

    // Convertim punctul ăsta ca să fie absolut (raportat la centrul lumii, nu doar la cameră)
    _posterWorldPosition = camPos + (camRot * forwardVector);

    setState(() {
      _isPosterLocked = true;
    });

    // Chenarul apare inițial fix pe mijlocul ecranului
    final size = MediaQuery.of(context).size;
    _posterScreenX = size.width / 2;
    _posterScreenY = size.height / 2;

    // Pornim un Timer care se execută de 30 de ori pe secundă (30 FPS)
    // El se ocupă să citească dacă te-ai mișcat și să mute desenul
    _arTrackingTimer = Timer.periodic(const Duration(milliseconds: 33), (
      timer,
    ) {
      _updatePosterPositionOnScreen();
    });
  }

  // MAGIA AR HIBRIDĂ: Funcția care mută desenul pe ecran ca să pară că stă în spațiu
  Future<void> _updatePosterPositionOnScreen() async {
    if (_posterWorldPosition == null || arSessionManager == null || !mounted)
      return;

    var cameraPose = await arSessionManager!.getCameraPose();
    if (cameraPose == null) return;

    vector.Vector3 camPos = cameraPose.getTranslation();

    // 1. Calculăm distanța reală (în metri) dintre telefonul tău și "ancora" din aer
    double distanceInMeters = camPos.distanceTo(_posterWorldPosition!);

    // 2. Calculăm scala. Dacă ești la 0.6 metri distanță, scala e 1.0 (mărime normală).
    // Dacă te dai mai în spate (ex. 1.2 metri), scala devine 0.5 (desenul se face mic).
    double newScale = 0.6 / (distanceInMeters == 0 ? 0.001 : distanceInMeters);
    newScale = newScale.clamp(0.2, 3.0); // Împiedicăm mărimile extreme

    // 3. Calculăm cu câți metri a deviat telefonul pe lățime/înălțime
    double deltaX = _posterWorldPosition!.x - camPos.x;
    double deltaY = _posterWorldPosition!.y - camPos.y;

    final size = MediaQuery.of(context).size;

    // 4. Convertim acea deviație din metri în pixeli pe ecranul tău
    // Multiplicatorul (1200) simulează field-of-view-ul camerei.
    double screenX = (size.width / 2) + (deltaX * 1200);
    double screenY = (size.height / 2) - (deltaY * 1200);

    // Salvăm noile coordonate ca interfața Flutter să se redeseneze instant
    setState(() {
      _posterScreenX = screenX;
      _posterScreenY = screenY;
      _scaleFactor = newScale;
    });
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
