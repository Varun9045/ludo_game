import 'dart:math';

import 'package:flutter/material.dart';

import '../model/board_geometry.dart';
import '../model/token.dart';

class LudoViewModel extends ChangeNotifier {
  final Random _rng = Random();

  int diceValue = 1;
  String currentPlayer = "red";
  bool canRoll = true;
  String? _lastMovedTokenKey;
  List<String> _activePlayers = const ["red", "green", "yellow", "blue"];
  List<Offset> _lastMoveTrail = const [];
  Color? _lastMoveTrailColor;

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
  List<Offset> get lastMoveTrail => _lastMoveTrail;
  Color? get lastMoveTrailColor => _lastMoveTrailColor;

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

    final prevStatus = token.status;
    final prevSteps = token.steps;
    final prevHomeStep = token.homeStep;

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
    _setMoveTrail(
      token,
      prevStatus,
      prevSteps,
      prevHomeStep,
    );
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
    _basePath = ludoBasePath;

    _startIndex = {
      "red": _basePath.indexOf(ludoStartCells["red"]!),
      "green": _basePath.indexOf(ludoStartCells["green"]!),
      "yellow": _basePath.indexOf(ludoStartCells["yellow"]!),
      "blue": _basePath.indexOf(ludoStartCells["blue"]!),
    };

    _homePaths = ludoHomePaths;

    _homeSlots = ludoHomeSlots;

    _playerPath = {
      "red": _buildPlayerPath("red"),
      "green": _buildPlayerPath("green"),
      "yellow": _buildPlayerPath("yellow"),
      "blue": _buildPlayerPath("blue"),
    };

    _safeCells = ludoSafeCells;
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

  void _setMoveTrail(
    TokenState token,
    TokenStatus prevStatus,
    int prevSteps,
    int prevHomeStep,
  ) {
    final trail = _computeTrail(
      token.player,
      prevStatus,
      prevSteps,
      prevHomeStep,
      token.status,
      token.steps,
      token.homeStep,
    );
    _lastMoveTrail = trail;
    _lastMoveTrailColor = playerColor(token.player);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 350), () {
      _lastMoveTrail = const [];
      _lastMoveTrailColor = null;
      notifyListeners();
    });
  }

  List<Offset> _computeTrail(
    String player,
    TokenStatus fromStatus,
    int fromSteps,
    int fromHomeStep,
    TokenStatus toStatus,
    int toSteps,
    int toHomeStep,
  ) {
    final trail = <Offset>[];
    final path = _playerPath[player]!;
    final home = _homePaths[player]!;

    if (fromStatus == TokenStatus.home && toStatus == TokenStatus.path) {
      trail.add(path[0]);
      return trail;
    }

    if (fromStatus == TokenStatus.path && toStatus == TokenStatus.path) {
      for (int i = fromSteps + 1; i <= toSteps; i++) {
        trail.add(path[i]);
      }
      return trail;
    }

    if (fromStatus == TokenStatus.path && toStatus == TokenStatus.homePath) {
      for (int i = fromSteps + 1; i < path.length; i++) {
        trail.add(path[i]);
      }
      for (int i = 0; i <= toHomeStep && i < home.length; i++) {
        trail.add(home[i]);
      }
      return trail;
    }

    if (fromStatus == TokenStatus.homePath && toStatus == TokenStatus.homePath) {
      for (int i = fromHomeStep + 1; i <= toHomeStep && i < home.length; i++) {
        trail.add(home[i]);
      }
      return trail;
    }

    if (toStatus == TokenStatus.finished) {
      if (fromStatus == TokenStatus.homePath) {
        for (int i = fromHomeStep + 1; i < home.length; i++) {
          trail.add(home[i]);
        }
      } else if (fromStatus == TokenStatus.path) {
        for (int i = fromSteps + 1; i < path.length; i++) {
          trail.add(path[i]);
        }
        for (int i = 0; i < home.length; i++) {
          trail.add(home[i]);
        }
      }
      return trail;
    }

    return trail;
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
