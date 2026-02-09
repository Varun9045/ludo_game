import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class Dice extends StatelessWidget {
  final int value;
  final Color dotColor;
  final Color borderColor;
  final double size;

  const Dice({
    super.key,
    required this.value,
    this.dotColor = Colors.black,
    this.borderColor = Colors.black,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(color: borderColor, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade200,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 6,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          ..._buildPips(value, dotColor, size),
        ],
      ),
    );
  }

  List<Widget> _buildPips(int value, Color color, double size) {
    final pips = <Offset>[];
    switch (value) {
      case 1:
        pips.add(const Offset(1, 1));
        break;
      case 2:
        pips.addAll([const Offset(0, 0), const Offset(2, 2)]);
        break;
      case 3:
        pips.addAll([const Offset(0, 0), const Offset(1, 1), const Offset(2, 2)]);
        break;
      case 4:
        pips.addAll([
          const Offset(0, 0),
          const Offset(0, 2),
          const Offset(2, 0),
          const Offset(2, 2),
        ]);
        break;
      case 5:
        pips.addAll([
          const Offset(0, 0),
          const Offset(0, 2),
          const Offset(1, 1),
          const Offset(2, 0),
          const Offset(2, 2),
        ]);
        break;
      case 6:
      default:
        pips.addAll([
          const Offset(0, 0),
          const Offset(0, 1),
          const Offset(0, 2),
          const Offset(2, 0),
          const Offset(2, 1),
          const Offset(2, 2),
        ]);
        break;
    }

    final double grid = size / 3;
    final double dot = size * 0.12;
    return pips
        .map(
          (p) => Positioned(
            left: p.dx * grid + (grid - dot) / 2,
            top: p.dy * grid + (grid - dot) / 2,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        )
        .toList();
  }
}

class AnimatedDice extends StatefulWidget {
  const AnimatedDice({
    super.key,
    required this.value,
    required this.onTap,
    this.dotColor = Colors.black,
    this.borderColor = Colors.black,
    this.size = 56,
    this.shuffleDuration = const Duration(milliseconds: 450),
    this.shuffleInterval = const Duration(milliseconds: 60),
  });

  final int value;
  final VoidCallback? onTap;
  final Color dotColor;
  final Color borderColor;
  final double size;
  final Duration shuffleDuration;
  final Duration shuffleInterval;

  @override
  State<AnimatedDice> createState() => _AnimatedDiceState();
}

class _AnimatedDiceState extends State<AnimatedDice> with SingleTickerProviderStateMixin {
  final Random _rng = Random();
  int _displayValue = 1;
  Timer? _timer;
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedDice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _startShuffle();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  void _startShuffle() {
    _timer?.cancel();
    _spinController.repeat();
    final endAt = DateTime.now().add(widget.shuffleDuration);
    _timer = Timer.periodic(widget.shuffleInterval, (t) {
      if (DateTime.now().isAfter(endAt)) {
        t.cancel();
        _spinController.stop();
        _spinController.reset();
        setState(() => _displayValue = widget.value);
        return;
      }
      setState(() => _displayValue = _rng.nextInt(6) + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _spinController,
        builder: (context, child) {
          final t = _spinController.value;
          final tilt = (t * 2 * 3.1415926535);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateZ(tilt)
              ..rotateX(0.15),
            child: child,
          );
        },
        child: Dice(
          value: _displayValue,
          dotColor: widget.dotColor,
          borderColor: widget.borderColor,
          size: widget.size,
        ),
      ),
    );
  }
}
