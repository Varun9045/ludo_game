import 'package:flutter/material.dart';

import '../../model/board_geometry.dart';

class BoardTiles extends StatelessWidget {
  const BoardTiles({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 15,
      ),
      itemBuilder: (context, index) {
        int row = index ~/ 15;
        int col = index % 15;
        Color? color;
        final pos = Offset(col.toDouble(), row.toDouble());

        if (_containsOffset(ludoHomePaths["red"]!, pos)) {
          color = Colors.red;
        } else if (_containsOffset(ludoHomePaths["green"]!, pos)) {
          color = Colors.green;
        } else if (_containsOffset(ludoHomePaths["yellow"]!, pos)) {
          color = Colors.yellow[700];
        } else if (_containsOffset(ludoHomePaths["blue"]!, pos)) {
          color = Colors.blue;
        } else if (pos == ludoStartCells["red"]) {
          color = Colors.red;
        } else if (pos == ludoStartCells["green"]) {
          color = Colors.green;
        } else if (pos == ludoStartCells["yellow"]) {
          color = Colors.yellow[700];
        } else if (pos == ludoStartCells["blue"]) {
          color = Colors.blue;
        }

        final isSafe = _containsOffset(ludoSafeCells.toList(), pos);
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color ?? Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            if (isSafe)
              Center(
                child: Icon(
                  Icons.star,
                  size: 12,
                  color: Colors.black,
                ),
              ),
          ],
        );
      },
      itemCount: 225,
    );
  }

  bool _containsOffset(List<Offset> list, Offset pos) {
    for (final o in list) {
      if (o == pos) return true;
    }
    return false;
  }

}
