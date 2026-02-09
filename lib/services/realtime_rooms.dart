import 'package:firebase_database/firebase_database.dart';

import '../features/ludo/viewmodel/ludo_view_model.dart';
import '../features/ludo/model/token.dart';

class RealtimeRooms {
  RealtimeRooms(this.db);

  final FirebaseDatabase db;

  DatabaseReference roomRef(String code) => db.ref("rooms/$code");
  DatabaseReference _messagesRef(String code) => roomRef(code).child("messages");
  DatabaseReference _connectedRef() => db.ref(".info/connected");

  Future<void> createRoom({
    required String code,
    required String hostPlayerId,
    required int maxPlayers,
  }) async {
    final ref = roomRef(code);
    await ref.set({
      "createdAt": ServerValue.timestamp,
      "status": "waiting",
      "host": hostPlayerId,
      "maxPlayers": maxPlayers,
      "players": {
        hostPlayerId: {
          "seat": _seatOrder(maxPlayers).first,
          "connected": true,
          "lastSeen": ServerValue.timestamp,
        }
      },
      "state": _initialState(),
    });
  }

  Future<void> joinRoom({
    required String code,
    required String playerId,
  }) async {
    final ref = roomRef(code);
    final roomSnap = await ref.get();
    final room = roomSnap.value as Map? ?? {};
    final players = (room["players"] as Map?) ?? {};
    final maxPlayers = (room["maxPlayers"] ?? 4) as int;
    final allowedSeats = _seatOrder(maxPlayers);
    if (players.length >= allowedSeats.length) {
      throw StateError("Room full");
    }
    final taken = players.values
        .map((e) => (e as Map?)?["seat"] as int? ?? -1)
        .where((e) => e >= 0)
        .toSet();
    int? seat;
    for (final s in allowedSeats) {
      if (!taken.contains(s)) {
        seat = s;
        break;
      }
    }
    if (seat == null) {
      throw StateError("Room full");
    }
    await ref.child("players/$playerId").set({
      "seat": seat,
      "connected": true,
      "lastSeen": ServerValue.timestamp,
    });
    final count = players.length + 1;
    if (count >= allowedSeats.length) {
      await ref.update({"status": "active"});
    }
  }

  Future<void> startPresence({
    required String code,
    required String playerId,
  }) async {
    final playersRef = roomRef(code).child("players/$playerId");
    _connectedRef().onValue.listen((event) {
      final connected = event.snapshot.value == true;
      if (connected) {
        playersRef.update({
          "connected": true,
          "lastSeen": ServerValue.timestamp,
        });
        playersRef.onDisconnect().update({
          "connected": false,
          "lastSeen": ServerValue.timestamp,
        });
      }
    });
  }

  Future<void> leaveRoom({
    required String code,
    required String playerId,
  }) async {
    final ref = roomRef(code);
    await ref.child("players/$playerId").remove();
    await _maybeTransferHostOrCleanup(code);
  }

  Stream<RoomState> watchRoom(String code) {
    return roomRef(code).onValue.map((event) {
      final data = event.snapshot.value as Map? ?? {};
      return RoomState.fromMap(code, data);
    });
  }

  Stream<List<RoomMessage>> watchMessages(String code) {
    final query = _messagesRef(code).orderByChild("ts").limitToLast(50);
    return query.onValue.map((event) {
      final data = event.snapshot.value as Map? ?? {};
      final messages = <RoomMessage>[];
      data.forEach((k, v) {
        final map = v as Map? ?? {};
        messages.add(
          RoomMessage(
            id: k.toString(),
            senderId: (map["senderId"] ?? "").toString(),
            senderColor: (map["senderColor"] ?? "").toString(),
            receiverColor: (map["receiverColor"] ?? "").toString(),
            text: (map["text"] ?? "").toString(),
            ts: (map["ts"] ?? 0) as int,
          ),
        );
      });
      messages.sort((a, b) => a.ts.compareTo(b.ts));
      return messages;
    });
  }

  Stream<List<RoomSummary>> watchWaitingRooms() {
    final query = db.ref("rooms").orderByChild("status").equalTo("waiting");
    return query.onValue.map((event) {
      final data = event.snapshot.value as Map? ?? {};
      final rooms = <RoomSummary>[];
      data.forEach((k, v) {
        final map = v as Map? ?? {};
        final players = (map["players"] as Map?) ?? {};
        final maxPlayers = (map["maxPlayers"] ?? 4) as int;
        if (players.isEmpty) return;
        int connected = 0;
        players.forEach((_, pv) {
          final m = pv as Map? ?? {};
          if (m["connected"] == true) connected++;
        });
        if (connected == 0) {
          roomRef(k.toString()).remove();
          return;
        }
        rooms.add(RoomSummary(
          code: k.toString(),
          players: players.length,
          connected: connected,
          maxPlayers: maxPlayers,
        ));
      });
      rooms.sort((a, b) => a.code.compareTo(b.code));
      return rooms;
    });
  }

  RoomStateData toRoomStateData(RoomState state) {
    final parsed = <String, List<RoomTokenData>>{};
    state.tokens.forEach((player, list) {
      parsed[player] = list
          .map(
            (e) => RoomTokenData(
              id: (e["id"] ?? 0) as int,
              status: _statusFromName((e["status"] ?? "home").toString()),
              steps: (e["steps"] ?? 0) as int,
              homeStep: (e["homeStep"] ?? 0) as int,
            ),
          )
          .toList();
    });
    return RoomStateData(
      currentPlayer: state.currentPlayer,
      diceValue: state.diceValue,
      canRoll: state.canRoll,
      tokens: parsed,
    );
  }

