import 'package:flutter/material.dart';
// import 'package:vector_math/vector_math_64.dart' as vector;
// import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';

class DrawingScreen extends StatefulWidget {
  final String roomName;
  final String posterImageName;

  const DrawingScreen({
    Key? key,
    required this.roomName,
    required this.posterImageName,
  }) : super(key: key);

  @override
  _DrawingScreenState createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  // Variabile pentru plugin-ul AR local
  // ARNode? _posterAnchorNode;

  Color _selectedColor = Colors.red;

  @override
  void initState() {
    super.initState();
    // Aici se configurează sesiunea AR pentru a menține tracking-ul pe posterul deja detectat
  }

  // Funcția apelată când utilizatorul atinge ecranul (Pan/Drag)
  void onPanUpdate(DragUpdateDetails details) {
    // 1. Raycast de la coordonatele 2D ale ecranului (details.localPosition)
    // 2. Găsirea intersecției cu planul 3D al posterului
    // 3. Verificarea limitelor: Punctul 3D de intersecție trebuie să fie în interiorul dimensiunilor posterului.
    // 4. Crearea unui element vizual (ex. o sferă mică / un segment de linie)

    /* Exemplu pseudo-cod AR:
    var hitResult = arSessionManager.raycast(details.localPosition);
    if (hitResult != null && hitResult.node == _posterAnchorNode) {
        var localPosition = hitResult.localPosition;
        
        // Verificăm dacă suntem pe suprafața posterului (ex: lățime 0.5m, înălțime 0.7m)
        if(localPosition.x >= -0.25 && localPosition.x <= 0.25 &&
           localPosition.y >= -0.35 && localPosition.y <= 0.35) {
             
             var drawingPoint = ARNode(
               type: NodeType.sphere,
               position: localPosition,
               materials: [ARMaterial(color: _selectedColor)]
             );
             // FOARTE IMPORTANT: Adăugăm punctul de desen ca fiind "copil" al ancorei posterului
             // Astfel încât, când posterul se mișcă/camera se mișcă, desenul rămâne lipit de doza de Cola
             arObjectManager.addChildNode(_posterAnchorNode, drawingPoint);
        }
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              // Curăță toate nodurile de desen din _posterAnchorNode
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Widget-ul AR
          GestureDetector(
            onPanUpdate: onPanUpdate,
            child: Container(
              color: Colors.grey[900], // Placeholder pentru feed-ul camerei AR
              width: double.infinity,
              height: double.infinity,
              child: const Center(
                child: Text(
                  "[AR Camera Feed]\nDesenează peste poster pe ecran.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),

          // Color Picker UI
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
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
      ),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _selectedColor == color ? Colors.white : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }
}
