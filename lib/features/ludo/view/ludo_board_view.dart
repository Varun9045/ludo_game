import 'package:flutter/material.dart';

import '../viewmodel/ludo_view_model.dart';
import 'widgets/board_tiles.dart';
import 'widgets/ludo_hud.dart';

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
        double boardSize = MediaQuery.of(context).size.width * 0.9;
        double cellSize = boardSize / 15;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: boardSize,
                height: boardSize,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Stack(
                    children: [
                      const BoardTiles(),
                      Positioned(
                        left: 0,
                        top: 0,
                        width: MediaQuery.of(context).size.width * 6 / 16.8,
                        height: MediaQuery.of(context).size.width * 6 / 16.8,
                        child: _homeBase(Colors.red),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        width: MediaQuery.of(context).size.width * 6 / 16.8,
                        height: MediaQuery.of(context).size.width * 6 / 16.8,
                        child: _homeBase(Colors.green),
                      ),
                      Positioned(
                        left: 0,
                        bottom: 0,
                        width: MediaQuery.of(context).size.width * 6 / 16.8,
                        height: MediaQuery.of(context).size.width * 6 / 16.8,
                        child: _homeBase(Colors.blue),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        width: MediaQuery.of(context).size.width * 6 / 16.8,
                        height: MediaQuery.of(context).size.width * 6 / 16.8,
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
              const SizedBox(height: 12),
              SizedBox(
                width: boardSize,
                child: LudoHud(
                  canRoll: vm.canRoll && canAct,
                  diceValue: vm.diceValue,
                  currentPlayer: vm.currentPlayer,
                  playerColor: vm.playerColor,
                  isActivePlayer: vm.isActivePlayer,
                  onRoll: () {
                    vm.rollDice();
                    onAfterLocalRoll();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _homeBase(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(8),
          color: Colors.white,
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            children: List.generate(4, (i) {
              return Center(
                child: CircleAvatar(radius: 18, backgroundColor: color),
              );
            }),
          ),
        ),
      ),
    );
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
                scale: vm.isLastMoved(token) ? 1.18 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.location_on,
                  color: vm.playerColor(token.player),
                  size: cellSize * 1.2,
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
        child: const Icon(Icons.star, color: Colors.black54, size: 18),
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
