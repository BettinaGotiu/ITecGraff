// import 'package:flutter/material.dart';

// // Importăm ecranul de AR din folderul pages, așa cum e în proiectul tău
// import 'package:itec/pages/ar_canvas_screen.dart';

// // Importăm ecranul 2D (Game Room) pe care l-am configurat mai devreme

// class PosterPopup extends StatelessWidget {
//   final String posterId;
//   final String imagePath; // Path sau URL-ul pentru imaginea recunoscută

//   const PosterPopup({Key? key, required this.posterId, required this.imagePath})
//     : super(key: key);

//   void _navigateTo(BuildContext context, Widget screen) {
//     Navigator.pop(context); // Închidem dialogul
//     Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Poster Recognized!'),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Image.asset(imagePath, height: 200, fit: BoxFit.contain),
//           const SizedBox(height: 16),
//           const Text('Choose your drawing mode:', textAlign: TextAlign.center),
//         ],
//       ),
//       actionsAlignment: MainAxisAlignment.center,
//       actions: [
//         // Redirectare către AR (Aici am schimbat din posterId în roomId)
//         ElevatedButton.icon(
//           icon: const Icon(Icons.view_in_ar),
//           label: const Text('AR Canvas'),
//           onPressed: () =>
//               _navigateTo(context, ARCanvasScreen(roomId: posterId)),
//         ),

//         // Redirectare către multiplayer-ul 2D
//         ElevatedButton.icon(
//           icon: const Icon(Icons.brush),
//           label: const Text('2D Game Room'),
//           onPressed: () => _navigateTo(
//             context,
//             CanvasScreen(initialPosterId: posterId, imagePath: imagePath),
//           ),
//         ),
//       ],
//     );
//   }
// }
