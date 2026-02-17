import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_snake_game/src/features/game/logic/game_provider.dart';
import 'package:flutter_snake_game/src/core/theme/app_theme.dart';

class SnakePainter extends CustomPainter {
  final List<GamePoint> snake;
  final List<GamePoint> obstacles;
  final List<GamePoint> playableCells;
  final GamePoint food;
  final Direction direction;
  final GameLevel currentLevel;
  final int gridWidth;
  final int gridHeight;
  final int snakeTickSpeedMs;
  final bool foodVisible;
  final bool isGameOver;
  final double animationValue;
  final int animationCycleMs;

  SnakePainter({
    required this.snake,
    required this.obstacles,
    required this.playableCells,
    required this.food,
    required this.direction,
    required this.currentLevel,
    required this.gridWidth,
    required this.gridHeight,
    required this.snakeTickSpeedMs,
    this.foodVisible = true,
    this.isGameOver = false,
    this.animationValue = 0.0,
    this.animationCycleMs = 60000,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bool isLightsOut = currentLevel == GameLevel.lightsOut;
    final double cellWidth = size.width / gridWidth;
    final double cellHeight = size.height / gridHeight;
    final Color boardBackground = isLightsOut
        ? AppTheme.lightsOutBoardBackground
        : AppTheme.creamBackground;
    final Color gridColor = isLightsOut
        ? AppTheme.lightsOutGridLine
        : AppTheme.gridLine;
    final Color borderColor = isLightsOut
        ? AppTheme.lightsOutBorder
        : AppTheme.containerBorder;
    final Color snakeColor = isLightsOut
        ? AppTheme.lightsOutSnake
        : AppTheme.snakeskin;
    final Color eyeColor = boardBackground;
    final Color obstacleColor = isLightsOut
        ? AppTheme.lightsOutGridLine.withValues(alpha: 0.75)
        : AppTheme.gridLine;

    canvas.drawRect(Offset.zero & size, Paint()..color = boardBackground);

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final Set<GamePoint> playableSet = playableCells.toSet();
    final List<_GridSegment> borderSegments = _buildClockwiseBorderPath(
      playableSet,
    );

    if (!isLightsOut) {
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
    }

    if (!isLightsOut) {
      for (final _GridSegment segment in borderSegments) {
        canvas.drawLine(
          _gridVertexToOffset(segment.start, cellWidth, cellHeight),
          _gridVertexToOffset(segment.end, cellWidth, cellHeight),
          borderPaint,
        );
      }
    }

    if (isLightsOut && borderSegments.isNotEmpty) {
      _drawLightsOutBorderRunner(canvas, borderSegments, cellWidth, cellHeight);
    }

    final Paint obstaclePaint = Paint()
      ..color = obstacleColor
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

    final bool shouldDrawFood = !isLightsOut || foodVisible;
    if (shouldDrawFood) {
      final double fadeWave =
          0.5 + (0.5 * sin((animationValue * 2 * pi * 2) - (pi / 2)));
      final double foodAlpha = isLightsOut
          ? (0.45 + (fadeWave * 0.55)).clamp(0.0, 1.0)
          : 1.0;
      final Paint foodPaint = Paint()
        ..color = AppTheme.foodOrange.withValues(alpha: foodAlpha)
        ..style = PaintingStyle.fill;
      Rect foodRect = Rect.fromLTWH(
        (food.x * cellWidth) + padding,
        (food.y * cellHeight) + padding,
        cellWidth - (padding * 2),
        cellHeight - (padding * 2),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(foodRect, const Radius.circular(4)),
        foodPaint,
      );
    }

    for (int i = 0; i < snake.length; i++) {
      GamePoint point = snake[i];

      double finalOpacity;
      if (isGameOver) {
        // Death effect: animated wave pulse across the body
        double travel = (animationValue * (snake.length + 5));
        double dist = (travel - i).abs();
        double pulse = (1.0 - (dist / 3.0)).clamp(0.0, 1.0);
        finalOpacity = 0.3 + (0.7 * pulse);
      } else {
        // Alive: head is fully opaque, body fades toward the tail
        final double t = snake.length > 1 ? i / (snake.length - 1) : 0.0;
        finalOpacity = 1.0 - (t * 0.6);
      }

      final Paint currentSegmentPaint = Paint()
        ..color = snakeColor.withValues(alpha: finalOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      Rect rect = Rect.fromLTWH(
        (point.x * cellWidth) + padding,
        (point.y * cellHeight) + padding,
        cellWidth - (padding * 2),
        cellHeight - (padding * 2),
      );

      if (i == 0) {
        double radius = (cellWidth - (padding * 2)) / 2;

        BorderRadius borderRadius;
        switch (direction) {
          case Direction.up:
            borderRadius = BorderRadius.vertical(
              top: Radius.circular(radius),
              bottom: const Radius.circular(4),
            );
            break;
          case Direction.down:
            borderRadius = BorderRadius.vertical(
              bottom: Radius.circular(radius),
              top: const Radius.circular(4),
            );
            break;
          case Direction.left:
            borderRadius = BorderRadius.horizontal(
              left: Radius.circular(radius),
              right: const Radius.circular(4),
            );
            break;
          case Direction.right:
            borderRadius = BorderRadius.horizontal(
              right: Radius.circular(radius),
              left: const Radius.circular(4),
            );
            break;
        }

        canvas.drawRRect(borderRadius.toRRect(rect), currentSegmentPaint);
        final double eyeSize = min(rect.width, rect.height) * 0.16;
        final double eyeGap = eyeSize * 1.75;
        final double frontInset = eyeSize * 1.5;
        Offset eyeA;
        Offset eyeB;
        switch (direction) {
          case Direction.up:
            eyeA = Offset(rect.center.dx - (eyeGap / 2), rect.top + frontInset);
            eyeB = Offset(rect.center.dx + (eyeGap / 2), rect.top + frontInset);
            break;
          case Direction.down:
            eyeA = Offset(
              rect.center.dx - (eyeGap / 2),
              rect.bottom - frontInset,
            );
            eyeB = Offset(
              rect.center.dx + (eyeGap / 2),
              rect.bottom - frontInset,
            );
            break;
          case Direction.left:
            eyeA = Offset(
              rect.left + frontInset,
              rect.center.dy - (eyeGap / 2),
            );
            eyeB = Offset(
              rect.left + frontInset,
              rect.center.dy + (eyeGap / 2),
            );
            break;
          case Direction.right:
            eyeA = Offset(
              rect.right - frontInset,
              rect.center.dy - (eyeGap / 2),
            );
            eyeB = Offset(
              rect.right - frontInset,
              rect.center.dy + (eyeGap / 2),
            );
            break;
        }
        final Paint eyeCutPaint = Paint()..color = eyeColor;
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
        GamePoint prev = snake[i - 1];
        int dx = prev.x - point.x;
        int dy = prev.y - point.y;

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
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          currentSegmentPaint,
        );
      }
    }
  }

  List<_GridSegment> _buildClockwiseBorderPath(Set<GamePoint> playableSet) {
    final List<_GridSegment> segments = <_GridSegment>[];
    for (final GamePoint p in playableSet) {
      final int x = p.x;
      final int y = p.y;

      if (!playableSet.contains(GamePoint(x, y - 1))) {
        segments.add(_GridSegment(_IntPoint(x, y), _IntPoint(x + 1, y)));
      }
      if (!playableSet.contains(GamePoint(x + 1, y))) {
        segments.add(
          _GridSegment(_IntPoint(x + 1, y), _IntPoint(x + 1, y + 1)),
        );
      }
      if (!playableSet.contains(GamePoint(x, y + 1))) {
        segments.add(
          _GridSegment(_IntPoint(x + 1, y + 1), _IntPoint(x, y + 1)),
        );
      }
      if (!playableSet.contains(GamePoint(x - 1, y))) {
        segments.add(_GridSegment(_IntPoint(x, y + 1), _IntPoint(x, y)));
      }
    }
    if (segments.isEmpty) {
      return segments;
    }
    final Map<_IntPoint, List<int>> byStart = <_IntPoint, List<int>>{};
    for (int i = 0; i < segments.length; i++) {
      byStart.putIfAbsent(segments[i].start, () => <int>[]).add(i);
    }

    final Set<int> remaining = <int>{
      for (int i = 0; i < segments.length; i++) i,
    };
    List<int> bestLoop = <int>[];

    while (remaining.isNotEmpty) {
      final int seed = remaining.first;
      final _IntPoint loopStart = segments[seed].start;
      final Set<int> localVisited = <int>{};
      final List<int> loop = <int>[];
      int currentIndex = seed;
      bool closed = false;

      for (int guard = 0; guard < segments.length + 5; guard++) {
        if (localVisited.contains(currentIndex)) {
          break;
        }
        localVisited.add(currentIndex);
        loop.add(currentIndex);
        remaining.remove(currentIndex);

        final _GridSegment current = segments[currentIndex];
        if (current.end == loopStart) {
          closed = true;
          break;
        }

        final List<int> candidates = (byStart[current.end] ?? <int>[])
            .where((idx) => !localVisited.contains(idx))
            .toList();
        if (candidates.isEmpty) {
          break;
        }
        currentIndex = _pickNextClockwiseIndex(segments, current, candidates);
      }

      if (closed && loop.length > bestLoop.length) {
        bestLoop = loop;
      }
    }

    if (bestLoop.isEmpty) {
      return segments;
    }
    return bestLoop.map((idx) => segments[idx]).toList();
  }

  void _drawLightsOutBorderRunner(
    Canvas canvas,
    List<_GridSegment> borderSegments,
    double cellWidth,
    double cellHeight,
  ) {
    if (borderSegments.isEmpty) {
      return;
    }
    final Path borderPath = _buildPathFromSegments(
      borderSegments,
      cellWidth,
      cellHeight,
    );
    final ui.PathMetric? metric = borderPath.computeMetrics().isEmpty
        ? null
        : borderPath.computeMetrics().first;
    if (metric == null || metric.length <= 0) {
      return;
    }
    final double perimeter = metric.length;
    final double elapsedSeconds =
        (animationValue % 1.0) * (animationCycleMs / 1000.0);
    const double cellsPerSecond = 13.0;
    final double pixelsPerSecond = cellsPerSecond * min(cellWidth, cellHeight);
    final double headDistance = (elapsedSeconds * pixelsPerSecond) % perimeter;
    final double tailLength = max(
      perimeter * 0.22,
      min(cellWidth, cellHeight) * 9.0,
    );
    _drawGradientTail(
      canvas,
      metric,
      headDistance,
      tailLength,
      strokeWidth: 2.35,
      segments: 40,
    );

    final Offset headCenter =
        metric.getTangentForOffset(headDistance)?.position ??
        _gridVertexToOffset(borderSegments.first.start, cellWidth, cellHeight);
    final Paint headPaint = Paint()
      ..color = AppTheme.lightsOutBorderRunner
      ..style = PaintingStyle.fill;
    canvas.drawCircle(headCenter, min(cellWidth, cellHeight) * 0.20, headPaint);
  }

  Path _buildPathFromSegments(
    List<_GridSegment> borderSegments,
    double cellWidth,
    double cellHeight,
  ) {
    final Path path = Path();
    if (borderSegments.isEmpty) {
      return path;
    }
    final Offset start = _gridVertexToOffset(
      borderSegments.first.start,
      cellWidth,
      cellHeight,
    );
    path.moveTo(start.dx, start.dy);
    for (final _GridSegment segment in borderSegments) {
      final Offset end = _gridVertexToOffset(
        segment.end,
        cellWidth,
        cellHeight,
      );
      path.lineTo(end.dx, end.dy);
    }
    path.close();
    return path;
  }

  void _drawWrappedPathRange(
    Canvas canvas,
    ui.PathMetric metric,
    double rawStart,
    double rawEnd,
    Paint paint,
  ) {
    final double len = metric.length;
    double start = rawStart % len;
    double end = rawEnd % len;
    if (start < 0) start += len;
    if (end < 0) end += len;

    if (start <= end) {
      canvas.drawPath(metric.extractPath(start, end), paint);
      return;
    }
    canvas.drawPath(metric.extractPath(start, len), paint);
    canvas.drawPath(metric.extractPath(0, end), paint);
  }

  void _drawGradientTail(
    Canvas canvas,
    ui.PathMetric metric,
    double headDistance,
    double tailLength, {
    required double strokeWidth,
    required int segments,
  }) {
    final int safeSegments = max(8, segments);
    for (int i = 0; i < safeSegments; i++) {
      final double t0 = i / safeSegments;
      final double t1 = (i + 1) / safeSegments;
      final double d0 = headDistance - tailLength + (tailLength * t0);
      final double d1 = headDistance - tailLength + (tailLength * t1);
      final double fade = pow(t1, 1.9).toDouble();
      final Paint paint = Paint()
        ..color = AppTheme.lightsOutBorderRunner.withValues(
          alpha: (0.03 + (fade * 0.75)).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      _drawWrappedPathRange(canvas, metric, d0, d1, paint);
    }
  }

  int _pickNextClockwiseIndex(
    List<_GridSegment> segments,
    _GridSegment current,
    List<int> candidates,
  ) {
    final _EdgeDir currentDir = _dirOf(current);
    final _EdgeDir reverseDir = _reverseDir(currentDir);
    final List<_EdgeDir> priority = _clockwisePriority(currentDir);

    int? best;
    int bestRank = 1 << 30;
    for (final int idx in candidates) {
      final _EdgeDir dir = _dirOf(segments[idx]);
      int rank = priority.indexOf(dir);
      if (rank < 0) {
        rank = 1 << 20;
      }
      if (dir == reverseDir) {
        rank += 1000;
      }
      if (rank < bestRank) {
        bestRank = rank;
        best = idx;
      }
    }
    return best ?? candidates.first;
  }

  _EdgeDir _dirOf(_GridSegment segment) {
    final int dx = segment.end.x - segment.start.x;
    final int dy = segment.end.y - segment.start.y;
    if (dx > 0) return _EdgeDir.right;
    if (dx < 0) return _EdgeDir.left;
    if (dy > 0) return _EdgeDir.down;
    return _EdgeDir.up;
  }

  _EdgeDir _reverseDir(_EdgeDir dir) {
    switch (dir) {
      case _EdgeDir.up:
        return _EdgeDir.down;
      case _EdgeDir.right:
        return _EdgeDir.left;
      case _EdgeDir.down:
        return _EdgeDir.up;
      case _EdgeDir.left:
        return _EdgeDir.right;
    }
  }

  List<_EdgeDir> _clockwisePriority(_EdgeDir dir) {
    switch (dir) {
      case _EdgeDir.up:
        return const [
          _EdgeDir.right,
          _EdgeDir.up,
          _EdgeDir.left,
          _EdgeDir.down,
        ];
      case _EdgeDir.right:
        return const [
          _EdgeDir.down,
          _EdgeDir.right,
          _EdgeDir.up,
          _EdgeDir.left,
        ];
      case _EdgeDir.down:
        return const [
          _EdgeDir.left,
          _EdgeDir.down,
          _EdgeDir.right,
          _EdgeDir.up,
        ];
      case _EdgeDir.left:
        return const [
          _EdgeDir.up,
          _EdgeDir.left,
          _EdgeDir.down,
          _EdgeDir.right,
        ];
    }
  }

  Offset _gridVertexToOffset(
    _IntPoint point,
    double cellWidth,
    double cellHeight,
  ) {
    return Offset(point.x * cellWidth, point.y * cellHeight);
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) {
    return oldDelegate.snake != snake ||
        oldDelegate.obstacles != obstacles ||
        oldDelegate.playableCells != playableCells ||
        oldDelegate.food != food ||
        oldDelegate.direction != direction ||
        oldDelegate.currentLevel != currentLevel ||
        oldDelegate.foodVisible != foodVisible ||
        oldDelegate.animationValue != animationValue;
  }
}

class _GridSegment {
  final _IntPoint start;
  final _IntPoint end;
  const _GridSegment(this.start, this.end);
}

enum _EdgeDir { up, right, down, left }

class _IntPoint {
  final int x;
  final int y;
  const _IntPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _IntPoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}
