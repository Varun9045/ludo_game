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

        if (_containsOffset(ludoBasePath, pos)) {
          color = Colors.grey.shade200;
        }

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

        return Container(
          decoration: BoxDecoration(
            color: color ?? Colors.white,
            border: Border.all(color: Colors.black.withValues(alpha: 0.15), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 1,
                offset: const Offset(0, 0.5),
              ),
            ],
          ),
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
