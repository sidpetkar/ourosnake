import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_snake_game/src/features/game/logic/game_provider.dart';
import 'package:flutter_snake_game/src/core/theme/app_theme.dart';

class SnakePainter extends CustomPainter {
  // ... (existing code)



  final List<GamePoint> snake;
  final List<GamePoint> obstacles;
  final List<GamePoint> playableCells;
  final GamePoint food;
  final Direction direction;
  final int gridWidth;
  final int gridHeight;

  final double animationValue;

  SnakePainter({
    required this.snake,
    required this.obstacles,
    required this.playableCells,
    required this.food,
    required this.direction,
    required this.gridWidth,
    required this.gridHeight,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / gridWidth;
    final double cellHeight = size.height / gridHeight;

    final Paint gridPaint = Paint()
      ..color = AppTheme.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final Paint borderPaint = Paint()
      ..color = AppTheme.containerBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;


    final Paint foodPaint = Paint()
      ..color = AppTheme.foodOrange
      ..style = PaintingStyle.fill;

    final Set<GamePoint> playableSet = playableCells.toSet();

    // 1. Draw Grid only on playable cells (enables irregular outer shapes)
    for (int x = 0; x < gridWidth; x++) {
      for (int y = 0; y < gridHeight; y++) {
        final GamePoint p = GamePoint(x, y);
        if (!playableSet.contains(p)) {
          continue;
        }
        final Rect cellRect = Rect.fromLTWH(
          x * cellWidth,
          y * cellHeight,
          cellWidth,
          cellHeight,
        );
        canvas.drawRect(cellRect, gridPaint);
      }
    }

    // 1.2 Draw thick border that follows playable shape edges
    for (int x = 0; x < gridWidth; x++) {
      for (int y = 0; y < gridHeight; y++) {
        final GamePoint p = GamePoint(x, y);
        if (!playableSet.contains(p)) {
          continue;
        }
        final double left = x * cellWidth;
        final double top = y * cellHeight;
        final double right = left + cellWidth;
        final double bottom = top + cellHeight;

        final bool hasTopNeighbor = playableSet.contains(GamePoint(x, y - 1));
        final bool hasBottomNeighbor = playableSet.contains(GamePoint(x, y + 1));
        final bool hasLeftNeighbor = playableSet.contains(GamePoint(x - 1, y));
        final bool hasRightNeighbor = playableSet.contains(GamePoint(x + 1, y));

        if (!hasTopNeighbor) {
          canvas.drawLine(Offset(left, top), Offset(right, top), borderPaint);
        }
        if (!hasBottomNeighbor) {
          canvas.drawLine(Offset(left, bottom), Offset(right, bottom), borderPaint);
        }
        if (!hasLeftNeighbor) {
          canvas.drawLine(Offset(left, top), Offset(left, bottom), borderPaint);
        }
        if (!hasRightNeighbor) {
          canvas.drawLine(Offset(right, top), Offset(right, bottom), borderPaint);
        }
      }
    }

    // 1.5 Draw Obstacles
    final Paint obstaclePaint = Paint()
      ..color = AppTheme.gridLine 
      ..style = PaintingStyle.fill;

    double padding = 2.0;

    for (var p in obstacles) {
      Rect rect = Rect.fromLTWH(
        p.x * cellWidth,
        p.y * cellHeight,
        cellWidth,
        cellHeight,
      );
      canvas.drawRect(rect, obstaclePaint);
    }

    // 2. Draw Food
    // double padding = 2.0; // Already defined above
    
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
      
      // Calculate opacity / Pulse Effect for ALL segments
      // We want the pulse to travel from head (index 0) to tail.
      // Animation value goes 0 -> 1.
      
      // Use the simpler travelling highlight logic
      double travel = (animationValue * (snake.length + 5)); // Travel distance
      double dist = (travel - i).abs();
      double pulse = (1.0 - (dist / 3.0)).clamp(0.0, 1.0); // bell curve around travel point
      
      double finalOpacity = 0.4 + (0.6 * pulse);
      
      final Paint currentSegmentPaint = Paint()
        ..color = AppTheme.snakeskin.withOpacity(finalOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
        
      Rect rect = Rect.fromLTWH(
        (point.x * cellWidth) + padding,
        (point.y * cellHeight) + padding,
        cellWidth - (padding * 2),
        cellHeight - (padding * 2),
      );

      if (i == 0) {
        // Head - Directional Rounded Corners
        double radius = (cellWidth - (padding * 2)) / 2;
        
        BorderRadius borderRadius;
        switch (direction) {
          case Direction.up:
            borderRadius = BorderRadius.vertical(top: Radius.circular(radius), bottom: Radius.circular(4)); 
            break;
          case Direction.down:
            borderRadius = BorderRadius.vertical(bottom: Radius.circular(radius), top: Radius.circular(4)); 
            break;
          case Direction.left:
            borderRadius = BorderRadius.horizontal(left: Radius.circular(radius), right: Radius.circular(4)); 
            break;
          case Direction.right:
            borderRadius = BorderRadius.horizontal(right: Radius.circular(radius), left: Radius.circular(4)); 
            break;
        }
        
        canvas.drawRRect(
          borderRadius.toRRect(rect), 
          currentSegmentPaint
        );
        final double eyeSize = min(rect.width, rect.height) * 0.16;
        final double eyeGap = eyeSize * 1.75;
        final double frontInset = eyeSize * 1.5; // little behind the tip
        Offset eyeA;
        Offset eyeB;
        switch (direction) {
          case Direction.up:
            eyeA = Offset(rect.center.dx - (eyeGap / 2), rect.top + frontInset);
            eyeB = Offset(rect.center.dx + (eyeGap / 2), rect.top + frontInset);
            break;
          case Direction.down:
            eyeA = Offset(rect.center.dx - (eyeGap / 2), rect.bottom - frontInset);
            eyeB = Offset(rect.center.dx + (eyeGap / 2), rect.bottom - frontInset);
            break;
          case Direction.left:
            eyeA = Offset(rect.left + frontInset, rect.center.dy - (eyeGap / 2));
            eyeB = Offset(rect.left + frontInset, rect.center.dy + (eyeGap / 2));
            break;
          case Direction.right:
            eyeA = Offset(rect.right - frontInset, rect.center.dy - (eyeGap / 2));
            eyeB = Offset(rect.right - frontInset, rect.center.dy + (eyeGap / 2));
            break;
        }
        final Paint eyeCutPaint = Paint()..color = AppTheme.creamBackground;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: eyeA, width: eyeSize, height: eyeSize),
            Radius.circular(eyeSize * 0.4),
          ),
          eyeCutPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: eyeB, width: eyeSize, height: eyeSize),
            Radius.circular(eyeSize * 0.4),
          ),
          eyeCutPaint,
        );

      } else if (i == snake.length - 1 && snake.length > 1) {
        // Tail - same shape as head, but opposite direction.
        GamePoint prev = snake[i - 1];
        int dx = prev.x - point.x;
        int dy = prev.y - point.y;
        
        // Handle wrap-around
        if (dx > 1) dx = -1;
        if (dx < -1) dx = 1;
        if (dy > 1) dy = -1;
        if (dy < -1) dy = 1;
        Direction tailDirection;
        if (dx == 1) {
          tailDirection = Direction.left;
        } else if (dx == -1) {
          tailDirection = Direction.right;
        } else if (dy == 1) {
          tailDirection = Direction.up;
        } else {
          tailDirection = Direction.down;
        }
        final double tailRadius = (cellWidth - (padding * 2)) / 2;
        final double tailBaseRadius = (cellWidth - (padding * 2)) * 0.32;
        BorderRadius tailBorderRadius;
        switch (tailDirection) {
          case Direction.up:
            tailBorderRadius = BorderRadius.vertical(
              top: Radius.circular(tailRadius),
              bottom: Radius.circular(tailBaseRadius),
            );
            break;
          case Direction.down:
            tailBorderRadius = BorderRadius.vertical(
              bottom: Radius.circular(tailRadius),
              top: Radius.circular(tailBaseRadius),
            );
            break;
          case Direction.left:
            tailBorderRadius = BorderRadius.horizontal(
              left: Radius.circular(tailRadius),
              right: Radius.circular(tailBaseRadius),
            );
            break;
          case Direction.right:
            tailBorderRadius = BorderRadius.horizontal(
              right: Radius.circular(tailRadius),
              left: Radius.circular(tailBaseRadius),
            );
            break;
        }
        canvas.drawRRect(tailBorderRadius.toRRect(rect), currentSegmentPaint);

      } else {
        // Body - Standard small radius
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), 
          currentSegmentPaint
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) {
    return oldDelegate.snake != snake || 
           oldDelegate.obstacles != obstacles ||
           oldDelegate.playableCells != playableCells ||
           oldDelegate.food != food || 
           oldDelegate.direction != direction ||
           oldDelegate.animationValue != animationValue;
  }
}
