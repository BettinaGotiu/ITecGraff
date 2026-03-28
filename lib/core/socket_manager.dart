import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketManager {
  SocketManager._internal();

  static final SocketManager _instance = SocketManager._internal();

  factory SocketManager() => _instance;

  io.Socket? socket;

  void connect(String baseUrl) {
    socket ??= io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    if (socket?.connected != true) {
      socket?.connect();
    }
  }

  void disconnect() {
    socket?.disconnect();
  }

  void joinRoom(String userId, String teamId, String posterId) {
    socket?.emit('joinRoom', {
      'userId': userId,
      'teamId': teamId,
      'posterId': posterId,
    });
  }

  void leaveRoom(String userId, String posterId) {
    socket?.emit('leaveRoom', {
      'userId': userId,
      'posterId': posterId,
    });
  }

  void sendDrawBatch(Map<String, dynamic> data) => socket?.emit('drawBatch', data);

  void onPlayerJoined(void Function(dynamic data) handler) => socket?.on('playerJoined', handler);
  void offPlayerJoined() => socket?.off('playerJoined');

  void onDrawUpdate(void Function(dynamic data) handler) => socket?.on('drawUpdate', handler);
  void offDrawUpdate() => socket?.off('drawUpdate');

  void onGameResult(void Function(dynamic data) handler) => socket?.on('gameResult', handler);
  void offGameResult() => socket?.off('gameResult');
}
