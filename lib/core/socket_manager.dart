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

  void joinPoster(String posterId) => socket?.emit('joinPoster', posterId);

  void sendDraw(Map<String, dynamic> data) => socket?.emit('draw', data);

  void onDraw(void Function(dynamic data) handler) => socket?.on('draw', handler);

  void offDraw() => socket?.off('draw');
}
