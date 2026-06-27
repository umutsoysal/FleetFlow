import 'dart:async';
import 'dart:convert';
import 'dart:io';

class NMEAConnection {
  final String host;
  final int port;
  final void Function(String line) onData;
  final VoidCallback onConnected;
  final void Function(String message) onError;
  final VoidCallback onDisconnected;

  Socket? _socket;
  String _buffer = '';

  NMEAConnection({
    required this.host,
    required this.port,
    required this.onData,
    required this.onConnected,
    required this.onError,
    required this.onDisconnected,
  });

  Future<void> connect() async {
    try {
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      onConnected();

      _socket!.cast<List<int>>().transform(ascii.decoder).listen(
        _onDataReceived,
        onError: (error) {
          onError(error.toString());
        },
        onDone: () {
          onDisconnected();
        },
        cancelOnError: false,
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
    _buffer = '';
  }

  void _onDataReceived(String data) {
    _buffer += data;

    while (true) {
      final newlineIdx = _buffer.indexOf('\n');
      if (newlineIdx == -1) break;

      var line = _buffer.substring(0, newlineIdx);
      _buffer = _buffer.substring(newlineIdx + 1);

      line = line.replaceAll('\r', '').trim();
      if (line.isNotEmpty) {
        onData(line);
      }
    }
  }
}

typedef VoidCallback = void Function();
