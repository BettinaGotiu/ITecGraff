// import 'dart:ui';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';

// // Asigură-te că importurile acestea duc către fișierele tale corecte:
// import '../models/stroke.dart'; // Aici se află DrawPoint și StrokeBatch
// import '../services/socket_service.dart'; // Folosim SocketService-ul pe care l-am creat anterior pentru noul backend
// import 'scan_screen.dart';

// class CanvasScreen extends StatefulWidget {
//   final String? initialPosterId;
//   final String?
//   imagePath; // Opțional: calea către imaginea posterului recunoscut

//   const CanvasScreen({super.key, this.initialPosterId, this.imagePath});

//   @override
//   State<CanvasScreen> createState() => _CanvasScreenState();
// }

// class _CanvasScreenState extends State<CanvasScreen> {
//   String? posterId;

//   // Lista de puncte locale și primite de la alți jucători
//   final List<DrawPoint> localPoints = [];
//   final List<DrawPoint> remotePoints = [];

//   // Coada pentru a trimite punctele în batch-uri (pentru a nu bloca rețeaua)
//   final List<DrawPoint> batchQueue = [];

//   final SocketService sm = SocketService();

//   String currentUserId = 'anonymous';
//   String currentTeamId = 'pink';
//   double currentBrushSize = 4.0;
//   String currentColor = "#FF4081"; // Roz (Pink Accent)

//   @override
//   void initState() {
//     super.initState();
//     posterId = widget.initialPosterId;
//     _initializeGameRoom();
//   }

//   Future<void> _initializeGameRoom() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       currentUserId = user.uid;
//       // Opțional: preia echipa din Firestore
//       final doc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user.uid)
//           .get();
//       if (doc.exists) {
//         currentTeamId = doc.get('teamId') ?? 'pink';
//       }
//     }

//     if (posterId != null) {
//       _connectAndJoinRoom(posterId!);
//     }
//   }

//   void _connectAndJoinRoom(String pId) {
//     // 1. Conectare și joinRoom (folosind noile evenimente backend)
//     sm.connectAndJoin(currentUserId, currentTeamId, pId);

//     // 2. Ascultare drawUpdate de la alți jucători (înlocuiește vechiul onDraw)
//     sm.drawUpdates.listen((data) {
//       if (!mounted) return;

//       // Backend-ul trimite { posterId, teamId, strokes: [...] }
//       final incomingBatch = StrokeBatch.fromJson(
//         Map<String, dynamic>.from(data),
//       );

//       setState(() {
//         remotePoints.addAll(incomingBatch.strokes);
//       });
//     });

//     // 3. Ascultare gameResult
//     sm.gameResults.listen((data) {
//       if (!mounted) return;
//       _showGameResultDialog(data);
//     });
//   }

//   @override
//   void dispose() {
//     _sendRemainingBatch();
//     if (posterId != null) {
//       sm.leaveRoom(posterId!, currentUserId);
//     }
//     super.dispose();
//   }

//   Future<void> _pickPoster() async {
//     final id = await Navigator.push<String?>(
//       context,
//       MaterialPageRoute(builder: (_) => const ScanScreen()),
//     );
//     if (id == null) return;

//     // Curățăm ecranul pentru un poster nou
//     setState(() {
//       posterId = id;
//       localPoints.clear();
//       remotePoints.clear();
//       batchQueue.clear();
//     });

//     _connectAndJoinRoom(id);
//   }

//   void _onPanUpdate(DragUpdateDetails details) {
//     RenderBox box = context.findRenderObject() as RenderBox;
//     Offset localPosition = box.globalToLocal(details.globalPosition);

//     final point = DrawPoint(
//       x: localPosition.dx,
//       y: localPosition.dy,
//       brushSize: currentBrushSize,
//       color: currentColor,
//     );

//     setState(() {
//       localPoints.add(point);
//       batchQueue.add(point);
//     });

//     // Trimitem batch-ul dacă s-au adunat destule puncte
//     if (batchQueue.length >= 10) {
//       _sendRemainingBatch();
//     }
//   }

//   void _onPanEnd(DragEndDetails details) {
//     _sendRemainingBatch();
//   }

//   void _sendRemainingBatch() {
//     if (batchQueue.isEmpty || posterId == null) return;

