import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../services/auth_service.dart';
import '../../../services/realtime_rooms.dart';
import '../viewmodel/ludo_view_model.dart';
import 'ludo_board_view.dart';

class LudoBoardScreen extends StatefulWidget {
  const LudoBoardScreen({
    super.key,
    required this.roomCode,
    required this.expectedPlayers,
  });

  final String roomCode;
  final int expectedPlayers;

  @override
  State<LudoBoardScreen> createState() => _LudoBoardScreenState();
}

class _LudoBoardScreenState extends State<LudoBoardScreen> {
  late final LudoViewModel _vm;
  late final AuthService _auth;
  late final RealtimeRooms _rooms;
  String? _playerId;
  String? _myColor;
  String? _hostId;
  String _status = "waiting";
  Map<String, int> _players = {};
  int _maxPlayers = 4;

  @override
  void initState() {
    super.initState();
    _vm = LudoViewModel();
    _auth = AuthService(FirebaseAuth.instance);
    _rooms = RealtimeRooms(FirebaseDatabase.instance);
    _initAuthAndListen();
  }

  @override
  void dispose() {
    final id = _playerId;
    if (id != null) {
      _rooms.leaveRoom(code: widget.roomCode, playerId: id);
    }
    _vm.dispose();
    super.dispose();
  }

  Future<void> _initAuthAndListen() async {
    final id = await _auth.ensureSignedIn();
    setState(() => _playerId = id);
    await _rooms.startPresence(code: widget.roomCode, playerId: id);
    _listenRoom(widget.roomCode);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LudoBoardView(
          vm: _vm,
          canAct: _canAct(),
          onAfterLocalMove: () async {
            final id = _playerId;
            if (id == null) return;
            await _rooms.submitMove(code: widget.roomCode, playerId: id, vm: _vm);
          },
          onAfterLocalRoll: () async {
            final id = _playerId;
            if (id == null) return;
            await _rooms.submitMove(code: widget.roomCode, playerId: id, vm: _vm);
          },
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: _infoButton(),
        ),
      ],
    );
  }

  void _listenRoom(String code) {
    _rooms.watchRoom(code).listen((room) {
      _myColor = _seatToColor(room.players[_playerId]);
      _hostId = room.host;
      _status = room.status;
      _players = room.players;
      _maxPlayers = room.maxPlayers;
      final activePlayers = _activePlayersFromSeats(_players);
      final data = _rooms.toRoomStateData(room);
      _vm.applyRemoteState(data);
      _vm.setActivePlayers(activePlayers);
      if (_isHost() && _status == "active") {
        final fixed = _vm.normalizeTurn(activePlayers);
        if (fixed && _playerId != null) {
          _rooms.submitMove(
            code: widget.roomCode,
            playerId: _playerId!,
            vm: _vm,
          );
        }
      }
      setState(() {});
    });
  }

  bool _canAct() {
    if (_playerId == null) return false;
    if (_myColor == null) return false;
    if (_status != "active") return false;
    return _vm.currentPlayer == _myColor;
  }

  String? _seatToColor(int? seat) {
    if (seat == null) return null;
    const colors = ["red", "green", "yellow", "blue"];
    if (seat < 0 || seat >= colors.length) return null;
    return colors[seat];
  }

  List<String> _activePlayersFromSeats(Map<String, int> seats) {
    final entries = seats.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final colors = <String>[];
    for (final entry in entries) {
      final color = _seatToColor(entry.value);
      if (color != null) colors.add(color);
    }
    return colors;
  }

  bool _isHost() => _playerId != null && _playerId == _hostId;

  Widget _infoButton() {
    return GestureDetector(
      onTap: _showRoomInfo,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black),
        ),
        child: const Icon(Icons.info_outline, size: 22),
      ),
    );
  }

  void _showRoomInfo() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Room: ${widget.roomCode}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text("Status: $_status"),
                Text("Max players: $_maxPlayers"),
                const SizedBox(height: 12),
                if (_isHost())
                  ElevatedButton(
                    onPressed: _status == "active"
                        ? null
                        : () {
                            Navigator.pop(context);
                            _rooms.startGame(code: widget.roomCode);
                          },
                    child: const Text("Start Game"),
                  ),
                if (_isHost())
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _kickDialog();
                    },
                    child: const Text("Kick Player"),
                  ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _leaveRoom();
                  },
                  child: const Text("Leave Room"),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Players",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ..._players.keys.map(
                  (id) => Text(
                    "${_seatToColor(_players[id]) ?? '-'}: $id${id == _hostId ? ' (host)' : ''}",
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _kickDialog() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Kick Player"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Player ID"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Kick"),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (id == null || id.isEmpty) return;
    await _rooms.kickPlayer(code: widget.roomCode, playerId: id);
  }

  Future<void> _leaveRoom() async {
    final id = _playerId;
    if (id == null) return;
    await _rooms.leaveRoom(code: widget.roomCode, playerId: id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
