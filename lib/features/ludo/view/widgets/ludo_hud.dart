import 'package:flutter/material.dart';

import 'dice.dart';

class LudoHud extends StatelessWidget {
  const LudoHud({
    super.key,
    required this.canRoll,
    required this.diceValue,
    required this.currentPlayer,
    required this.playerColor,
    required this.isActivePlayer,
    required this.onRoll,
  });

  final bool canRoll;
  final int diceValue;
  final String currentPlayer;
  final Color Function(String player) playerColor;
  final bool Function(String player) isActivePlayer;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: Colors.black),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _playerBadge("red"),
          _playerBadge("green"),
          _playerBadge("yellow"),
          _playerBadge("blue"),
          GestureDetector(
            onTap: canRoll ? onRoll : null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) {
                return ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(anim),
                  child: child,
                );
              },
              child: Dice(
                key: ValueKey<int>(diceValue),
                value: diceValue,
                color: playerColor(currentPlayer),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerBadge(String player) {
    bool active = isActivePlayer(player);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? playerColor(player) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black),
      ),
      child: Text(
        player.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: active ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
