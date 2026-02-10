import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameStatus { initial, playing, paused, gameOver }
enum Direction { up, down, left, right }

class GamePoint {
  final int x;
  final int y;
  GamePoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GamePoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
  
  @override
  String toString() => '($x, $y)';
}

class GameProvider extends ChangeNotifier {
  // Configuration
  static const int gridWidth = 20;
  static const int gridHeight = 30; // Adjusted for aspect ratio in screenshot
  static const int baseSpeedMs = 150; // Even faster

  // State
  List<GamePoint> _snake = [];
  GamePoint _food = GamePoint(0, 0);
  Direction _direction = Direction.up;
  Direction? _nextDirection;
  GameStatus _status = GameStatus.initial;
  int _score = 0;
  int _highScore = 0;
  Timer? _gameTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Getters
  List<GamePoint> get snake => _snake;
  GamePoint get food => _food;
  GameStatus get status => _status;
  int get score => _score;
  int get highScore => _highScore;
  int get width => gridWidth;
  int get height => gridHeight;

  GameProvider() {
    _loadHighScore();
    _generateFood(); // Initial random food
  }

  void _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('high_score') ?? 0;
    notifyListeners();
  }

  void _saveHighScore() async {
    if (_score > _highScore) {
      _highScore = _score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('high_score', _highScore);
      notifyListeners();
    }
  }

  void startGame() {
    _score = 0;
    // Snake's standard start position
    _snake = [
      GamePoint(10, 20),
      GamePoint(10, 21),
      GamePoint(10, 22),
    ];
    _direction = Direction.up;
    _nextDirection = null;
    _status = GameStatus.playing;
    
    // Only regenerate food if it collides with the new snake
    // Otherwise keep it where the user sees it (consistency)
    bool foodCollides = false;
    for (var p in _snake) {
      if (p == _food) {
        foodCollides = true;
        break;
      }
    }
    if (foodCollides) {
      _generateFood();
    }
    
    _startTimer();
    HapticFeedback.heavyImpact(); // Stronger start
    _playSound('start.mp3'); // Optional if you have it
    notifyListeners();
  }

  void pauseGame() {
    if (_status == GameStatus.playing) {
      _status = GameStatus.paused;
      _gameTimer?.cancel();
      HapticFeedback.mediumImpact();
      _playSound('pause.mp3');
      notifyListeners();
    } else if (_status == GameStatus.paused) {
      _status = GameStatus.playing;
      _startTimer();
      HapticFeedback.mediumImpact();
      _playSound('pause.mp3');
      notifyListeners();
    }
  }

  void endGame() {
    _status = GameStatus.initial; // Go back to start screen effectively, or reset
    _gameTimer?.cancel();
    _status = GameStatus.initial; // Go back to start screen effectively, or reset
    _gameTimer?.cancel();
    _snake = []; // clear snake
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void _gameOver() {
    _status = GameStatus.gameOver;
    _gameTimer?.cancel();
    _saveHighScore();
    HapticFeedback.heavyImpact();
    _playSound('game_over.mp3');
    notifyListeners();
  }

  Future<void> _playSound(String fileName) async {
    // Expects files in assets/sounds/
    try {
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      // Ignore if file not found (user hasn't added yet)
      debugPrint("Audio error: $e");
    }
  }

  void _startTimer() {
    _gameTimer?.cancel();
    // Speed increases slightly as score goes up, cap at 50ms
    int speed = max(50, baseSpeedMs - (_score * 2));
    _gameTimer = Timer.periodic(Duration(milliseconds: speed), (timer) {
      _tick();
    });
  }

  void _generateFood() {
    final random = Random();
    GamePoint newFood;
    do {
      newFood = GamePoint(random.nextInt(gridWidth), random.nextInt(gridHeight));
    } while (_snake.contains(newFood));
    _food = newFood;
    notifyListeners();
  }

  void setDirection(Direction newDir) {
    if (_status != GameStatus.playing) return;

    // Prevent 180 turns
    if ((_direction == Direction.up && newDir == Direction.down) ||
        (_direction == Direction.down && newDir == Direction.up) ||
        (_direction == Direction.left && newDir == Direction.right) ||
        (_direction == Direction.right && newDir == Direction.left)) {
      return;
    }
    
    // Also prevent setting same direction twice in one tick to avoid rapid self-collision scenarios
    // Use buffer
    _nextDirection = newDir;
    HapticFeedback.selectionClick();
  }

  // Handle Pan Gesture Velocity to Direction
  void handleSwipe(DragEndDetails details) {
    if (_status != GameStatus.playing) return;

    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.dx == 0 && velocity.dy == 0) return;

    if (velocity.dx.abs() > velocity.dy.abs()) {
      // Horizontal
      if (velocity.dx > 0) {
        setDirection(Direction.right);
      } else {
        setDirection(Direction.left);
      }
    } else {
      // Vertical
      if (velocity.dy > 0) {
        setDirection(Direction.down);
      } else {
        setDirection(Direction.up);
      }
    }
  }

  void _tick() {
    if (_nextDirection != null) {
      _direction = _nextDirection!;
      _nextDirection = null;
    }

    final head = _snake.first;
    GamePoint newHead;

    switch (_direction) {
      case Direction.up:
        newHead = GamePoint(head.x, head.y - 1);
        break;
      case Direction.down:
        newHead = GamePoint(head.x, head.y + 1);
        break;
      case Direction.left:
        newHead = GamePoint(head.x - 1, head.y);
        break;
      case Direction.right:
        newHead = GamePoint(head.x + 1, head.y);
        break;
    }

    // Wall Collision - WRAP AROUND
    if (newHead.x < 0) {
      newHead = GamePoint(gridWidth - 1, newHead.y);
    } else if (newHead.x >= gridWidth) {
      newHead = GamePoint(0, newHead.y);
    }
    
    // Optional: Vertical Wrap (if desired, otherwise keep walls or wrap)
    // User specifically asked for "if snake goes out from right he should enter from left"
    // Usually implies consistent behavior for all walls.
    if (newHead.y < 0) {
      newHead = GamePoint(newHead.x, gridHeight - 1);
    } else if (newHead.y >= gridHeight) {
      newHead = GamePoint(newHead.x, 0);
    }

    // Self Collision (ignore tail as it will move, unless we ate food)
    // Actually tail moves at end of this fn.
    // If we simply check snake.contains, we might collide with tail that is about to move away.
    // But logically, if newHead equals last tail segment, it's fine.
    // However, if we ate food, we grow, so tail doesn't move.
    
    bool eaten = newHead == _food;
    
    // Check collision with body (excluding tail if not eaten)
    // A simpler way: just check all body parts. If it hits tail, it's game over unless tail moves.
    // Easier interpretation: Standard snake rules.
    if (_snake.contains(newHead)) {
       // If we hit the tail, and we are NOT eating, the tail will move away, so it's safe.
       // But wait: snake = [Head, Body, Tail].
       // Move: NewHead, Head, Body. Tail removed.
       // So if NewHead == Tail, it is safe.
       if (newHead == _snake.last && !eaten) {
         // Safe
       } else {
         _gameOver();
         return;
       }
    }

    // Create NEW list for immutability so CustomPainter detects change
    List<GamePoint> newSnake = List.from(_snake);
    newSnake.insert(0, newHead);

    if (eaten) {
      _score++;
      // Update snake BEFORE generating food so food doesn't spawn on head
      _snake = newSnake; 
      _generateFood();
      _startTimer(); // Update speed
      HapticFeedback.heavyImpact(); // Strong eat feedback
      _playSound('eat.mp3');
    } else {
      newSnake.removeLast();
      _snake = newSnake;
    }
    
    notifyListeners();
  }
}
