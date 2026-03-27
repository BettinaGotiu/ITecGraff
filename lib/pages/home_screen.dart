import 'package:flutter/material.dart';
import 'scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onPosterSelected});
  final ValueChanged<String> onPosterSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('iTEC Override')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bine ai venit!'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan poster'),
              onPressed: () async {
                final id = await Navigator.push<String?>(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                );
                if (id != null) {
                  onPosterSelected(id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Success: $id')));
                  }
                }
              },
            ),
            const SizedBox(height: 20),
            const Text(
              '1. Scanează un poster\n2. Deschide Canvas\n3. Desenează în room-ul posterului',
            ),
          ],
        ),
      ),
    );
  }
}
