import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  late IO.Socket socket;
  final String serverUrl = 'http://192.168.56.1:3000'; // IP-ul tău actual

  final _playerJoinedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _drawUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _gameResultController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get playerJoined =>
      _playerJoinedController.stream;
  Stream<Map<String, dynamic>> get drawUpdates => _drawUpdateController.stream;
  Stream<Map<String, dynamic>> get gameResults => _gameResultController.stream;

  // AM ADĂUGAT username CA PARAMETRU AICI:
  void connectAndJoin(
    String userId,
    String teamId,
    String posterId,
    String username,
  ) {
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected to Socket.IO Server');
      socket.emit('joinRoom', {
        'userId': userId,
        'teamId': teamId,
        'posterId': posterId,
        'username': username, // Trimitem username-ul curat
      });
    });

    socket.on('playerJoined', (data) {
      _playerJoinedController.add(Map<String, dynamic>.from(data));
    });

    socket.on('drawUpdate', (data) {
      _drawUpdateController.add(Map<String, dynamic>.from(data));
    });

    socket.on('gameResult', (data) {
      _gameResultController.add(Map<String, dynamic>.from(data));
    });

    socket.onError((error) => print("Socket Error: $error"));
    socket.onDisconnect((_) => print("Socket Disconnected"));
  }

  void sendDrawBatch(
    String posterId,
    String userId,
    String teamId,
    List<Map<String, dynamic>> strokes,
  ) {
    if (strokes.isNotEmpty) {
      socket.emit('drawBatch', {
        'posterId': posterId,
        'userId': userId,
        'teamId': teamId,
        'strokes': strokes,
      });
    }
  }

  void leaveRoom(String posterId, String userId) {
    socket.emit('leaveRoom', {'posterId': posterId, 'userId': userId});
    socket.disconnect();
  }

  void dispose() {
    _playerJoinedController.close();
    _drawUpdateController.close();
    _gameResultController.close();
  }
}
