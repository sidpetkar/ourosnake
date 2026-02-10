import 'package:flutter/material.dart';
import 'package:flutter_snake_game/src/features/game/logic/game_provider.dart';
import 'package:flutter_snake_game/src/core/theme/app_theme.dart';

class SnakePainter extends CustomPainter {
  final List<GamePoint> snake;
  final GamePoint food;
  final int gridWidth;
  final int gridHeight;

  SnakePainter({
    required this.snake,
    required this.food,
    required this.gridWidth,
    required this.gridHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / gridWidth;
    final double cellHeight = size.height / gridHeight;

    final Paint gridPaint = Paint()
      ..color = AppTheme.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Paint snakePaint = Paint()
      ..color = AppTheme.snakeskin
      ..style = PaintingStyle.fill;

    final Paint foodPaint = Paint()
      ..color = AppTheme.foodOrange
      ..style = PaintingStyle.fill;

    // 1. Draw Grid
    for (int i = 0; i <= gridWidth; i++) {
      double x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (int i = 0; i <= gridHeight; i++) {
      double y = i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Draw Food
    // User requested "Circle or High Rounded Square"
    // Screenshot shows Square with slight radius.
    double padding = 2.0;
    
    Rect foodRect = Rect.fromLTWH(
      (food.x * cellWidth) + padding,
      (food.y * cellHeight) + padding,
      cellWidth - (padding * 2),
      cellHeight - (padding * 2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(foodRect, const Radius.circular(4)), 
      foodPaint
    );

    // 3. Draw Snake
    for (int i = 0; i < snake.length; i++) {
      GamePoint point = snake[i];
      
      // Calculate opacity: Head (i=0) is 1.0
      // We want a very smooth fade towards the tail.
      double opacity = 1.0;
      if (snake.length > 2) {
         // Denominator > snake.length ensures we never reach 0.0 opacity
         opacity = 1.0 - (i / (snake.length * 1.2));
         opacity = opacity.clamp(0.15, 1.0);
      }

      final Paint currentSegmentPaint = Paint()
        ..color = AppTheme.snakeskin.withOpacity(opacity)
        ..style = PaintingStyle.fill;
        
      Rect rect = Rect.fromLTWH(
        (point.x * cellWidth) + padding,
        (point.y * cellHeight) + padding,
        cellWidth - (padding * 2),
        cellHeight - (padding * 2),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)), 
        currentSegmentPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) {
    return oldDelegate.snake != snake || oldDelegate.food != food;
  }
}
