import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OVERRIDE',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7B3EFF), // neon purple
        brightness: Brightness.dark,
      ),
      home: const AuthGate(),
    );
  }
}
