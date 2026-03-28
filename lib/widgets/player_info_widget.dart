import 'package:flutter/material.dart';

class PlayerInfoWidget extends StatelessWidget {
  final int playerCount;

  const PlayerInfoWidget({Key? key, required this.playerCount})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people, size: 16, color: Colors.blueAccent),
          const SizedBox(width: 6),
          Text(
            "$playerCount",
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
