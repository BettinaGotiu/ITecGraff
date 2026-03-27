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
  final List<Stroke> strokes = [];
  Stroke? current;
  final sm = SocketManager();

  @override
  void initState() {
    super.initState();
    posterId = widget.initialPosterId;
    sm.connect('http://10.0.2.2:3000'); // pune URL-ul tău
    sm.onDraw((data) {
      if (!mounted) return;
      final incoming = Stroke.fromJson(Map<String, dynamic>.from(data as Map));
      setState(() => strokes.add(incoming));
    });
    if (posterId != null) sm.joinPoster(posterId!);
  }

  @override
  void dispose() {
    sm.offDraw();
    super.dispose();
  }

  Future<void> _pickPoster() async {
    final id = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (id == null) return;
    posterId = id;
    strokes.clear();
    sm.joinPoster(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (posterId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Canvas')),
        body: Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan poster'),
            onPressed: _pickPoster,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Poster: $posterId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _pickPoster,
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
          child: Container(color: Colors.black.withOpacity(0.88)),
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter(this.strokes);
  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = Color(s.color)
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      if (s.points.length < 2) continue;
      for (int i = 0; i < s.points.length - 1; i++) {
        canvas.drawLine(s.points[i], s.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) => true;
}
