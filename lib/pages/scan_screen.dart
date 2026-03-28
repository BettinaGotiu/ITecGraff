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

// Stările prin care trece ecranul (fără să închidă camera)
enum AppState { scanning, popup, drawing }

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Managerii pentru plugin-ul AR
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  // Variabile de stare
  AppState _currentState = AppState.scanning;
  String _detectedRoomName = "";
  ARImageAnchor? _activePosterAnchor;
  Color _selectedColor = Colors.red;

  @override
  void dispose() {
    arSessionManager
        ?.dispose(); // Oprim sesiunea AR cand iesim definitiv din pagina
    super.dispose();
  }

  // Funcția apelată când camera AR este pregătită
  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    // Inițializare optimizată strict pentru imagini (fără podele)
    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      handleTaps: false,
      handlePans: false,
      handleRotation: false,
    );

    this.arObjectManager!.onInitialize();

    // Încărcăm imaginile pentru tracking
    _loadReferenceImages();
  }

  Future<void> _loadReferenceImages() async {
    // Adăugăm posterele în baza de date AR
    await arSessionManager?.addReferenceImage(
      name: "afis1",
      path: "assets/posters/afis1.png",
      physicalWidth: 0.5,
    );

    await arSessionManager?.addReferenceImage(
      name: "afis12",
      path: "assets/posters/afis12.png",
      physicalWidth: 0.4,
    );

    // Ascultăm când ARCore detectează una din imaginile de mai sus
    arAnchorManager?.onAnchorDownloaded =
        (Map<String, dynamic> serializedAnchor) {
          final anchor = ARAnchor.fromJson(serializedAnchor);

          if (anchor is ARImageAnchor && _currentState == AppState.scanning) {
            onImageDetected(anchor);
          }
          return anchor;
        };
  }

  // Logica de detectare a imaginii
  void onImageDetected(ARImageAnchor anchor) {
    String roomName = "Unknown Room";
    if (anchor.referenceImageName == "afis1") roomName = "Camera Principală";
    if (anchor.referenceImageName == "afis12") roomName = "Camera Afiș 12";

    setState(() {
      _detectedRoomName = roomName;
      _activePosterAnchor = anchor;
      _currentState = AppState.popup; // Afișăm popup-ul peste cameră
    });
  }

  // Logica pentru desen - Se activează doar în starea "drawing"
  void _onScreenDrag(DragUpdateDetails details) async {
    if (_currentState != AppState.drawing || _activePosterAnchor == null)
      return;

    var hits = await arSessionManager?.raycast(context.size!, details.localPosition, details.localPosition);
    if (hits != null && hits.isNotEmpty) {
       var firstHit = hits.first;
       
       vector.Matrix4 hitTransform = firstHit.worldTransform;
       vector.Vector3 worldPos = hitTransform.getTranslation();

       vector.Matrix4 inversePosterTransform = vector.Matrix4.copy(_activePosterAnchor!.transformation);
       inversePosterTransform.invert();
       vector.Vector3 localPos = inversePosterTransform.transform3(worldPos);

       double halfWidth = _activePosterAnchor!.physicalSize.x / 2.0;
       double halfHeight = _activePosterAnchor!.physicalSize.y / 2.0;

       if (localPos.x.abs() <= halfWidth && localPos.z.abs() <= halfHeight) {
           var drawNode = ARNode(
               type: NodeType.localGLTF2,
               uri: "assets/models/cube.glb", 
               position: localPos, 
               scale: vector.Vector3(0.01, 0.01, 0.01),
           );

           arObjectManager?.addNode(drawNode, parentAnchor: _activePosterAnchor);
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Scanner & Graff'),
        backgroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          // 1. STRATUL 3D: Camera AR care rulează continuu în fundal
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.none,
          ),

          // 2. STRATUL UI: Se modifică în funcție de ce facem
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

  // UI - Mod Scanare
  Widget _buildScanningUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.crop_free, size: 100, color: Colors.white54),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black54,
            child: const Text(
              "Îndreaptă camera spre un poster...",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  // UI - Pop-up
  Widget _buildPopupUI() {
    return Container(
      color: Colors.black54, // Dimming background
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Poster Detectat!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Do you want to join $_detectedRoomName?",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentState =
                              AppState.scanning; // Revenim la scanare
                          _activePosterAnchor = null;
                        });
                      },
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentState =
                              AppState.drawing; // Trecem direct la desen!
                        });
                      },
                      child: const Text("Join"),
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

  // UI - Mod Desenare
  Widget _buildDrawingUI() {
    return Stack(
      children: [
        // Panou invizibil pentru a capta desenul pe ecran
        GestureDetector(
          onPanUpdate: _onScreenDrag,
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // Buton iesire
        Positioned(
          top: 20,
          left: 20,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () {
              setState(() {
                _currentState = AppState.scanning;
                _activePosterAnchor = null;
              });
            },
          ),
        ),

        // Color Picker
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorButton(Colors.red),
              _buildColorButton(Colors.green),
              _buildColorButton(Colors.blue),
              _buildColorButton(Colors.yellow),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorButton(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
      },
      child: Container(
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