  Future<void> submitMove({
    required String code,
    required String playerId,
    required LudoViewModel vm,
  }) async {
    final ref = roomRef(code);
    await ref.child("state").set({
      "currentPlayer": vm.currentPlayer,
      "diceValue": vm.diceValue,
      "canRoll": vm.canRoll,
      "tokens": _serializeTokens(vm),
      "updatedBy": playerId,
      "updatedAt": ServerValue.timestamp,
    });
  }

  Future<void> sendMessage({
    required String code,
    required String senderId,
    required String senderColor,
    String receiverColor = "all",
    required String text,
  }) async {
    final ref = _messagesRef(code).push();
    await ref.set({
      "senderId": senderId,
      "senderColor": senderColor,
      "receiverColor": receiverColor,
      "text": text,
      "ts": ServerValue.timestamp,
    });
  }

  List<int> _seatOrder(int maxPlayers) {
    if (maxPlayers == 2) return [0, 2];
    if (maxPlayers == 3) return [0, 1, 2];
    return [0, 1, 2, 3];
  }

  Future<void> startGame({
    required String code,
  }) async {
    await roomRef(code).update({"status": "active"});
  }

  Future<void> kickPlayer({
    required String code,
    required String playerId,
  }) async {
    await roomRef(code).child("players/$playerId").remove();
    await _maybeTransferHostOrCleanup(code);
  }

  Future<void> _maybeTransferHostOrCleanup(String code) async {
    final ref = roomRef(code);
    final snapshot = await ref.get();
    final data = snapshot.value as Map? ?? {};
    final players = (data["players"] as Map?) ?? {};
    if (players.isEmpty) {
      await ref.remove();
      return;
    }
    final host = data["host"]?.toString();
    if (host == null || !players.containsKey(host)) {
      final newHost = players.keys.first.toString();
      await ref.update({"host": newHost});
    }
  }

  Map<String, dynamic> _initialState() {
    return {
      "currentPlayer": "red",
      "diceValue": 1,
      "canRoll": true,
      "tokens": {
        "red": List.generate(4, (i) => {"id": i, "status": "home", "steps": 0, "homeStep": 0}),
        "green": List.generate(4, (i) => {"id": i, "status": "home", "steps": 0, "homeStep": 0}),
        "yellow": List.generate(4, (i) => {"id": i, "status": "home", "steps": 0, "homeStep": 0}),
        "blue": List.generate(4, (i) => {"id": i, "status": "home", "steps": 0, "homeStep": 0}),
      },
    };
  }

  Map<String, dynamic> _serializeTokens(LudoViewModel vm) {
    final result = <String, dynamic>{};
    vm.tokens.forEach((player, list) {
      result[player] = list
          .map((t) => {
                "id": t.id,
                "status": t.status.name,
                "steps": t.steps,
                "homeStep": t.homeStep,
              })
          .toList();
    });
    return result;
  }

  TokenStatus _statusFromName(String name) {
    switch (name) {
      case "path":
        return TokenStatus.path;
      case "homePath":
        return TokenStatus.homePath;
      case "finished":
        return TokenStatus.finished;
      case "home":
      default:
        return TokenStatus.home;
    }
  }
}

class RoomState {
  RoomState({
    required this.code,
    required this.status,
    required this.currentPlayer,
    required this.diceValue,
    required this.canRoll,
    required this.tokens,
    required this.players,
    required this.host,
    required this.playersConnected,
    required this.maxPlayers,
  });

  final String code;
  final String status;
  final String currentPlayer;
  final int diceValue;
  final bool canRoll;
  final Map<String, List<Map<String, dynamic>>> tokens;
  final Map<String, int> players;
  final String? host;
  final Map<String, bool> playersConnected;
  final int maxPlayers;

  factory RoomState.fromMap(String code, Map data) {
    final state = (data["state"] as Map?) ?? {};
    final players = (data["players"] as Map?) ?? {};
    final host = data["host"]?.toString();
    final maxPlayers = (data["maxPlayers"] ?? 4) as int;
    final tokens = (state["tokens"] as Map?) ?? {};
    final parsedTokens = <String, List<Map<String, dynamic>>>{};
    tokens.forEach((k, v) {
      parsedTokens[k.toString()] = (v as List? ?? [])
          .map((e) => (e as Map).map((kk, vv) => MapEntry(kk.toString(), vv)))
          .toList();
    });
    final parsedPlayers = <String, int>{};
    final parsedConnected = <String, bool>{};
    players.forEach((k, v) {
      final map = v as Map? ?? {};
      parsedPlayers[k.toString()] = (map["seat"] ?? 0) as int;
      parsedConnected[k.toString()] = (map["connected"] ?? false) as bool;
    });
    return RoomState(
      code: code,
      status: (data["status"] ?? "waiting").toString(),
      currentPlayer: (state["currentPlayer"] ?? "red").toString(),
      diceValue: (state["diceValue"] ?? 1) as int,
      canRoll: (state["canRoll"] ?? true) as bool,
      tokens: parsedTokens,
      players: parsedPlayers,
      host: host,
      playersConnected: parsedConnected,
      maxPlayers: maxPlayers,
    );
  }
}

class RoomSummary {
  RoomSummary({
    required this.code,
    required this.players,
    required this.connected,
    required this.maxPlayers,
  });

  final String code;
  final int players;
  final int connected;
  final int maxPlayers;
}

class RoomMessage {
  RoomMessage({
    required this.id,
    required this.senderId,
    required this.senderColor,
    required this.receiverColor,
    required this.text,
    required this.ts,
  });

  final String id;
  final String senderId;
  final String senderColor;
  final String receiverColor;
  final String text;
  final int ts;
}
