import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/socket_manager.dart';
import '../models/stroke.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GameRoomScreen – collaborative drawing room for a scanned poster.
//
// Features:
//  • Poster image fetched from local assets and displayed fullscreen.
//  • Left sidebar: color picker, brush size slider, brush shape selector.
//  • Drawing canvas overlaid on the poster; strokes are synced via Socket.IO.
//  • Each user's strokes are identified separately (userId from Firebase Auth).
//  • Battle mode: approximate pixel-coverage per user displayed in real time.
//  • Stroke points are batched and sent to the backend on pan-end (or every
//    _kBatchSize points for very long strokes).
// ─────────────────────────────────────────────────────────────────────────────

/// Minimum number of points to accumulate before emitting an intermediate
/// batch to the backend (keeps very long strokes from being dropped on
/// connection loss while still being efficient).
const int _kBatchSize = 60;

class GameRoomScreen extends StatefulWidget {
  final String posterId; // e.g. "afis1"

  const GameRoomScreen({Key? key, required this.posterId}) : super(key: key);

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  // ── Socket ─────────────────────────────────────────────────────────────────
  final _sm = SocketManager();

  // ── User identity ──────────────────────────────────────────────────────────
  late final String _userId;

  // ── Strokes: userId → list of strokes drawn by that user ──────────────────
  final Map<String, List<Stroke>> _strokesByUser = {};

  // ── Current stroke being drawn (local) ────────────────────────────────────
  Stroke? _current;

  // ── Brush options ──────────────────────────────────────────────────────────
  Color _brushColor = Colors.pinkAccent;
  double _brushSize = 5.0;
  StrokeCap _brushShape = StrokeCap.round;

  // ── Battle mode: approximate coverage (pixels²) per user ──────────────────
  final Map<String, double> _coverage = {};

  // ── Online user count (tracked via socket join/leave events) ──────────────
  int _onlineCount = 1;

  // Palette of selectable colors
  static const _kPalette = [
    Colors.pinkAccent,
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.yellowAccent,
    Colors.greenAccent,
    Colors.cyanAccent,
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.white,
    Colors.black,
  ];

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _userId = FirebaseAuth.instance.currentUser?.uid ?? _randomId();

    // Connect to the socket backend and join this poster's room.
    // Using 10.0.2.2 for Android emulator; replace with real server URL in prod.
    _sm.connect('http://10.0.2.2:3000');
    _sm.joinPoster(widget.posterId);

    // Listen for strokes from other users.
    _sm.onDraw((data) {
      if (!mounted) return;
      try {
        final stroke =
            Stroke.fromJson(Map<String, dynamic>.from(data as Map));
        // Ignore echoes of our own strokes that come back from the server.
        if (stroke.userId == _userId) return;
        setState(() {
          _strokesByUser.putIfAbsent(stroke.userId, () => []).add(stroke);
          _addCoverage(stroke);
        });
      } catch (_) {
        // Malformed data – ignore.
      }
    });

