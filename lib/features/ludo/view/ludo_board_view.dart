import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../viewmodel/ludo_view_model.dart';
import 'widgets/board_tiles.dart';

class LudoBoardView extends StatelessWidget {
  const LudoBoardView({
    super.key,
    required this.vm,
    required this.canAct,
    required this.onAfterLocalMove,
    required this.onAfterLocalRoll,
  });

  final LudoViewModel vm;
  final bool canAct;
  final VoidCallback onAfterLocalMove;
  final VoidCallback onAfterLocalRoll;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxBoard = math.min(
              constraints.maxWidth * 0.9,
              constraints.maxHeight * 0.9,
            );
            final boardSize = maxBoard.clamp(220.0, 520.0);
            final cellSize = boardSize / 15;

            return Center(
              child: SizedBox(
                width: boardSize,
                height: boardSize,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        const _SoftBackground(),
                        const BoardTiles(),
                        ..._buildMoveTrail(cellSize),
                        Positioned(
                          left: 0,
                          top: 0,
                          width: boardSize * 6 / 15,
                          height: boardSize * 6 / 15,
                          child: _homeBase(Colors.red),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          width: boardSize * 6 / 15,
                          height: boardSize * 6 / 15,
                          child: _homeBase(Colors.green),
                        ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          width: boardSize * 6 / 15,
                          height: boardSize * 6 / 15,
                          child: _homeBase(Colors.blue),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          width: boardSize * 6 / 15,
                          height: boardSize * 6 / 15,
                          child: _homeBase(Colors.yellow[700]!),
                        ),

                        Center(
                          child: CustomPaint(
                            size: Size.square(cellSize * 3),
                            painter: CenterTrianglePainter(),
                          ),
                        ),

                        ..._buildAllTokens(cellSize),

                        _buildStar(cellSize, 2, 6),
                        _buildStar(cellSize, 6, 12),
                        _buildStar(cellSize, 12, 8),
                        _buildStar(cellSize, 8, 2),

                        _buildArrow(cellSize, 0, 7, Icons.arrow_downward),
                        _buildArrow(cellSize, 7, 14, Icons.arrow_back),
                        _buildArrow(cellSize, 14, 7, Icons.arrow_upward),
                        _buildArrow(cellSize, 7, 0, Icons.arrow_forward),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _homeBase(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                children: List.generate(4, (i) {
                  return Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.5),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMoveTrail(double cellSize) {
    final trail = vm.lastMoveTrail;
    final color = vm.lastMoveTrailColor;
    if (trail.isEmpty || color == null) return const [];
    return trail
        .map(
          (pos) => Positioned(
            top: pos.dy * cellSize + cellSize * 0.08,
            left: pos.dx * cellSize + cellSize * 0.08,
            child: Container(
              width: cellSize * 0.84,
              height: cellSize * 0.84,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildAllTokens(double cellSize) {
    final widgets = <Widget>[];
    for (final entry in vm.tokens.entries) {
      for (final token in entry.value) {
        final pos = vm.tokenPosition(token);
        widgets.add(
          AnimatedPositioned(
            top: pos.dy * cellSize + cellSize * 0.1,
            left: pos.dx * cellSize + cellSize * 0.1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: GestureDetector(
              onTap: vm.isActivePlayer(token.player)
                  ? () {
                      if (!canAct) return;
                      vm.moveToken(token);
                      onAfterLocalMove();
                    }
                  : null,
              child: AnimatedScale(
                scale: vm.isLastMoved(token) ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Container(
                  width: cellSize * 0.9,
                  height: cellSize * 0.9,
                  decoration: BoxDecoration(
                    color: vm.playerColor(token.player),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildStar(double cellSize, int row, int col) {
    return Positioned(
      top: row * cellSize,
      left: col * cellSize,
      child: SizedBox(
        width: cellSize,
        height: cellSize,
        child: const Icon(Icons.star, color: Colors.black54, size: 16),
      ),
    );
  }

  Widget _buildArrow(double cellSize, int row, int col, IconData icon) {
    return Positioned(
      top: row * cellSize,
      left: col * cellSize,
      child: SizedBox(
        width: cellSize,
        height: cellSize,
        child: Icon(icon, color: Colors.black87, size: 18),
      ),
    );
  }

}

class CenterTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final center = Offset(size.width / 2, size.height / 2);

    paint.color = Colors.green;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0)
        ..close(),
      paint,
    );

    paint.color = Colors.yellow[700]!;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..close(),
      paint,
    );

    paint.color = Colors.blue;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      paint,
    );

    paint.color = Colors.red;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(0, size.height)
        ..lineTo(0, 0)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _SoftBackground extends StatelessWidget {
  const _SoftBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SoftPatternPainter(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.2, -0.2),
            radius: 1.2,
            colors: [
              Color(0xFFEAF3FF),
              Color(0xFFD6E6FF),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35);
    const spacing = 18.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x + (y / spacing).floor() % 2 * 6, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
