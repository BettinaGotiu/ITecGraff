import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  // --- SINGLETON PATTERN ---
  // Asta previne crearea mai multor conexiuni și deconectarea la Hot Reload / Rebuild
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;

  // ATENȚIE: 192.168.56.1 este de obicei VirtualBox.
  // Folosește 10.0.2.2 pentru Android Emulator sau IP-ul rețelei WiFi (ex: 192.168.1.5) pt telefon fizic
  final String serverUrl =
      'https://rossie-aristolochiaceous-lopsidedly.ngrok-free.dev';

  // --- STREAM CONTROLLERS ---
  final _playerJoinedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _userLeftController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _drawUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _gameResultController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _timerUpdateController =
      StreamController<dynamic>.broadcast(); // Lăsat dynamic pt int/Map
  final _roomStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _rivalEnteredController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _sideEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  // --- GETTERS ---
  Stream<Map<String, dynamic>> get playerJoined =>
      _playerJoinedController.stream;
  Stream<Map<String, dynamic>> get userLeft => _userLeftController.stream;
  Stream<Map<String, dynamic>> get drawUpdates => _drawUpdateController.stream;
  Stream<Map<String, dynamic>> get gameResults => _gameResultController.stream;
  Stream<dynamic> get timerUpdates => _timerUpdateController.stream;
  Stream<Map<String, dynamic>> get roomState => _roomStateController.stream;
  Stream<Map<String, dynamic>> get rivalEntered =>
      _rivalEnteredController.stream;
  Stream<Map<String, dynamic>> get sideEvent => _sideEventController.stream;

  void connectAndRegister(
    String userId,
    String username,
    String teamId,
    int level,
    String posterId,
  ) {
    // Dacă e deja conectat, nu recreăm conexiunea, ci doar trimitem joinRoom din nou
    if (socket != null && socket!.connected) {
      _join(userId, teamId, posterId, username);
      return;
    }

    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('✅ SUCCESS: Connected to Socket.IO Server');

      // 1. Backend-ul cere registerUser mai întâi
      socket!.emit('registerUser', {
        'userId': userId,
        'username': username,
        'teamId': teamId,
        'level': level,
      });

      // 2. Apoi trimitem joinRoom
      _join(userId, teamId, posterId, username);
    });

    // --- ASCULTĂM EVENIMENTELE EMISE DE BACKEND ---
    socket!.on(
      'playerJoined',
      (data) => _playerJoinedController.add(Map<String, dynamic>.from(data)),
    );
    socket!.on(
      'userLeft',
      (data) => _userLeftController.add(Map<String, dynamic>.from(data)),
    );
    socket!.on(
      'drawUpdate',
      (data) => _drawUpdateController.add(Map<String, dynamic>.from(data)),
    );
    socket!.on(
      'gameResult',
      (data) => _gameResultController.add(Map<String, dynamic>.from(data)),
    );
    socket!.on(
      'roomState',
      (data) => _roomStateController.add(Map<String, dynamic>.from(data)),
    );
    socket!.on('timerUpdate', (data) => _timerUpdateController.add(data));
    socket!.on(
      'rivalEntered',
      (data) => _rivalEnteredController.add(Map<String, dynamic>.from(data)),
    );
    socket!.on(
      'sideEvent',
      (data) => _sideEventController.add(Map<String, dynamic>.from(data)),
    );

    socket!.onError((error) => print("❌ Socket Error: $error"));
    socket!.onDisconnect((_) => print("⚠️ Socket Disconnected"));
  }

  void _join(String userId, String teamId, String posterId, String username) {
    socket!.emit('joinRoom', {
      'userId': userId,
      'teamId': teamId,
      'posterId': posterId,
      'username': username,
    });
  }

  void sendDrawBatch(
    String posterId,
    String userId,
    String teamId,
    List<Map<String, dynamic>> strokes,
  ) {
    if (strokes.isNotEmpty) {
      socket?.emit('drawBatch', {
        'posterId': posterId,
        'userId': userId,
        'teamId': teamId,
        'strokes': strokes,
      });
    }
  }

  void leaveRoom(String posterId, String userId) {
    socket?.emit('leaveRoom', {'posterId': posterId, 'userId': userId});
    socket?.disconnect();
  }

  void dispose() {
    // NU MAI ÎNCHIDEM STREAM-URILE AICI!
    // Deoarece SocketService e un Singleton, stream-urile trebuie să trăiască atâta timp
    // cât rulează aplicația. Dacă le închidem, la a doua intrare în joc va da crash (Bad State).
  }
}
