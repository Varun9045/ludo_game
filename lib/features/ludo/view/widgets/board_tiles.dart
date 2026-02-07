import 'package:flutter/material.dart';

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

        if (row == 6 && col == 1) color = Colors.red;
        if (row == 7 && col > 0 && col < 6) color = Colors.red;
        if (row > 0 && row <= 5 && col == 7) color = Colors.green;
        if (row == 1 && col == 8) color = Colors.green;
        if (row == 7 && col >= 9 && col < 14) color = Colors.yellow[700];
        if (row == 8 && col == 13) color = Colors.yellow[700];
        if (row > 8 && row < 14 && col == 7) color = Colors.blue;
        if (row == 13 && col == 6) color = Colors.blue;

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 0.38),
            color: color ?? Colors.white,
          ),
        );
      },
      itemCount: 225,
    );
  }
}
