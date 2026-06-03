import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

class TcpMessagingService {
  final int port = 4321;
  ServerSocket? _serverSocket;
  final List<Socket> _clientSockets = [];
  final Map<String, Socket> _peerSockets = {};
  final _uuid = const Uuid();
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final _connectionCountController = StreamController<int>.broadcast();
  Stream<int> get connectionCountStream => _connectionCountController.stream;

  Future<void> startServer() async {
    if (_serverSocket != null) return;
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _serverSocket!.listen((Socket client) {
      _registerSocket(client);
      client.listen(
        (data) => _handleData(data, client),
        onError: (err) => _removeClient(client),
        onDone: () => _removeClient(client),
      );
    });
  }

  Future<void> connectToPeer(String ipAddress) async {
    try {
      final socket = await Socket.connect(ipAddress, port);
      _registerSocket(socket, ipAddress: ipAddress);
      socket.listen(
        (data) => _handleData(data, socket),
        onError: (err) => _removeClient(socket),
        onDone: () => _removeClient(socket),
      );
    } catch (e) {
      _messageController.add({
        'type': 'system',
        'senderId': 'system',
        'displayName': 'Subnet',
        'text': 'Connection failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
        'isAnonymous': false,
      });
    }
  }

  void _handleData(List<int> data, Socket sourceSocket) {
    try {
      final decoded = utf8.decode(data);
      final jsonMsg = jsonDecode(decoded) as Map<String, dynamic>;
      jsonMsg['sourceIp'] = sourceSocket.remoteAddress.address;
      _messageController.add(jsonMsg);

      final type = jsonMsg['type'] ?? 'message';
      final scope = jsonMsg['scope'] ?? 'space';
      if (type == 'message' && scope == 'direct') {
        return;
      }
      if (type == 'message' || type == 'report' || type == 'space_closed') {
        _broadcastData(data, sourceSocket); // broadcast to others
      }
    } catch (e) {
      _messageController.add({
        'type': 'system',
        'senderId': 'system',
        'displayName': 'Subnet',
        'text': 'Could not read an incoming message.',
        'timestamp': DateTime.now().toIso8601String(),
        'isAnonymous': false,
      });
    }
  }

  void _broadcastData(List<int> data, [Socket? excludeSocket]) {
    for (final socket in List<Socket>.from(_clientSockets)) {
      if (socket != excludeSocket) {
        try {
          socket.add(data);
        } catch (_) {
          // ignore failures on write
        }
      }
    }
  }

  void broadcastMessage(Map<String, dynamic> message) {
    final data = utf8.encode(jsonEncode(message));
    _broadcastData(data);
    _messageController.add(message);
  }

  Future<void> sendToPeer(String ipAddress, Map<String, dynamic> message) async {
    final socket = _peerSockets[ipAddress];
    if (socket != null) {
      socket.add(utf8.encode(jsonEncode(message)));
      return;
    }

    final newSocket = await Socket.connect(ipAddress, port);
    _registerSocket(newSocket, ipAddress: ipAddress);
    newSocket.listen(
      (data) => _handleData(data, newSocket),
      onError: (err) => _removeClient(newSocket),
      onDone: () => _removeClient(newSocket),
    );
    newSocket.add(utf8.encode(jsonEncode(message)));
  }

  Future<String> sendChatRequest({
    required String ipAddress,
    required String senderId,
    required String displayName,
    required bool isAnonymous,
    String? spaceId,
    String? spaceName,
    String? accessKey,
  }) async {
    final requestId = _uuid.v4();
    final message = {
      'type': 'chat_request',
      'requestId': requestId,
      'senderId': senderId,
      'displayName': displayName,
      'isAnonymous': isAnonymous,
      'timestamp': DateTime.now().toIso8601String(),
      'spaceId': spaceId,
      'spaceName': spaceName,
      'accessKey': accessKey,
    };
    await sendToPeer(ipAddress, message);
    _messageController.add({...message, 'sourceIp': ipAddress});
    return requestId;
  }

  Future<void> sendChatAccept({
    required String ipAddress,
    required String requestId,
    required String senderId,
    String? spaceId,
  }) async {
    final message = {
      'type': 'chat_accept',
      'requestId': requestId,
      'senderId': senderId,
      'spaceId': spaceId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await sendToPeer(ipAddress, message);
    _messageController.add({...message, 'sourceIp': ipAddress});
  }

  Future<void> sendChatDeny({
    required String ipAddress,
    required String requestId,
    required String senderId,
    String? reason,
  }) async {
    final message = {
      'type': 'chat_deny',
      'requestId': requestId,
      'senderId': senderId,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await sendToPeer(ipAddress, message);
    _messageController.add({...message, 'sourceIp': ipAddress});
  }

  Future<void> sendSpaceReport({
    required String ipAddress,
    required String spaceId,
    required String reporterId,
    required bool isAnonymous,
  }) async {
    final message = {
      'type': 'space_report',
      'spaceId': spaceId,
      'senderId': reporterId,
      'isAnonymous': isAnonymous,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await sendToPeer(ipAddress, message);
    _messageController.add({...message, 'sourceIp': ipAddress});
  }

  void broadcastSpaceClosed({required String spaceId, String? reason}) {
    final message = {
      'type': 'space_closed',
      'spaceId': spaceId,
      'reason': reason ?? 'Space closed',
      'timestamp': DateTime.now().toIso8601String(),
    };
    broadcastMessage(message);
  }

  void sendTypingIndicator({
    required String displayName,
    required bool isTyping,
  }) {
    final message = {
      'type': 'typing',
      'displayName': displayName,
      'isTyping': isTyping,
      'timestamp': DateTime.now().toIso8601String(),
    };
    broadcastMessage(message);
  }

  void sendMessageReaction({
    required String messageId,
    required String emoji,
    required String userId,
    required String displayName,
  }) {
    final message = {
      'type': 'reaction',
      'messageId': messageId,
      'emoji': emoji,
      'userId': userId,
      'displayName': displayName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    broadcastMessage(message);
  }

  void _removeClient(Socket socket) {
    _clientSockets.remove(socket);
    _peerSockets.removeWhere((key, value) => value == socket);
    _connectionCountController.add(_clientSockets.length);
    socket.destroy();
  }

  void stop() {
    _serverSocket?.close();
    for (var s in _clientSockets) {
      s.destroy();
    }
    _clientSockets.clear();
    _peerSockets.clear();
    _messageController.close();
    _connectionCountController.close();
  }

  void _registerSocket(Socket socket, {String? ipAddress}) {
    _clientSockets.add(socket);
    final ip = ipAddress ?? socket.remoteAddress.address;
    _peerSockets[ip] = socket;
    _connectionCountController.add(_clientSockets.length);
  }
}
