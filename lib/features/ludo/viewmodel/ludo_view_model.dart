import 'dart:math';

import 'package:flutter/material.dart';

import '../model/token.dart';

class LudoViewModel extends ChangeNotifier {
  final Random _rng = Random();

  int diceValue = 1;
  String currentPlayer = "red";
  bool canRoll = true;
  String? _lastMovedTokenKey;
  List<String> _activePlayers = const ["red", "green", "yellow", "blue"];

  late final List<Offset> _basePath;
  late final Map<String, int> _startIndex;
  late final Map<String, List<Offset>> _homePaths;
  late final Map<String, List<Offset>> _homeSlots;
  late final Map<String, List<Offset>> _playerPath;
  late final Set<Offset> _safeCells;

  final Map<String, List<TokenState>> _tokens = {
    "red": List.generate(4, (i) => TokenState("red", i)),
    "green": List.generate(4, (i) => TokenState("green", i)),
    "yellow": List.generate(4, (i) => TokenState("yellow", i)),
    "blue": List.generate(4, (i) => TokenState("blue", i)),
  };

  LudoViewModel() {
    _initBoardData();
  }

  Map<String, List<TokenState>> get tokens => _tokens;
  String? get lastMovedTokenKey => _lastMovedTokenKey;
  List<String> get activePlayers => _activePlayers;

  Color playerColor(String player) {
    switch (player) {
      case "red":
        return Colors.red;
      case "green":
        return Colors.green;
      case "yellow":
        return Colors.yellow.shade700;
      case "blue":
        return Colors.blue;
      default:
        return Colors.black;
    }
  }

  void rollDice() {
    if (!canRoll) return;
    diceValue = _rng.nextInt(6) + 1;
    canRoll = false;

    if (!_hasAnyValidMove(currentPlayer, diceValue)) {
      _switchTurn();
      canRoll = true;
    }
    notifyListeners();
  }

  void moveToken(TokenState token) {
    if (canRoll) return;
    if (!_canMoveToken(token, diceValue)) return;

    bool captured = false;

    if (token.status == TokenStatus.home) {
      token.status = TokenStatus.path;
      token.steps = 0;
    } else if (token.status == TokenStatus.path) {
      final next = token.steps + diceValue;
      if (next < 52) {
        token.steps = next;
      } else {
        final homeStep = next - 52;
        if (homeStep >= 5) {
          token.status = TokenStatus.finished;
        } else {
          token.status = TokenStatus.homePath;
          token.homeStep = homeStep;
        }
      }
    } else if (token.status == TokenStatus.homePath) {
      final next = token.homeStep + diceValue;
      if (next == 5) {
        token.status = TokenStatus.finished;
      } else {
        token.homeStep = next;
      }
    }

    if (token.status == TokenStatus.path) {
      captured = _resolveCapture(token);
    }

    if (diceValue != 6) {
      _switchTurn();
    } else if (captured) {
      // Keep turn after capture on 6.
    }
    _pulseToken(token);
    canRoll = true;
    notifyListeners();
  }

  Offset tokenPosition(TokenState token) {
    if (token.status == TokenStatus.home) {
      return _homeSlots[token.player]![token.id];
    }
    if (token.status == TokenStatus.path) {
      return _playerPath[token.player]![token.steps];
    }
    if (token.status == TokenStatus.homePath) {
      return _homePaths[token.player]![token.homeStep];
    }
    const finishes = [
      Offset(7.1, 7.1),
      Offset(7.5, 7.1),
      Offset(7.1, 7.5),
      Offset(7.5, 7.5),
    ];
    return finishes[token.id % finishes.length];
  }

  bool isActivePlayer(String player) => currentPlayer == player;

  void _switchTurn() {
    final list = _activePlayers;
    if (list.isEmpty) return;
    final idx = list.indexOf(currentPlayer);
    if (idx == -1) {
      currentPlayer = list.first;
      return;
    }
    currentPlayer = list[(idx + 1) % list.length];
  }

  bool _hasAnyValidMove(String player, int dice) {
    for (final token in _tokens[player]!) {
      if (_canMoveToken(token, dice)) {
        return true;
      }
    }
    return false;
  }

  bool _canMoveToken(TokenState token, int dice) {
    if (token.status == TokenStatus.finished) return false;

    if (token.status == TokenStatus.home) {
      return dice == 6;
    }

    if (token.status == TokenStatus.path) {
      final next = token.steps + dice;
      if (next < 52) return true;
      if (next == 52) return true;
      final homeStep = next - 52;
      return homeStep <= 5;
    }

    if (token.status == TokenStatus.homePath) {
      final next = token.homeStep + dice;
      return next <= 5;
    }

    return false;
  }

