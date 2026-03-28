import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

enum AppState { scanning, popup, drawing }

class ARMainScreen extends StatefulWidget {
  const ARMainScreen({Key? key}) : super(key: key);

  @override
  _ARMainScreenState createState() => _ARMainScreenState();
}

class _ARMainScreenState extends State<ARMainScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  AppState _currentState = AppState.scanning;
  String _detectedRoomName = "";
  ARImageAnchor? _activePosterAnchor;
  Color _selectedColor = Colors.red;

  @override
  void dispose() {
    super.dispose();
    arSessionManager?.dispose(); // Oprim sesiunea la iesirea din ecran
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    // Initializam Sesiunea AR
    this.arSessionManager!.onInitialize(
      showFeaturePoints: false, // Fara puncte pe ecran
      showPlanes: false, // Nu cautam podeaua, ne intereseaza doar posterul
      showWorldOrigin: false,
      handleTaps: false,
    );
    this.arObjectManager!.onInitialize();

    _setupImageTracking();
  }

  Future<void> _setupImageTracking() async {
    // Cream lista cu toate cele 13 postere din assets/posters
    final List<Map<String, dynamic>> posterImages = [
      for (int i = 1; i <= 13; i++)
        {
          'name': 'afis$i',
          'path': 'assets/posters/afis$i.png',
          'physicalWidth': 0.3, // ~30 cm – ajustați dacă cunoașteți dimensiunea reală
        }
    ];

    // Incarcam TOATE posterele intr-un singur apel (eficient – o singura configurare ARCore)
    await arSessionManager?.addAllReferenceImages(posterImages);

    // Ascultam pentru momentul in care camera detecteaza oricare din postere
    arAnchorManager?.onAnchorDownloaded =
        (Map<String, dynamic> serializedAnchor) {
          final anchor = ARAnchor.fromJson(serializedAnchor);

          if (anchor is ARImageAnchor && _currentState == AppState.scanning) {
            _showRoomPopup(anchor, 'Camera "${anchor.referenceImageName}"');
          }
          return anchor;
        };
  }

  void _showRoomPopup(ARImageAnchor anchor, String roomName) {
    setState(() {
      _detectedRoomName = roomName;
      _activePosterAnchor = anchor;
      _currentState = AppState.popup;
    });
  }

  // --- LOGICA DE DESEN (ANCORAT PE POSTER) ---
  void _onScreenDrag(DragUpdateDetails details) async {
    if (_currentState != AppState.drawing || _activePosterAnchor == null)
      return;

    // Logica pentru a adauga puncte (ex: sfere 3D) direct pe suprafata posterului
    // Aceste puncte vor avea ca parinte (_activePosterAnchor). Cand posterul
    // se misca in camera, punctele se vor misca sincronizat.

    /*
    // Decomenteaza si adapteaza la functia reala de raycast a plugin-ului
    var hits = await arSessionManager?.raycast(details.localPosition);
    if (hits != null && hits.isNotEmpty) {
       var firstHit = hits.first;
       
       var drawNode = ARNode(
           type: NodeType.localGLTF2, 
           position: firstHit.worldTransform.getTranslation(),
           scale: vector.Vector3(0.01, 0.01, 0.01), // Mărimea "pensulei"
       );

       arObjectManager?.addNode(drawNode, parentAnchor: _activePosterAnchor);
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // WIDGET-UL CARE DESCHIDE CAMERA PROPRIU-ZISĂ
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.none,
          ),

          // Interfata aplicata PESTE camera in functie de stare
          _buildUIOverlay(),
        ],
      ),
    );
  }

  Widget _buildUIOverlay() {
    switch (_currentState) {
      case AppState.scanning:
        return _buildScanningUI();
      case AppState.popup:
        return _buildPopupUI();
      case AppState.drawing:
        return _buildDrawingUI();
    }
  }

  Widget _buildScanningUI() {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            "Îndreaptă camera spre afis12.png...",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupUI() {
    return Container(
      color: Colors.black54, // Dimming background
      child: Center(
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.symmetric(horizontal: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                const Text(
                  "Poster Detectat!",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Vrei să intri în $_detectedRoomName?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _currentState = AppState.scanning;
                        _activePosterAnchor = null;
                      }),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: () => setState(() {
                        _currentState = AppState.drawing;
                      }),
                      child: const Text(
                        "Join Room",
                        style: TextStyle(color: Colors.white),
                      ),
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

  Widget _buildDrawingUI() {
    return Stack(
      children: [
        // Suprafata invizibila pentru a prinde gesturile de desen
        GestureDetector(
          onPanUpdate: _onScreenDrag,
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // Buton de iesire din camera
        Positioned(
          top: 50,
          left: 20,
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            mini: true,
            child: const Icon(Icons.close, color: Colors.black),
            onPressed: () => setState(() {
              _currentState = AppState.scanning;
              _activePosterAnchor = null;
            }),
          ),
        ),
        // Indicator Camera
        Positioned(
          top: 60,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _detectedRoomName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Selector Culori
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _colorBtn(Colors.red),
              _colorBtn(Colors.green),
              _colorBtn(Colors.blue),
              _colorBtn(Colors.yellow),
            ],
          ),
        ),
      ],
    );
  }

  Widget _colorBtn(Color color) {
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _selectedColor == color ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    );
  }
}
