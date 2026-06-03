import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class SignalingService {
  WebSocketChannel? _channel;
  final String wsUrl = 'ws://localhost:8080';

  void connect(String roomId, String userId) {
    _channel = IOWebSocketChannel.connect('$wsUrl?room=$roomId&userId=$userId');
  }

  void sendOffer(Map<String, dynamic> offer) {
    _channel?.sink.add(jsonEncode({'type': 'offer', 'data': offer}));
  }

  void sendAnswer(Map<String, dynamic> answer) {
    _channel?.sink.add(jsonEncode({'type': 'answer', 'data': answer}));
  }

  void sendIceCandidate(Map<String, dynamic> candidate) {
    _channel?.sink.add(jsonEncode({'type': 'candidate', 'data': candidate}));
  }

  Stream get onMessage => _channel!.stream.map((data) => jsonDecode(data));

  void close() {
    _channel?.sink.close();
  }
}