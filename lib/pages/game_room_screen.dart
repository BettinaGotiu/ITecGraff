import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// IMPORTĂ FIȘIERUL TĂU STROKE.DART AICI:
import '../models/stroke.dart'; // Ajustează calea dacă e nevoie
import '../services/socket_service.dart'; // Asigură-te că folosești SocketService creat anterior

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
  final SocketService _socketService = SocketService();

  late String currentUserId;
  String currentTeamId = "";

  List<DrawPoint> localStrokes = [];
  List<DrawPoint> remoteStrokes = [];
  List<DrawPoint> batchQueue = [];

  double currentBrushSize = 10.0;
  String currentColor = "#FF0000";

  @override
  void initState() {
    super.initState();
    _initializeUserAndSocket();
  }

  Future<void> _initializeUserAndSocket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() => currentTeamId = doc.get('teamId'));
      }

      // Înlocuiește 'joinPoster' cu metoda existentă 'connectAndJoin'
      _socketService.connectAndJoin(
        currentUserId,
        currentTeamId,
        widget.posterId,
      );

      // Înlocuiește 'onDraw' cu ascultarea stream-ului 'drawUpdates'
      _socketService.drawUpdates.listen((data) {
        List strokesData = data['strokes'];
        setState(() {
          remoteStrokes.addAll(strokesData.map((s) => DrawPoint.fromJson(s)));
        });
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    RenderBox box = context.findRenderObject() as RenderBox;
    Offset localPosition = box.globalToLocal(details.globalPosition);

    DrawPoint point = DrawPoint(
      x: localPosition.dx,
      y: localPosition.dy,
      brushSize: currentBrushSize,
      color: currentColor,
    );

    setState(() {
      localStrokes.add(point);
      batchQueue.add(point);
    });

    if (batchQueue.length >= 10) _sendBatch();
  }

  void _onPanEnd(DragEndDetails details) => _sendBatch();

  void _sendBatch() {
    if (batchQueue.isEmpty) return;
    _socketService.sendDrawBatch(
      widget.posterId,
      currentUserId,
      currentTeamId,
      batchQueue.map((s) => s.toJson()).toList(),
    );
    batchQueue.clear();
  }

  @override
  void dispose() {
    _sendBatch();
    _socketService.leaveRoom(widget.posterId, currentUserId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2D Game Room')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.circle, color: Colors.red),
                onPressed: () => currentColor = "#FF0000",
              ),
              IconButton(
                icon: const Icon(Icons.circle, color: Colors.blue),
                onPressed: () => currentColor = "#0000FF",
              ),
              Slider(
                value: currentBrushSize,
                min: 2,
                max: 20,
                onChanged: (v) => setState(() => currentBrushSize = v),
              ),
            ],
          ),
          Expanded(
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(widget.imagePath, fit: BoxFit.contain),
                  ),
                  CustomPaint(
                    painter: DrawingPainter(localStrokes, remoteStrokes),
                    size: Size.infinite,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawPoint> local;
  final List<DrawPoint> remote;

  DrawingPainter(this.local, this.remote);

  @override
  void paint(Canvas canvas, Size size) {
    _drawStrokes(canvas, remote);
    _drawStrokes(canvas, local);
  }

  void _drawStrokes(Canvas canvas, List<DrawPoint> strokes) {
    for (var point in strokes) {
      String hexColor = point.color.replaceAll("#", "");
      if (hexColor.length == 6) hexColor = "FF$hexColor";

      final paint = Paint()
        ..color = Color(int.parse("0x$hexColor"))
        ..strokeCap = StrokeCap.round
        ..strokeWidth = point.brushSize;
      canvas.drawPoints(PointMode.points, [Offset(point.x, point.y)], paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