//     // Folosim noile funcții pentru batching (înlocuiește sendDraw)
//     sm.sendDrawBatch(
//       posterId!,
//       currentUserId,
//       currentTeamId,
//       batchQueue.map((p) => p.toJson()).toList(),
//     );
//     batchQueue.clear();
//   }

//   void _showGameResultDialog(Map<String, dynamic> result) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         title: const Text("Joc Terminat!"),
//         content: Text(
//           "Câștigători: ${result['winnerTeam']}\nAcoperire: ${result['coverage']}%\nXP: ${result['xp'][currentUserId] ?? 0}",
//         ),
//         actions: [
//           TextButton(
//             onPressed: () =>
//                 Navigator.popUntil(context, (route) => route.isFirst),
//             child: const Text("Ieșire"),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (posterId == null) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Game Room')),
//         body: Center(
//           child: ElevatedButton.icon(
//             icon: const Icon(Icons.qr_code_scanner),
//             label: const Text('Scan poster to play'),
//             onPressed: _pickPoster,
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Poster: $posterId'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.qr_code_scanner),
//             onPressed: _pickPoster,
//           ),
//         ],
//       ),
//       body: GestureDetector(
//         onPanUpdate: _onPanUpdate,
//         onPanEnd: _onPanEnd,
//         child: Stack(
//           children: [
//             // Fundalul cu posterul, dacă există imagine, altfel negru
//             Container(
//               color: widget.imagePath == null
//                   ? Colors.black.withOpacity(0.88)
//                   : null,
//               width: double.infinity,
//               height: double.infinity,
//               child: widget.imagePath != null
//                   ? Image.asset(widget.imagePath!, fit: BoxFit.cover)
//                   : null,
//             ),
//             // Layer-ul de desenare
//             CustomPaint(
//               painter: _CanvasPainter(localPoints, remotePoints),
//               size: Size.infinite,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _CanvasPainter extends CustomPainter {
//   final List<DrawPoint> localPoints;
//   final List<DrawPoint> remotePoints;

//   _CanvasPainter(this.localPoints, this.remotePoints);

//   void _drawPoints(Canvas canvas, List<DrawPoint> points) {
//     if (points.isEmpty) return;

//     for (int i = 0; i < points.length - 1; i++) {
//       final p1 = points[i];
//       final p2 = points[i + 1];

//       // Convertim hex-ul în Color (ex: #FF4081 -> 0xFFFF4081)
//       String hexColor = p1.color.replaceAll("#", "");
//       if (hexColor.length == 6) hexColor = "FF$hexColor";
//       Color strokeColor = Color(int.parse("0x$hexColor"));

//       final paint = Paint()
//         ..color = strokeColor
//         ..strokeWidth = p1.brushSize
//         ..style = PaintingStyle.stroke
//         ..strokeCap = StrokeCap.round;

//       // Desenăm linia doar dacă punctele sunt foarte apropiate (pentru a simula o linie continuă din batch-uri)
//       // Dacă distanța e mare, înseamnă că utilizatorul a ridicat degetul (nou stroke)
//       final distance = (Offset(p1.x, p1.y) - Offset(p2.x, p2.y)).distance;
//       if (distance < 50.0) {
//         canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), paint);
//       } else {
//         // Dacă e doar un punct singular izolat
//         canvas.drawPoints(PointMode.points, [Offset(p1.x, p1.y)], paint);
//       }
//     }

//     // Ultimul punct
//     if (points.isNotEmpty) {
//       final last = points.last;
//       String hexColor = last.color.replaceAll("#", "");
//       if (hexColor.length == 6) hexColor = "FF$hexColor";
//       final paint = Paint()
//         ..color = Color(int.parse("0x$hexColor"))
//         ..strokeWidth = last.brushSize
//         ..strokeCap = StrokeCap.round;
//       canvas.drawPoints(PointMode.points, [Offset(last.x, last.y)], paint);
//     }
//   }

//   @override
//   void paint(Canvas canvas, Size size) {
//     _drawPoints(canvas, remotePoints);
//     _drawPoints(canvas, localPoints);
//   }

//   @override
//   bool shouldRepaint(covariant _CanvasPainter oldDelegate) => true;
// }
