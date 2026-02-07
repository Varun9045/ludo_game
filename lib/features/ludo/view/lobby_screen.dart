import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../services/auth_service.dart';
import '../../../services/realtime_rooms.dart';
import '../../../services/room_code.dart';
import 'ludo_board_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final AuthService _auth;
  late final RealtimeRooms _rooms;
  String? _playerId;
  bool _loading = true;
  int? _maxPlayers;

  @override
  void initState() {
    super.initState();
    _auth = AuthService(FirebaseAuth.instance);
    _rooms = RealtimeRooms(FirebaseDatabase.instance);
    _initAuth();
  }

  Future<void> _initAuth() async {
    final id = await _auth.ensureSignedIn();
    setState(() {
      _playerId = id;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_maxPlayers == null) {
      return _playerCountPicker();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Ludo Lobby",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _createRoom,
                child: const Text("Create Room"),
              ),
              ElevatedButton(
                onPressed: _joinRoomDialog,
                child: const Text("Join Room"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Open Rooms",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<RoomSummary>>(
              stream: _rooms.watchWaitingRooms(),
              builder: (context, snapshot) {
                final rooms = snapshot.data ?? [];
                if (rooms.isEmpty) {
                  return const Center(child: Text("No rooms available"));
                }
                return ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return ListTile(
                      title: Text("Room ${room.code}"),
                      subtitle:
                          Text("${room.connected}/${room.maxPlayers} online"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _joinRoom(room.code),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your ID: ${_playerId ?? '-'}",
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _createRoom() async {
    final code = generateRoomCode();
    await _rooms.createRoom(
      code: code,
      hostPlayerId: _playerId!,
      maxPlayers: _maxPlayers ?? 4,
    );
    _openRoom(code);
  }

  Future<void> _joinRoomDialog() async {
    final code = await _askRoomCode();
    if (code == null || code.isEmpty) return;
    await _joinRoom(code);
  }

  Future<void> _joinRoom(String code) async {
    await _rooms.joinRoom(code: code, playerId: _playerId!);
    _openRoom(code);
  }

  void _openRoom(String code) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LudoBoardScreen(
          roomCode: code,
          expectedPlayers: _maxPlayers ?? 4,
        ),
      ),
    );
  }

  Future<String?> _askRoomCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Join Room"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter room code"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Join"),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return code?.toUpperCase();
  }

  Widget _playerCountPicker() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "How many players will play?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _playerCountButton(2),
                  _playerCountButton(3),
                  _playerCountButton(4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerCountButton(int count) {
    return ElevatedButton(
      onPressed: () => setState(() => _maxPlayers = count),
      child: Text("$count Players"),
    );
  }
}
