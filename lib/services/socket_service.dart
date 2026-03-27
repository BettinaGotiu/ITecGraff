import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class StrokeData {
  final Map<String, dynamic> stroke;
  final String team;

  StrokeData({required this.stroke, required this.team});

  factory StrokeData.fromMap(Map<String, dynamic> data) {
    return StrokeData(
      stroke: data['stroke'] ?? {},
      team: data['team'] ?? 'Unknown',
    );
  }
}

class SocketService extends ChangeNotifier {
  late IO.Socket _socket;
  String? _currentRoom;

  // Storing strokes received from the backend
  List<StrokeData> _remoteStrokes = [];
  List<StrokeData> get remoteStrokes => _remoteStrokes;

  void connect(String serverUrl) {
    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket.connect();

    _socket.onConnect((_) {
      print('Connected to Socket.IO backend');
    });

    _socket.on('initialCanvas', (data) {
      // Received all previous strokes
      if (data is Map) {
         data.forEach((userEmail, strokesList) {
           for(var s in strokesList) {
              _remoteStrokes.add(StrokeData.fromMap(s));
           }
         });
         notifyListeners();
      }
    });

    _socket.on('draw', (data) {
      // New stroke from another user
      _remoteStrokes.add(StrokeData.fromMap(data));
      notifyListeners();
    });

    _socket.onDisconnect((_) => print('Disconnected from backend'));
  }

  void joinPosterRoom(String posterId, String email) {
    _currentRoom = posterId;
    _remoteStrokes.clear();
    _socket.emit('joinPoster', {'posterId': posterId, 'email': email});
    notifyListeners();
  }

  void sendStroke(Map<String, dynamic> stroke, String team, String email) {
    if (_currentRoom == null) return;
    
    final payload = {
      'posterId': _currentRoom,
      'email': email,
      'team': team,
      'stroke': stroke,
    };
    
    _socket.emit('draw', payload);
  }

  void disconnect() {
    _socket.disconnect();
  }
}