  void _initBoardData() {
    _basePath = [
      const Offset(6, 1),
      const Offset(6, 2),
      const Offset(6, 3),
      const Offset(6, 4),
      const Offset(6, 5),
      const Offset(5, 6),
      const Offset(4, 6),
      const Offset(3, 6),
      const Offset(2, 6),
      const Offset(1, 6),
      const Offset(0, 6),
      const Offset(0, 7),
      const Offset(0, 8),
      const Offset(1, 8),
      const Offset(2, 8),
      const Offset(3, 8),
      const Offset(4, 8),
      const Offset(5, 8),
      const Offset(6, 9),
      const Offset(6, 10),
      const Offset(6, 11),
      const Offset(6, 12),
      const Offset(6, 13),
      const Offset(6, 14),
      const Offset(7, 14),
      const Offset(8, 14),
      const Offset(8, 13),
      const Offset(8, 12),
      const Offset(8, 11),
      const Offset(8, 10),
      const Offset(8, 9),
      const Offset(9, 8),
      const Offset(10, 8),
      const Offset(11, 8),
      const Offset(12, 8),
      const Offset(13, 8),
      const Offset(14, 8),
      const Offset(14, 7),
      const Offset(14, 6),
      const Offset(13, 6),
      const Offset(12, 6),
      const Offset(11, 6),
      const Offset(10, 6),
      const Offset(9, 6),
      const Offset(8, 5),
      const Offset(8, 4),
      const Offset(8, 3),
      const Offset(8, 2),
      const Offset(8, 1),
      const Offset(8, 0),
      const Offset(7, 0),
      const Offset(6, 0),
    ];

    _startIndex = {
      "red": _basePath.indexOf(const Offset(6, 1)),
      "green": _basePath.indexOf(const Offset(1, 8)),
      "yellow": _basePath.indexOf(const Offset(8, 13)),
      "blue": _basePath.indexOf(const Offset(13, 6)),
    };

    _homePaths = {
      "red": [
        const Offset(7, 1),
        const Offset(7, 2),
        const Offset(7, 3),
        const Offset(7, 4),
        const Offset(7, 5),
        const Offset(7, 6),
      ],
      "green": [
        const Offset(1, 7),
        const Offset(2, 7),
        const Offset(3, 7),
        const Offset(4, 7),
        const Offset(5, 7),
        const Offset(6, 7),
      ],
      "yellow": [
        const Offset(7, 13),
        const Offset(7, 12),
        const Offset(7, 11),
        const Offset(7, 10),
        const Offset(7, 9),
        const Offset(7, 8),
      ],
      "blue": [
        const Offset(13, 7),
        const Offset(12, 7),
        const Offset(11, 7),
        const Offset(10, 7),
        const Offset(9, 7),
        const Offset(8, 7),
      ],
    };

    _homeSlots = {
      "red": [
        const Offset(1, 1),
        const Offset(1, 4),
        const Offset(3, 1),
        const Offset(3, 4),
      ],
      "green": [
        const Offset(1, 10),
        const Offset(1, 13),
        const Offset(3, 10),
        const Offset(3, 13),
      ],
      "blue": [
        const Offset(10, 1),
        const Offset(10, 4),
        const Offset(12, 1),
        const Offset(12, 4),
      ],
      "yellow": [
        const Offset(10, 10),
        const Offset(10, 13),
        const Offset(12, 10),
        const Offset(12, 13),
      ],
    };

    _playerPath = {
      "red": _buildPlayerPath("red"),
      "green": _buildPlayerPath("green"),
      "yellow": _buildPlayerPath("yellow"),
      "blue": _buildPlayerPath("blue"),
    };

    _safeCells = {
      const Offset(2, 6),
      const Offset(6, 12),
      const Offset(12, 8),
      const Offset(8, 2),
      _playerPath["red"]![0],
      _playerPath["green"]![0],
      _playerPath["yellow"]![0],
      _playerPath["blue"]![0],
    };
  }

  List<Offset> _buildPlayerPath(String player) {
    final start = _startIndex[player]!;
    return List.generate(
      _basePath.length,
      (i) => _basePath[(start + i) % _basePath.length],
    );
  }

  bool _isSafeCell(Offset pos) => _safeCells.contains(pos);

  bool _resolveCapture(TokenState moved) {
    final pos = _playerPath[moved.player]![moved.steps];
    if (_isSafeCell(pos)) return false;

    bool captured = false;
    for (final entry in _tokens.entries) {
      if (entry.key == moved.player) continue;
      for (final token in entry.value) {
        if (token.status != TokenStatus.path) continue;
        final tpos = _playerPath[token.player]![token.steps];
        if (tpos == pos) {
          token.status = TokenStatus.home;
          token.steps = 0;
          token.homeStep = 0;
          captured = true;
        }
      }
    }
    return captured;
  }

  void applyRemoteState(RoomStateData data) {
    currentPlayer = data.currentPlayer;
    diceValue = data.diceValue;
    canRoll = data.canRoll;
    data.tokens.forEach((player, list) {
      final local = _tokens[player];
      if (local == null) return;
      for (final map in list) {
        final id = map.id;
        if (id < 0 || id >= local.length) continue;
        final token = local[id];
        token.status = map.status;
        token.steps = map.steps;
        token.homeStep = map.homeStep;
      }
    });
    notifyListeners();
  }

  void setActivePlayers(List<String> players) {
    if (players.isEmpty) return;
    if (_sameList(_activePlayers, players)) return;
    _activePlayers = List<String>.from(players);
    if (!_activePlayers.contains(currentPlayer)) {
      currentPlayer = _activePlayers.first;
      canRoll = true;
    }
    notifyListeners();
  }

  bool normalizeTurn(List<String> players) {
    if (players.isEmpty) return false;
    setActivePlayers(players);
    if (!_activePlayers.contains(currentPlayer)) {
      currentPlayer = _activePlayers.first;
      canRoll = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool isLastMoved(TokenState token) {
    return _lastMovedTokenKey == _tokenKey(token);
  }

  void _pulseToken(TokenState token) {
    final key = _tokenKey(token);
    _lastMovedTokenKey = key;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (_lastMovedTokenKey == key) {
        _lastMovedTokenKey = null;
        notifyListeners();
      }
    });
  }

  String _tokenKey(TokenState token) => "${token.player}-${token.id}";

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class RoomStateData {
  RoomStateData({
    required this.currentPlayer,
    required this.diceValue,
    required this.canRoll,
    required this.tokens,
  });

  final String currentPlayer;
  final int diceValue;
  final bool canRoll;
  final Map<String, List<RoomTokenData>> tokens;
}

class RoomTokenData {
  RoomTokenData({
    required this.id,
    required this.status,
    required this.steps,
    required this.homeStep,
  });

  final int id;
  final TokenStatus status;
  final int steps;
  final int homeStep;
}
