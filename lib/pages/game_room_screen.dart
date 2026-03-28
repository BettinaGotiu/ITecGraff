import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/socket_service.dart';
import '../models/stroke.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/toolbar_widget.dart';
import '../widgets/player_info_widget.dart';

class GameRoomScreen extends StatefulWidget {
  final String posterId;
  final String imagePath;

  const GameRoomScreen({
    Key? key,
    required this.posterId,
    required this.imagePath,
  }) : super(key: key);

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  final SocketService sm = SocketService();

  String currentUserId = 'anonymous';
  String currentTeamId = 'pink';

  // State for drawing tools
  double currentBrushSize = 5.0;
  String currentColor = "#FF4081"; // Default pink
  bool isEraser = false;

  // State for Game Data
  int playerCount = 1;
  List<DrawPoint> remotePoints = [];
  List<DrawPoint> localPoints = [];
  List<DrawPoint> batchQueue = [];

  @override
  void initState() {
    super.initState();
    _initializeGameRoom();
  }

  Future<void> _initializeGameRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        currentTeamId = doc.get('teamId') ?? 'pink';
      }
    }

    sm.connectAndJoin(currentUserId, currentTeamId, widget.posterId);

    // Listen for new players
    sm.playerJoined.listen((data) {
      if (mounted) setState(() => playerCount++);
    });

    // Listen for incoming strokes
    sm.drawUpdates.listen((data) {
      if (!mounted) return;
      final incomingBatch = StrokeBatch.fromJson(
        Map<String, dynamic>.from(data),
      );
      setState(() {
        remotePoints.addAll(incomingBatch.strokes);
      });
    });

    // Listen for game end
    sm.gameResults.listen((data) {
      if (!mounted) return;
      _showGameResultDialog(data);
    });
  }

  void _onStrokeDrawn(DrawPoint point) {
    setState(() {
      localPoints.add(point);
      batchQueue.add(point);
    });

    if (batchQueue.length >= 10) {
      _sendBatch();
    }
  }

  void _onStrokeEnded() {
    _sendBatch();
  }

  void _sendBatch() {
    if (batchQueue.isEmpty) return;
    sm.sendDrawBatch(
      widget.posterId,
      currentUserId,
      currentTeamId,
      batchQueue.map((p) => p.toJson()).toList(),
    );
    batchQueue.clear();
  }

  void _showGameResultDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Game Over!"),
        content: Text(
          "Winner: ${result['winnerTeam']}\nCoverage: ${result['coverage']}%\nXP: ${result['xp'][currentUserId] ?? 0}",
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("Exit"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sendBatch();
    sm.leaveRoom(widget.posterId, currentUserId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Clean modern background
      appBar: AppBar(
        title: Text('Graff Room: ${widget.posterId}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [PlayerInfoWidget(playerCount: playerCount)],
      ),
      body: Column(
        children: [
          // The Toolbar at the top
          ToolbarWidget(
            currentColor: isEraser ? "#00000000" : currentColor,
            currentBrushSize: currentBrushSize,
            isEraser: isEraser,
            onColorSelected: (color) => setState(() {
              currentColor = color;
              isEraser = false;
            }),
            onBrushSizeChanged: (size) =>
                setState(() => currentBrushSize = size),
            onEraserToggled: () => setState(() => isEraser = true),
          ),

          const SizedBox(height: 20),

          // The Framed Poster Canvas
          Expanded(
            child: Center(
              child: DrawingCanvas(
                imagePath: widget.imagePath,
                localPoints: localPoints,
                remotePoints: remotePoints,
                currentBrushSize: currentBrushSize,
                currentColor: isEraser
                    ? "#00000000"
                    : currentColor, // Eraser acts as transparent/clear
                isEraser: isEraser,
                onStrokeUpdate: _onStrokeDrawn,
                onStrokeEnd: _onStrokeEnded,
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
