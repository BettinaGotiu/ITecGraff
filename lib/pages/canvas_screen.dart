import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/socket_manager.dart';
import '../models/stroke.dart';
import 'scan_screen.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key, this.initialPosterId});

  final String? initialPosterId;

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  String? posterId;
  final List<Stroke> strokes = <Stroke>[];
  Stroke? current;
  final SocketManager sm = SocketManager();

  @override
  void initState() {
    super.initState();
    posterId = widget.initialPosterId;

    sm.connect('http://10.0.2.2:3000');
    sm.onDraw((data) {
      if (!mounted) return;
      final incoming = Stroke.fromJson(Map<String, dynamic>.from(data as Map));
      setState(() => strokes.add(incoming));
    });
  }

  Future<void> _ensurePoster() async {
    if (posterId != null) return;

    final id = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );

    if (id == null) return;

    posterId = id;
    sm.joinPoster(id);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    sm.offDraw();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ensurePoster(),
      builder: (context, snapshot) {
        if (posterId == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Poster: $posterId'),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () async {
                  final id = await Navigator.push<String?>(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanScreen()),
                  );
                  if (id == null) return;
                  posterId = id;
                  sm.joinPoster(id);
                  if (mounted) setState(() => strokes.clear());
                },
              ),
            ],
          ),
          body: GestureDetector(
            onPanStart: (details) {
              final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
              current = Stroke(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                points: [details.localPosition],
                color: Colors.pinkAccent.value,
                width: 4,
                userId: userId,
              );
              setState(() => strokes.add(current!));
            },
            onPanUpdate: (details) {
              current?.points.add(details.localPosition);
              setState(() {});
            },
            onPanEnd: (_) {
              if (current == null) return;

              sm.sendDraw({
                'posterId': posterId,
                'team': 'pink',
                'stroke': current!.toJson(),
              });
              current = null;
            },
            child: CustomPaint(
              painter: _CanvasPainter(strokes),
              child: Container(color: Colors.black.withValues(alpha: 0.88)),
            ),
          ),
        );
      },
    );
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter(this.strokes);

  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = Color(stroke.color)
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (stroke.points.length < 2) continue;

      for (var i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) => true;
}