    // Optional: listen for room user-count updates.
    _sm.socket?.on('roomUsers', (count) {
      if (mounted && count is int) {
        setState(() => _onlineCount = count);
      }
    });
  }

  @override
  void dispose() {
    _sm.offDraw();
    _sm.socket?.off('roomUsers');
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _randomId() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  /// Approximate pixel coverage for a stroke (sum of circle areas at each point).
  double _approximateCoverage(Stroke s) {
    final r = s.width / 2;
    return s.points.length * pi * r * r;
  }

  void _addCoverage(Stroke s) {
    _coverage[s.userId] =
        (_coverage[s.userId] ?? 0) + _approximateCoverage(s);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Drawing callbacks
  // ─────────────────────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    final stroke = Stroke(
      id: _randomId(),
      points: [d.localPosition],
      color: _brushColor.value,
      width: _brushSize,
      userId: _userId,
    );
    setState(() {
      _current = stroke;
      _strokesByUser.putIfAbsent(_userId, () => []).add(stroke);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_current == null) return;
    _current!.points.add(d.localPosition);

    // Send an intermediate batch when the stroke grows large enough.
    if (_current!.points.length % _kBatchSize == 0) {
      _emitStroke(_current!);
    }

    setState(() {
      _addCoverage(Stroke(
        id: _current!.id,
        points: [d.localPosition],
        color: _current!.color,
        width: _current!.width,
        userId: _userId,
      ));
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_current == null) return;
    _emitStroke(_current!);
    setState(() => _current = null);
  }

  void _emitStroke(Stroke stroke) {
    _sm.sendDraw({
      'posterId': widget.posterId,
      'team': _userId,
      'stroke': stroke.toJson(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Battle mode helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Sorted coverage entries, largest first.
  List<MapEntry<String, double>> get _leaderboard {
    final entries = _coverage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  String _shortId(String uid) {
    if (uid.length <= 6) return uid;
    return '${uid.substring(0, 3)}…${uid.substring(uid.length - 3)}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBrushSidebar(),
                  Expanded(child: _buildPosterCanvas()),
                ],
              ),
            ),
            _buildBattleBanner(),
          ],
        ),
      ),
    );
  }

  // ── Top app-bar ──────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B3EFF).withOpacity(0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Game Room · ${widget.posterId}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Online users badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7B3EFF).withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7B3EFF), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$_onlineCount',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Clear my strokes
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
            tooltip: 'Șterge desenul meu',
            onPressed: () => setState(() {
              _strokesByUser.remove(_userId);
              _coverage.remove(_userId);
            }),
          ),
        ],
      ),
    );
  }

  // ── Left brush sidebar ───────────────────────────────────────────────────
  Widget _buildBrushSidebar() {
    return Container(
      width: 68,
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Color swatches
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Center(
                    child: Text(
                      'Color',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                ),
                ..._kPalette.map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _brushColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _brushColor == c
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: _brushColor == c
                              ? [
                                  BoxShadow(
                                    color: c.withOpacity(0.6),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 6),

          // Brush size slider (vertical)
          const Text('Size', style: TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          SizedBox(
            height: 100,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: _brushSize,
                min: 2,
                max: 30,
                onChanged: (v) => setState(() => _brushSize = v),
                activeColor: _brushColor,
                inactiveColor: Colors.white12,
              ),
            ),
          ),
          // Size preview dot
          Container(
            width: _brushSize.clamp(4.0, 30.0),
            height: _brushSize.clamp(4.0, 30.0),
            decoration: BoxDecoration(
              color: _brushColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 10),

          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 6),

          // Brush shape selector
          const Text('Shape', style: TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          _shapeButton(StrokeCap.round, Icons.circle, 'Round'),
          _shapeButton(StrokeCap.square, Icons.square, 'Square'),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _shapeButton(StrokeCap cap, IconData icon, String label) {
    final selected = _brushShape == cap;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: GestureDetector(
        onTap: () => setState(() => _brushShape = cap),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF7B3EFF).withOpacity(0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF7B3EFF) : Colors.white12,
            ),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }

  // ── Poster canvas ─────────────────────────────────────────────────────────
  Widget _buildPosterCanvas() {
    final allStrokes = _strokesByUser.values.expand((l) => l).toList();

    return ClipRect(
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster image as background
            Image.asset(
              'assets/posters/${widget.posterId}.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[850],
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_not_supported,
                          color: Colors.white38, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        widget.posterId,
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Drawing layer
            CustomPaint(
              painter: _MultiUserPainter(strokes: allStrokes),
              size: Size.infinite,
            ),
          ],
        ),
      ),
    );
  }

  // ── Battle banner ─────────────────────────────────────────────────────────
  Widget _buildBattleBanner() {
    final lb = _leaderboard;
    if (lb.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: const Color(0xFF7B3EFF).withOpacity(0.4),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              const Text(
                '⚔️ Battle Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildLeaderboard(lb),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(List<MapEntry<String, double>> lb) {
    final totalCoverage =
        lb.fold<double>(0, (sum, e) => sum + e.value);

    return Column(
      children: lb.take(5).map((entry) {
        final isMe = entry.key == _userId;
        final pct = totalCoverage > 0
            ? (entry.value / totalCoverage * 100)
            : 0.0;
        final color = isMe ? const Color(0xFF7B3EFF) : Colors.blueAccent;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(
                  isMe ? 'You' : _shortId(entry.key),
                  style: TextStyle(
                    color: isMe ? const Color(0xFF7B3EFF) : Colors.white70,
                    fontSize: 11,
                    fontWeight:
                        isMe ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isMe ? const Color(0xFF7B3EFF) : Colors.white54,
                    fontSize: 11,
                    fontWeight:
                        isMe ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter that draws all strokes from all users.
// ─────────────────────────────────────────────────────────────────────────────
class _MultiUserPainter extends CustomPainter {
  final List<Stroke> strokes;

  const _MultiUserPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;

      final paint = Paint()
        ..color = Color(s.color)
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (s.points.length == 1) {
        canvas.drawCircle(s.points.first, s.width / 2, paint);
        continue;
      }

      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (int i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx, s.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MultiUserPainter old) => true;
}
