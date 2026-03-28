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
  String currentUsername = 'Guest';
  int currentLevel = 1; // NOU: necesar pentru backend

  // State for drawing tools
  double currentBrushSize = 5.0;
  String currentColor = "#FF4081"; // Default pink
  bool isEraser = false;

  // State for Game Data
  List<Map<String, dynamic>> activePlayers = [];
  List<DrawPoint> remotePoints = [];
  List<DrawPoint> localPoints = [];
  List<DrawPoint> batchQueue = [];
  Offset? _lastSentOffset;

  // Real-time data din backend
  int timeLeft = 30;
  Map<String, dynamic> currentCoverage = {'pink': 0, 'blue': 0};

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

      if (doc.exists && doc.data()!.containsKey('teamId')) {
        setState(() {
          currentTeamId = doc.get('teamId');
          currentColor = doc.get('teamColor') ?? '#FF4081'; // Culoarea echipei
          currentUsername = doc.get('username') ?? 'Player';
          currentLevel = doc.get('level') ?? 1;
        });
      } else {
        // Dacă nu are echipă, dăm pop și arătăm eroare
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Te rugăm să te alături unei echipe mai întâi (din meniul Echipe)!',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      activePlayers.add({
        'userId': currentUserId,
        'teamId': currentTeamId,
        'username': currentUsername,
      });
    });

    // FIX: Folosim metoda corectă din noul SocketService
    sm.connectAndRegister(
      currentUserId,
      currentUsername,
      currentTeamId,
      currentLevel,
      widget.posterId,
    );

    // Initial state (gets strokes already drawn by others if you join late)
    sm.roomState.listen((data) {
      if (!mounted) return;
      try {
        setState(() {
          if (data['strokes'] != null) {
            final incomingBatch = StrokeBatch.fromJson(
              Map<String, dynamic>.from(data),
            );
            remotePoints = incomingBatch.strokes;
          }
        });
      } catch (e) {
        print("Error parsing roomState: $e");
      }
    });

    sm.playerJoined.listen((data) {
      if (mounted) {
        setState(() {
          if (!activePlayers.any((p) => p['userId'] == data['userId'])) {
            activePlayers.add(data);
          }
        });
      }
    });

    sm.userLeft.listen((data) {
      if (mounted) {
        setState(() {
          activePlayers.removeWhere((p) => p['userId'] == data['userId']);
        });
      }
    });

    sm.drawUpdates.listen((data) {
      if (!mounted) return;
      final incomingBatch = StrokeBatch.fromJson(
        Map<String, dynamic>.from(data),
      );
      setState(() {
        remotePoints.addAll(incomingBatch.strokes);
      });
    });

    // Ascultăm timer-ul și acoperirea dinamică
    sm.timerUpdates.listen((data) {
      if (!mounted) return;
      setState(() {
        timeLeft = data['timeLeft'] ?? 0;
        if (data['coverage'] != null) {
          currentCoverage = Map<String, dynamic>.from(data['coverage']);
        }
      });
    });

    // Ascultăm rezultatul final (cu validări anti-crash)
    sm.gameResults.listen((data) {
      if (!mounted) return;
      _showGameResultDialog(data);
    });
  }

  void _onStrokeDrawn(DrawPoint point) {
    setState(() {
      localPoints.add(point);
    });

    bool shouldBatch = false;
    if (_lastSentOffset == null) {
      shouldBatch = true;
    } else {
      double dist = (Offset(point.x, point.y) - _lastSentOffset!).distance;
      if (dist > 4.0) shouldBatch = true;
    }

    if (shouldBatch) {
      batchQueue.add(point);
      _lastSentOffset = Offset(point.x, point.y);
    }

    if (batchQueue.length >= 8) {
      _sendBatch();
    }
  }

  void _onStrokeEnded() {
    _sendBatch();
    _lastSentOffset = null;
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
    String winnerTeam = result['winnerTeam'] ?? 'Egalitate';

    // Extragem map-ul cu scorurile echipelor trimise de backend
    Map<String, dynamic> teamScores = result['teamScores'] != null
        ? Map<String, dynamic>.from(result['teamScores'])
        : {};

    // Extragem XP-ul câștigat de jucătorul curent
    int gainedXp = 0;
    if (result['xp'] != null) {
      gainedXp = result['xp'][currentUserId] ?? 0;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  winnerTeam == 'Egalitate'
                      ? "Jocul s-a terminat la egalitate!"
                      : "Echipa $winnerTeam a câștigat!",
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Scor Final Acoperire:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Generăm scorurile dinamic pentru FIECARE echipă din map-ul primit de la backend
              if (teamScores.isNotEmpty)
                ...teamScores.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      "• ${entry.key.toUpperCase()} Team: ${entry.value}%",
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList()
              else
                const Text("Nicio echipă nu a desenat."),

              const Divider(height: 30),
              Center(
                child: Column(
                  children: [
                    const Text(
                      "Ai câștigat",
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      "+ $gainedXp XP",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () {
                // 1. Închidem popup-ul
                Navigator.pop(context);

                // 2. Resetăm state-ul vizual al tablei de desen a jucătorului
                setState(() {
                  localPoints.clear();
                  remotePoints.clear();
                  batchQueue.clear();
                  _lastSentOffset = null;
                  timeLeft = 60; // reset temporar UI până răspunde backend-ul
                  currentCoverage = {};
                });

                // 3. Spunem backend-ului să inițieze/să ne bage în următorul joc
                // Notă: connectAndRegister va refolosi conexiunea și va emite 'joinRoom' în backend
                sm.connectAndRegister(
                  currentUserId,
                  currentUsername,
                  currentTeamId,
                  currentLevel,
                  widget.posterId,
                );
              },
              child: const Text("Joacă din nou"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                // Dacă jucătorul iese din cameră
                sm.leaveRoom(widget.posterId, currentUserId);
                sm.socket?.disconnect();
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text(
                "Ieșire",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _sendBatch();
    sm.leaveRoom(widget.posterId, currentUserId);
    // Deconectăm manual când părăsim camera definitiv
    sm.socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Room: ${widget.posterId}',
              style: const TextStyle(fontSize: 16),
            ),
            // UI pentru Timp și Acoperire în timp real
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 14,
                  color: timeLeft <= 5 ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  '$timeLeft s',
                  style: TextStyle(
                    fontSize: 14,
                    color: timeLeft <= 5 ? Colors.red : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Pink: ${currentCoverage['pink'] ?? 0}% | Blue: ${currentCoverage['blue'] ?? 0}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [PlayerInfoWidget(activePlayers: activePlayers)],
      ),
      body: Column(
        children: [
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
          Expanded(
            child: Center(
              child: DrawingCanvas(
                imagePath: widget.imagePath,
                localPoints: localPoints,
                remotePoints: remotePoints,
                currentBrushSize: currentBrushSize,
                currentColor: isEraser ? "#00000000" : currentColor,
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
