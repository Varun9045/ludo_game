import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../services/auth_service.dart';
import '../../../services/realtime_rooms.dart';
import '../viewmodel/ludo_view_model.dart';
import 'ludo_board_view.dart';
import 'widgets/dice.dart';

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
  Offset _infoOffset = const Offset(0, 0);
  String? _playerId;
  String? _myColor;
  String? _hostId;
  String _status = "waiting";
  Map<String, int> _players = {};
  int _maxPlayers = 4;
  StreamSubscription<List<RoomMessage>>? _messageSub;
  final Map<String, String> _lastMessages = {};
  final Map<String, Timer> _messageTimers = {};
  List<RoomMessage> _recentMessages = const [];
  final TextEditingController _messageController = TextEditingController();
  String _messageReceiver = "all";

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
    _messageSub?.cancel();
    _messageController.dispose();
    for (final t in _messageTimers.values) {
      t.cancel();
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
    final size = MediaQuery.of(context).size;
    final safe = MediaQuery.of(context).padding;
    const buttonSize = 44.0;
    final maxX = size.width - buttonSize - 12;
    final minX = 12.0;
    final minY = safe.top + 12;
    final maxY = size.height - safe.bottom - buttonSize - 12;
    if (_infoOffset == const Offset(0, 0)) {
      _infoOffset = Offset(maxX, maxY - 60);
    }
    return Stack(
      children: [
        const _ScreenBackground(),
        SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: Center(
                  child: LudoBoardView(
                    vm: _vm,
                    canAct: _canAct(),
                    onAfterLocalMove: () async {
                      final id = _playerId;
                      if (id == null) return;
                      await _rooms.submitMove(
                        code: widget.roomCode,
                        playerId: id,
                        vm: _vm,
                      );
                    },
                    onAfterLocalRoll: () async {
                      final id = _playerId;
                      if (id == null) return;
                      await _rooms.submitMove(
                        code: widget.roomCode,
                        playerId: id,
                        vm: _vm,
                      );
                    },
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
        Positioned(
          left: _infoOffset.dx,
          top: _infoOffset.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final next = _infoOffset + details.delta;
                _infoOffset = Offset(
                  next.dx.clamp(minX, maxX),
                  next.dy.clamp(minY, maxY),
                );
              });
            },
            child: _infoButton(),
          ),
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
      _startMessageStreamIfNeeded(code);
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

  void _startMessageStreamIfNeeded(String code) {
    if (_messageSub != null) return;
    _messageSub = _rooms.watchMessages(code).listen((messages) {
      _recentMessages = messages;
      if (messages.isEmpty) {
        _lastMessages.clear();
        if (mounted) setState(() {});
        return;
      }
      final latest = messages.last;
      final receiver = latest.receiverColor;
      if (receiver.isNotEmpty && receiver != "all" && receiver != _myColor) {
        return;
      }
      _showMessage(latest.senderColor, latest.text);
    });
  }

  void _showMessage(String color, String text) {
    if (color.isEmpty) return;
    _messageTimers[color]?.cancel();
    _lastMessages[color] = text;
    _messageTimers[color] = Timer(const Duration(seconds: 30), () {
      _lastMessages.remove(color);
      if (mounted) setState(() {});
    });
    if (mounted) setState(() {});
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

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _playerPill(
            color: Colors.red,
            active: _myColor == "red",
            message: _lastMessages["red"],
          ),
          _playerPill(
            color: Colors.blue,
            active: _myColor == "blue",
            message: _lastMessages["blue"],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D4CA3),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _playerPill(
            color: Colors.green,
            active: _myColor == "green",
            compact: true,
            message: _lastMessages["green"],
          ),
          AnimatedDice(
            value: _vm.diceValue,
            dotColor: _vm.playerColor(_vm.currentPlayer),
            borderColor: _vm.playerColor(_vm.currentPlayer),
            onTap: _canAct()
                ? () async {
                    _vm.rollDice();
                    final id = _playerId;
                    if (id == null) return;
                    await _rooms.submitMove(
                      code: widget.roomCode,
                      playerId: id,
                      vm: _vm,
                    );
                  }
                : null,
          ),
          _playerPill(
            color: Colors.yellow[700]!,
            active: _myColor == "yellow",
            compact: true,
            message: _lastMessages["yellow"],
          ),
        ],
      ),
    );
  }

  Widget _iconCircle(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 18),
    );
  }

  Widget _playerPill({
    required Color color,
    required bool active,
    bool compact = false,
    String? message,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            width: compact ? 14 : 18,
            height: compact ? 14 : 18,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ),
        ),
        if (message != null && message.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            constraints: const BoxConstraints(maxWidth: 120),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
            ),
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ),
      ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Room: ${widget.roomCode}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        _iconCircle(Icons.chat_bubble_outline),
                        const SizedBox(width: 8),
                        _iconCircle(Icons.volume_up_outlined),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildChatPanel(),
                const SizedBox(height: 12),
                Text("Status: $_status"),
                Text("Max players: $_maxPlayers"),
                const SizedBox(height: 12),
                if (_isHost())
                  ElevatedButton(
                    onPressed: (_status == "active" || _players.length < 2)
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

  Widget _buildChatPanel() {
    final receivers = ["all", ..._players.keys.map((id) => _seatToColor(_players[id]) ?? "").where((e) => e.isNotEmpty)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recentMessages.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _recentMessages.length > 5 ? 5 : _recentMessages.length,
              itemBuilder: (context, index) {
                final msg = _recentMessages[_recentMessages.length - 1 - index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    "${msg.senderColor}: ${msg.text}",
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: "Type a message",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _messageReceiver,
              items: receivers
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _messageReceiver = v);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _sendMessage() async {
    final id = _playerId;
    if (id == null) return;
    final color = _myColor ?? _seatToColor(_players[id]) ?? "";
    if (color.isEmpty) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await _rooms.sendMessage(
      code: widget.roomCode,
      senderId: id,
      senderColor: color,
      receiverColor: _messageReceiver,
      text: text,
    );
    _messageController.clear();
  }

}

class _ScreenBackground extends StatelessWidget {
  const _ScreenBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.2, -0.4),
          radius: 1.2,
          colors: [
            Color(0xFF2B7ACD),
            Color(0xFF0B3A78),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _DiamondPatternPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DiamondPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 24.0;
    for (double y = -size.height; y < size.height * 2; y += step) {
      for (double x = -size.width; x < size.width * 2; x += step) {
        final path = Path()
          ..moveTo(x + step / 2, y)
          ..lineTo(x + step, y + step / 2)
          ..lineTo(x + step / 2, y + step)
          ..lineTo(x, y + step / 2)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
