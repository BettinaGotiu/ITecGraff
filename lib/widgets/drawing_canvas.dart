import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/stroke.dart';

class DrawingCanvas extends StatelessWidget {
  final String imagePath;
  final List<DrawPoint> localPoints;
  final List<DrawPoint> remotePoints;
  final double currentBrushSize;
  final String currentColor;
  final bool isEraser;
  final Function(DrawPoint) onStrokeUpdate;
  final VoidCallback onStrokeEnd;

  const DrawingCanvas({
    Key? key,
    required this.imagePath,
    required this.localPoints,
    required this.remotePoints,
    required this.currentBrushSize,
    required this.currentColor,
    required this.isEraser,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onPanUpdate: (details) {
                RenderBox box = context.findRenderObject() as RenderBox;
                Offset localPos = box.globalToLocal(details.globalPosition);

                // Ensure drawing stays within bounds
                if (localPos.dx >= 0 &&
                    localPos.dx <= constraints.maxWidth &&
                    localPos.dy >= 0 &&
                    localPos.dy <= constraints.maxHeight) {
                  onStrokeUpdate(
                    DrawPoint(
                      x: localPos.dx,
                      y: localPos.dy,
                      brushSize: currentBrushSize,
                      color: isEraser ? "#00000000" : currentColor,
                    ),
                  );
                }
              },
              onPanEnd: (_) => onStrokeEnd(),
              child: Stack(
                children: [
                  // Poster Background
                  Image.asset(
                    imagePath,
                    width: constraints.maxWidth,
                    fit: BoxFit.contain, // Keeps poster aspect ratio
                  ),
                  // Drawing Layer
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CanvasPainter(localPoints, remotePoints),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<DrawPoint> local;
  final List<DrawPoint> remote;

  CanvasPainter(this.local, this.remote);

  void _drawPoints(Canvas canvas, List<DrawPoint> points) {
    if (points.isEmpty) return;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      // Handle Eraser (Transparent color)
      bool isErase = p1.color == "#00000000";

      String hexColor = p1.color.replaceAll("#", "");
      if (hexColor.length == 6) hexColor = "FF$hexColor";
      Color strokeColor = Color(int.parse("0x$hexColor"));

      final paint = Paint()
        ..strokeWidth = p1.brushSize
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..blendMode = isErase ? BlendMode.clear : BlendMode.srcOver
        ..color = isErase ? Colors.transparent : strokeColor;

      final distance = (Offset(p1.x, p1.y) - Offset(p2.x, p2.y)).distance;
      if (distance < 50.0) {
        canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), paint);
      } else {
        canvas.drawPoints(PointMode.points, [Offset(p1.x, p1.y)], paint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    _drawPoints(canvas, remote);
    _drawPoints(canvas, local);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}
