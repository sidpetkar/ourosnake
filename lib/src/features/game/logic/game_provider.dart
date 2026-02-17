import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

enum GameStatus { initial, playing, paused, gameOver }

enum GameLevel { beginner, intermediate, advanced, lightsOut }

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
  static const int gridWidth = 21; // Odd number for perfect symmetry
  static const int gridHeight = 31; // Odd number for perfect symmetry
  // Base speeds for levels
  static const int speedBeginner = 150;
  static const int speedIntermediate = 150;
  static const int speedAdvanced = 100;
  static const int speedLightsOut = 160; // Special mode
  static const double _minSwipeDelta = 7.0;

  // State
  List<GamePoint> _snake = [];
  List<GamePoint> _obstacles = [];
  List<GamePoint> _playableCells = [];
  Set<GamePoint> _playableCellSet = <GamePoint>{};
  GamePoint _food = GamePoint(0, 0);
  Direction _direction = Direction.up;
  Direction? _nextDirection;
  GameStatus _status = GameStatus.initial;
  int _score = 0;
  final Map<GameLevel, int> _highScores = {
    GameLevel.beginner: 0,
    GameLevel.intermediate: 0,
    GameLevel.advanced: 0,
    GameLevel.lightsOut: 0,
  };
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _wrapWallsEnabled = true;
  GameLevel _currentLevel = GameLevel.beginner;
  Timer? _gameTimer;
  Timer? _lightsOutFoodTimer;
  // Simple pool of players for SFX.
  final List<AudioPlayer> _sfxPlayers = [];
  int _currentSfxPlayerIndex = 0;
  static const int _sfxPoolSize = 5;
  final Random _random = Random();

  DateTime? _lastSwipeTime;
  bool _hasVibrator = false;
  int? _lastIntermediateShapeId;
  int? _lastLightsOutShapeId;
  int? _lastZenPatternId;
  int _currentTickSpeedMs = speedBeginner;
  bool _lightsOutFoodVisible = true;

  // Getters
  List<GamePoint> get snake => _snake;
  List<GamePoint> get obstacles => _obstacles;
  List<GamePoint> get playableCells => _playableCells;
  GamePoint get food => _food;
  GameStatus get status => _status;
  int get score => _score;
  int get highScore => _highScores[_currentLevel] ?? 0;
  int get width => gridWidth;
  int get height => gridHeight;
  int get currentTickSpeedMs => _currentTickSpeedMs;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get wrapWallsEnabled => _wrapWallsEnabled;
  bool get foodVisible =>
      _currentLevel == GameLevel.lightsOut ? _lightsOutFoodVisible : true;

  Direction get direction => _direction;
  GameLevel get currentLevel => _currentLevel;

  GameProvider() {
    _setPlayableCells(_buildFullPlayableCells());
    _loadPreferences();
    _initAudio();
    _generateFood();
    _checkVibrator();
  }

  Future<void> _initAudio() async {
    for (int i = 0; i < _sfxPoolSize; i++) {
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      _sfxPlayers.add(player);
    }
  }

  void _checkVibrator() async {
    try {
      if (kIsWeb) {
        _hasVibrator = false;
      } else {
        _hasVibrator = await Vibration.hasVibrator();
      }
    } catch (_) {
      _hasVibrator = false;
    }
  }

  String _levelPrefKey(GameLevel level) => 'high_score_${level.name}';

  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    for (final level in GameLevel.values) {
      _highScores[level] = prefs.getInt(_levelPrefKey(level)) ?? 0;
    }
    _soundEnabled = prefs.getBool('setting_sound_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('setting_vibration_enabled') ?? true;
    _wrapWallsEnabled = prefs.getBool('setting_wrap_walls_enabled') ?? true;
    notifyListeners();
  }

  void _saveHighScore() async {
    final int currentHigh = _highScores[_currentLevel] ?? 0;
    if (_score > currentHigh) {
      _highScores[_currentLevel] = _score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_levelPrefKey(_currentLevel), _score);
      notifyListeners();
    }
  }

  Future<void> setSoundEnabled(bool value) async {
    final bool wasEnabled = _soundEnabled;
    if (wasEnabled && !value) {
      // Play click before muting so OFF also gives feedback.
      _playSound('toggle.wav', force: true);
    }
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_sound_enabled', value);
    notifyListeners();
    if (value) {
      _playSound('toggle.wav');
    }
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_vibration_enabled', value);
    notifyListeners();
    _playSound('toggle.wav');
  }

  Future<void> setWrapWallsEnabled(bool value) async {
    _wrapWallsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_wrap_walls_enabled', value);
    notifyListeners();
    _playSound('toggle.wav');
  }

  void startGame() {
    _score = 0;
    _status = GameStatus.playing;

    _generateLevel(_currentLevel);
    final (spawnSnake, spawnDirection) = _buildInitialSpawn(_random);
    _snake = spawnSnake;
    _direction = spawnDirection;
    _nextDirection = null;

    final bool foodCollides =
        !_isPlayable(_food) ||
        _snake.contains(_food) ||
        _obstacles.contains(_food) ||
        !_isFoodReachableFromSnake(_food);

    if (foodCollides) {
      _generateFood();
    }
    _startLightsOutFoodCycleIfNeeded();

    _startTimer();
    _triggerVibration(duration: 100, amplitude: 255);
    _playSound('start.wav'); // Optional if you have it
    notifyListeners();
  }

  void pauseGame() {
    if (_status == GameStatus.playing) {
      _status = GameStatus.paused;
      _gameTimer?.cancel();
      _cancelLightsOutFoodTimer();
      _triggerVibration(duration: 50, amplitude: 128);
      _playSound('pause.wav');
      notifyListeners();
    } else if (_status == GameStatus.paused) {
      _status = GameStatus.playing;
      _startTimer();
      _startLightsOutFoodCycleIfNeeded();
      _triggerVibration(duration: 50, amplitude: 128);
      _playSound('pause.wav');
      notifyListeners();
    }
  }

  void endGame() {
    _status =
        GameStatus.initial; // Go back to start screen effectively, or reset
    _gameTimer?.cancel();
    _cancelLightsOutFoodTimer();

    _snake = []; // clear snake
    _triggerVibration(duration: 50, amplitude: 100);
    notifyListeners();
  }

  void _gameOver() {
    _status = GameStatus.gameOver;
    _gameTimer?.cancel();
    _cancelLightsOutFoodTimer();
    _saveHighScore();
    _triggerVibration(duration: 200, amplitude: 255);

    _playSound('game_over.wav');
    notifyListeners();
  }

  void _triggerVibration({int duration = 50, int amplitude = 128}) async {
    if (!_vibrationEnabled) {
      return;
    }
    if (kIsWeb) {
      return;
    }
    try {
      if (_hasVibrator) {
        Vibration.vibrate(duration: duration, amplitude: amplitude).catchError((
          e,
        ) {
          HapticFeedback.mediumImpact();
        });
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Silently fail on platforms that don't support vibration
    }
  }

  void _generateLevel(GameLevel level) {
    _obstacles = [];
    if (level == GameLevel.beginner) {
      _setPlayableCells(_buildFullPlayableCells());
      _generateBeginnerObstacles(Random());
      notifyListeners();
      return;
    }
    if (level == GameLevel.advanced) {
      _setPlayableCells(_buildFullPlayableCells());
      _generateZenMasterObstacles(Random());
      notifyListeners();
      return;
    }
    if (level == GameLevel.lightsOut) {
      final random = Random();
      _setPlayableCells(_buildLightsOutPlayableShape(random));
      notifyListeners();
      return;
    }
    if (level != GameLevel.intermediate) {
      _setPlayableCells(_buildFullPlayableCells());
      notifyListeners();
      return;
    }

    final random = Random();
    int shapePattern = random.nextInt(6);
    if (_lastIntermediateShapeId != null &&
        shapePattern == _lastIntermediateShapeId) {
      shapePattern = (shapePattern + 1 + random.nextInt(5)) % 6;
    }
    _lastIntermediateShapeId = shapePattern;
    _setPlayableCells(_buildIntermediatePlayableShape(shapePattern, random));
    _generateIntermediateObstacles(random);
    notifyListeners();
  }

  Future<void> _playSound(String fileName, {bool force = false}) async {
    if (!_soundEnabled && !force) {
      return;
    }

    if (_sfxPlayers.isEmpty) return;

    try {
      // Round-robin selection: always pick next player, stopping it if busy.
      // This ensures the latest sound plays immediately.
      final player = _sfxPlayers[_currentSfxPlayerIndex];
      _currentSfxPlayerIndex =
          (_currentSfxPlayerIndex + 1) % _sfxPlayers.length;

      await player.stop();
      await player.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint("Audio error: $e");
    }
  }

  void setLevel(GameLevel level) {
    if (_status == GameStatus.initial) {
      _currentLevel = level;
      if (!kIsWeb) {
        HapticFeedback.selectionClick();
      }
      notifyListeners();
    }
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _currentTickSpeedMs = _computeTickSpeed(_score);
    _gameTimer = Timer.periodic(Duration(milliseconds: _currentTickSpeedMs), (
      timer,
    ) {
      _tick();
    });
  }

  int _baseSpeedForLevel() {
    switch (_currentLevel) {
      case GameLevel.beginner:
        return speedBeginner;
      case GameLevel.intermediate:
        return speedIntermediate;
      case GameLevel.advanced:
        return speedAdvanced;
      case GameLevel.lightsOut:
        return speedLightsOut;
    }
  }

  int _computeTickSpeed(int score) {
    final int baseSpeed = _baseSpeedForLevel();
    // Quantize to avoid restarting timer every single point.
    final int quantizedScore = (score ~/ 3) * 3;
    return max(50, baseSpeed - (quantizedScore * 2));
  }

  void _generateFood({bool notify = true}) {
    final Set<GamePoint> blocked = _obstacles.toSet()..addAll(_snake);

    // One BFS from snake head to find all reachable cells. This avoids an expensive
    // "BFS per candidate cell" scan that can cause a visible pause after eating.
    final Set<GamePoint> reachable = <GamePoint>{};
    if (_snake.isNotEmpty) {
      final GamePoint start = _snake.first;
      final List<GamePoint> queue = <GamePoint>[start];
      reachable.add(start);
      int index = 0;
      while (index < queue.length) {
        final GamePoint current = queue[index++];
        for (final dir in Direction.values) {
          final GamePoint next = _step(current, dir);
          if (!_isPlayable(next) ||
              blocked.contains(next) ||
              reachable.contains(next)) {
            continue;
          }
          reachable.add(next);
          queue.add(next);
        }
      }
    }

    final List<GamePoint> candidates = _playableCells.where((p) {
      if (blocked.contains(p)) {
        return false;
      }
      return _snake.isEmpty ? true : reachable.contains(p);
    }).toList();

    if (candidates.isEmpty) {
      _gameOver();
      return;
    }
    _food = candidates[_random.nextInt(candidates.length)];
    if (notify) {
      notifyListeners();
    }
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

    // Ignore if no change in intended direction
    if (newDir == (_nextDirection ?? _direction)) {
      return;
    }

    // Debounce rapid swipes - keep responsive while preventing accidental doubles.
    final now = DateTime.now();
    if (_lastSwipeTime != null &&
        now.difference(_lastSwipeTime!).inMilliseconds < 50) {
      return;
    }

    // Also prevent setting same direction twice in one tick to avoid rapid self-collision scenarios
    // Use buffer
    _nextDirection = newDir;
    _lastSwipeTime = now;
    _triggerVibration(duration: 30, amplitude: 80);
    _playSound('swipe.wav');
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

  // Handle very small, continuous drag updates for fast touch response.
  void handleSwipeUpdate(DragUpdateDetails details) {
    if (_status != GameStatus.playing) return;

    final double dx = details.delta.dx;
    final double dy = details.delta.dy;
    if (dx.abs() < _minSwipeDelta && dy.abs() < _minSwipeDelta) {
      return;
    }

    if (dx.abs() > dy.abs()) {
      setDirection(dx > 0 ? Direction.right : Direction.left);
    } else {
      setDirection(dy > 0 ? Direction.down : Direction.up);
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

    final bool shouldWrapWalls =
        _wrapWallsEnabled && _currentLevel != GameLevel.advanced;
    if (shouldWrapWalls) {
      // Wall Collision - WRAP AROUND
      if (newHead.x < 0) {
        newHead = GamePoint(gridWidth - 1, newHead.y);
      } else if (newHead.x >= gridWidth) {
        newHead = GamePoint(0, newHead.y);
      }
      if (newHead.y < 0) {
        newHead = GamePoint(newHead.x, gridHeight - 1);
      } else if (newHead.y >= gridHeight) {
        newHead = GamePoint(newHead.x, 0);
      }
    } else {
      if (newHead.x < 0 ||
          newHead.x >= gridWidth ||
          newHead.y < 0 ||
          newHead.y >= gridHeight) {
        _gameOver();
        return;
      }
    }

    if (!_isPlayable(newHead)) {
      _gameOver();
      return;
    }

    // Self Collision (ignore tail as it will move, unless we ate food)
    // Actually tail moves at end of this fn.
    // If we simply check snake.contains, we might collide with tail that is about to move away.
    // But logically, if newHead equals last tail segment, it's fine.
    // However, if we ate food, we grow, so tail doesn't move.

    bool eaten = newHead == _food;

    // Check collision with body (excluding tail if not eaten)
    if (_snake.contains(newHead)) {
      if (newHead == _snake.last && !eaten) {
        // Safe
      } else {
        _gameOver();
        return;
      }
    }

    // Check Obstacle Collision
    if (_obstacles.contains(newHead)) {
      _gameOver();
      return;
    }

    // Create NEW list for immutability so CustomPainter detects change
    List<GamePoint> newSnake = List.from(_snake);
    newSnake.insert(0, newHead);

    if (eaten) {
      _score++;
      // Update snake BEFORE generating food so food doesn't spawn on head
      _snake = newSnake;

      _updateTimerSpeed();
      _generateFood(notify: false);
      if (_currentLevel == GameLevel.lightsOut) {
        _lightsOutFoodVisible = true;
        _startLightsOutFoodCycleIfNeeded(notify: false);
      }

      _triggerVibration(duration: 100, amplitude: 200);
      _playSound('eat.wav');
    } else {
      newSnake.removeLast();
      _snake = newSnake;
    }

    notifyListeners();
  }

  void _updateTimerSpeed() {
    final int newSpeed = _computeTickSpeed(_score);
    if (_gameTimer == null || newSpeed == _currentTickSpeedMs) {
      return;
    }
    _currentTickSpeedMs = newSpeed;
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(Duration(milliseconds: newSpeed), (timer) {
      _tick();
    });
  }

  List<GamePoint> _buildFullPlayableCells() {
    final List<GamePoint> cells = [];
    for (int x = 0; x < gridWidth; x++) {
      for (int y = 0; y < gridHeight; y++) {
        cells.add(GamePoint(x, y));
      }
    }
    return cells;
  }

  void _setPlayableCells(List<GamePoint> cells) {
    _playableCells = cells;
    _playableCellSet = cells.toSet();
  }

  bool _isPlayable(GamePoint p) => _playableCellSet.contains(p);

  void _cancelLightsOutFoodTimer() {
    _lightsOutFoodTimer?.cancel();
    _lightsOutFoodTimer = null;
  }

  void _startLightsOutFoodCycleIfNeeded({bool notify = true}) {
    _cancelLightsOutFoodTimer();
    if (_currentLevel != GameLevel.lightsOut || _status != GameStatus.playing) {
      _lightsOutFoodVisible = true;
      if (notify) {
        notifyListeners();
      }
      return;
    }
    _lightsOutFoodVisible = true;
    if (notify) {
      notifyListeners();
    }
    _lightsOutFoodTimer = Timer(const Duration(seconds: 1), () {
      if (_currentLevel != GameLevel.lightsOut ||
          _status != GameStatus.playing) {
        return;
      }
      _lightsOutFoodVisible = false;
      notifyListeners();
      _scheduleLightsOutFoodRespawn();
    });
  }

  void _scheduleLightsOutFoodRespawn() {
    _cancelLightsOutFoodTimer();
    final int hiddenMs = 1000;
    _lightsOutFoodTimer = Timer(Duration(milliseconds: hiddenMs), () {
      if (_currentLevel != GameLevel.lightsOut ||
          _status != GameStatus.playing) {
        return;
      }
      _lightsOutFoodVisible = true;
      notifyListeners();
      _startLightsOutFoodCycleIfNeeded(notify: false);
    });
  }

  List<GamePoint> _buildIntermediatePlayableShape(int shape, Random random) {
    final Set<GamePoint> cells = <GamePoint>{};

    void fillRect(int x0, int y0, int w, int h) {
      for (int x = x0; x < x0 + w; x++) {
        for (int y = y0; y < y0 + h; y++) {
          if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
            cells.add(GamePoint(x, y));
          }
        }
      }
    }

    switch (shape) {
      case 0:
        // Classic plus with random arm widths
        final int colW = 4 + random.nextInt(3); // 4..6
        final int rowH = 5 + random.nextInt(3); // 5..7
        final int colX = (gridWidth - colW) ~/ 2;
        final int rowY = (gridHeight - rowH) ~/ 2;
        fillRect(colX, 0, colW, gridHeight);
        fillRect(0, rowY, gridWidth, rowH);
        break;
      case 1:
        // T shape
        final int stemW = 4 + random.nextInt(2); // 4..5
        final int stemX = (gridWidth - stemW) ~/ 2;
        fillRect(stemX, 2, stemW, gridHeight - 4);
        fillRect(1, 2, gridWidth - 2, 7);
        break;
      case 2:
        // H shape
        fillRect(1, 2, 5, gridHeight - 4);
        fillRect(gridWidth - 6, 2, 5, gridHeight - 4);
        fillRect(4, (gridHeight ~/ 2) - 3, gridWidth - 8, 6);
        break;
      case 3:
        // Dumbbell (two rooms connected by a corridor)
        final bool vertical = random.nextBool();
        if (vertical) {
          fillRect(3, 2, gridWidth - 6, 8);
          fillRect((gridWidth ~/ 2) - 2, 9, 4, gridHeight - 18);
          fillRect(3, gridHeight - 10, gridWidth - 6, 8);
        } else {
          fillRect(1, 6, 7, gridHeight - 12);
          fillRect(7, (gridHeight ~/ 2) - 2, gridWidth - 14, 4);
          fillRect(gridWidth - 8, 6, 7, gridHeight - 12);
        }
        break;
      case 4:
        // Offset cross (asymmetric)
        fillRect((gridWidth ~/ 2) - 2, 0, 5, gridHeight);
        fillRect(0, (gridHeight ~/ 2) - 2, gridWidth - 3, 5);
        break;
      default:
        // Puzzle-ish stepped corridor
        fillRect(2, 2, 6, 6);
        fillRect(6, 6, 4, 6);
        fillRect(6, 12, 8, 4);
        fillRect(12, 12, 4, 7);
        fillRect(9, 19, 7, 5);
        fillRect(5, 21, 5, 6);
        break;
    }

    // Guarantee center playability for spawn search stability
    fillRect((gridWidth ~/ 2) - 2, (gridHeight ~/ 2) - 3, 5, 7);

    return cells.toList();
  }

  List<GamePoint> _buildLightsOutPlayableShape(Random random) {
    const int minPlayableCells = 290;
    List<GamePoint> bestCells = _buildFullPlayableCells();
    int bestArea = 0;
    int? chosenShape;

    for (int i = 0; i < 24; i++) {
      int shapePattern = random.nextInt(6);
      if (_lastLightsOutShapeId != null &&
          shapePattern == _lastLightsOutShapeId) {
        shapePattern = (shapePattern + 1 + random.nextInt(5)) % 6;
      }
      final List<GamePoint> candidate = _buildIntermediatePlayableShape(
        shapePattern,
        random,
      );
      final int area = candidate.length;
      if (area > bestArea) {
        bestArea = area;
        bestCells = candidate;
        chosenShape = shapePattern;
      }
      if (area >= minPlayableCells && _isConnectedPlayableArea(candidate)) {
        _lastLightsOutShapeId = shapePattern;
        return candidate;
      }
    }

    _lastLightsOutShapeId = chosenShape ?? _lastLightsOutShapeId;
    if (_isConnectedPlayableArea(bestCells)) {
      return bestCells;
    }
    return _buildFullPlayableCells();
  }

  bool _isConnectedPlayableArea(List<GamePoint> cells) {
    if (cells.isEmpty) {
      return false;
    }
    final Set<GamePoint> cellSet = cells.toSet();
    final Set<GamePoint> visited = <GamePoint>{};
    final List<GamePoint> queue = <GamePoint>[cells.first];
    visited.add(cells.first);

    int index = 0;
    while (index < queue.length) {
      final GamePoint current = queue[index++];
      for (final Direction dir in Direction.values) {
        final GamePoint next = _step(current, dir);
        if (!cellSet.contains(next) || visited.contains(next)) {
          continue;
        }
        visited.add(next);
        queue.add(next);
      }
    }
    return visited.length == cellSet.length;
  }

  void _generateIntermediateObstacles(Random random) {
    _obstacles = [];
    final int pattern = random.nextInt(3);

    bool canPlace(GamePoint p) {
      final int centerX = gridWidth ~/ 2;
      final int centerY = gridHeight ~/ 2;
      final bool nearSpawn =
          (p.x - centerX).abs() <= 2 && (p.y - centerY).abs() <= 4;
      return _isPlayable(p) && !_obstacles.contains(p) && !nearSpawn;
    }

    void addPoint(GamePoint p) {
      if (canPlace(p)) {
        _obstacles.add(p);
      }
    }

    if (pattern == 0) {
      final int count = 12 + random.nextInt(7);
      for (int i = 0; i < count; i++) {
        final GamePoint p =
            _playableCells[random.nextInt(_playableCells.length)];
        addPoint(p);
      }
      return;
    }

    if (pattern == 1) {
      final int y = (gridHeight ~/ 2) - 5 + random.nextInt(11);
      final int xStart = (gridWidth ~/ 2) - 3;
      for (int x = xStart; x < xStart + 7; x++) {
        addPoint(GamePoint(x, y));
      }
      final int x = (gridWidth ~/ 2) - 3 + random.nextInt(7);
      final int yStart = (gridHeight ~/ 2) - 4;
      for (int y2 = yStart; y2 < yStart + 9; y2++) {
        addPoint(GamePoint(x, y2));
      }
      return;
    }

    final int xLeft = (gridWidth ~/ 2) - 6;
    final int xRight = (gridWidth ~/ 2) + 5;
    final int yStart = (gridHeight ~/ 2) - 4;
    for (int y = yStart; y < yStart + 8; y++) {
      addPoint(GamePoint(xLeft, y));
      addPoint(GamePoint(xRight, y));
    }
  }

  void _generateZenMasterObstacles(Random random) {
    int pattern = (_lastZenPatternId ?? -1) + 1;
    if (pattern >= 3) pattern = 0; // Rotate 0 -> 1 -> 2 -> 0
    _lastZenPatternId = pattern;

    final Set<GamePoint> zenWalls = <GamePoint>{};

    switch (pattern) {
      case 0:
        _buildZenConcentric(zenWalls);
        break;
      case 1:
        _buildZenGate(zenWalls);
        break;
      case 2:
        _buildZenLadder(zenWalls);
        break;
    }

    _obstacles = zenWalls.toList();
  }

  void _buildZenConcentric(Set<GamePoint> walls) {
    final int centerX = gridWidth ~/ 2;
    final int centerY = gridHeight ~/ 2;

    for (int x = 0; x < gridWidth; x++) {
      for (int y = 0; y < gridHeight; y++) {
        // Calculate distance from edges
        final int edgeDistX = min(x, gridWidth - 1 - x);
        final int edgeDistY = min(y, gridHeight - 1 - y);

        // Calculate distance from center
        final int dx = (x - centerX).abs();
        final int dy = (y - centerY).abs();

        bool isWall = false;

        // Ring 1 (Outer) - Inset 1
        if ((edgeDistX == 1 && edgeDistY >= 1) ||
            (edgeDistY == 1 && edgeDistX >= 1)) {
          isWall = true;
          // Openings: Top/Bottom Center
          if (edgeDistY == 1 && dx <= 1) isWall = false;
        }

        // Ring 2 (Middle) - Inset 4
        if ((edgeDistX == 4 && edgeDistY >= 4) ||
            (edgeDistY == 4 && edgeDistX >= 4)) {
          isWall = true;
          // Openings: Left/Right Center
          if (edgeDistX == 4 && dy <= 1) isWall = false;
        }

        // Ring 3 (Inner) - Inset 7
        if ((edgeDistX == 7 && edgeDistY >= 7) ||
            (edgeDistY == 7 && edgeDistX >= 7)) {
          isWall = true;
          // Openings: Top/Bottom Center
          if (edgeDistY == 7 && dx <= 1) isWall = false;
        }

        // Inner Pillars (Center Chamber Accents)
        // Placed symmetrically inside the innermost ring
        if (dx == 2 && dy == 2) {
          // Corner pillars inside the center
          isWall = true;
        }

        if (_isSafeZone(x, y)) {
          isWall = false;
        }

        if (isWall) {
          walls.add(GamePoint(x, y));
        }
      }
    }
    // Add single block right in center (requested tweak)
    walls.add(GamePoint(centerX, centerY));
  }

  void _buildZenGate(Set<GamePoint> walls) {
    // Two large vertical structures side-by-side with a central channel.
    for (int x = 0; x < gridWidth; x++) {
      for (int y = 0; y < gridHeight; y++) {
        if (_isSafeZone(x, y)) continue;

        // Left Block: x in [2, 8], y in [2, 28]
        // Right Block: x in [12, 18], y in [2, 28]
        bool isWall = false;

        if ((x >= 2 && x <= 8) || (x >= 12 && x <= 18)) {
          if (y >= 2 && y <= gridHeight - 3) {
            // Hollow out the blocks
            if (x > 2 && x < 8 && y > 2 && y < gridHeight - 3) {
              isWall = false;
            } else if (x > 12 && x < 18 && y > 2 && y < gridHeight - 3) {
              isWall = false;
            } else {
              isWall = true;
            }
          }
        }

        // Add openings to the blocks
        if (isWall) {
          // Side openings
          if ((x == 2 || x == 18) && (y == gridHeight ~/ 2)) isWall = false;
          // Inner openings
          if ((x == 8 || x == 12) && (y == 8 || y == gridHeight - 9)) {
            isWall = false;
          }
        }

        if (isWall) walls.add(GamePoint(x, y));
      }
    }
  }

  void _buildZenLadder(Set<GamePoint> walls) {
    // Horizontal layers with alternating gaps.
    for (int y = 4; y < gridHeight - 4; y += 5) {
      for (int x = 2; x < gridWidth - 2; x++) {
        if (_isSafeZone(x, y)) continue;

        // Gap pattern: Center gap for even index layers, Side gaps for odd
        bool isGap = false;
        if ((y ~/ 5) % 2 == 0) {
          // Center gap
          if ((x - (gridWidth ~/ 2)).abs() <= 2) isGap = true;
        } else {
          // Side gaps
          if (x < 5 || x > gridWidth - 6) isGap = true;
        }

        if (!isGap) {
          walls.add(GamePoint(x, y));
        }
      }
    }

    // Vertical connectors on sides
    for (int y = 4; y < gridHeight - 4; y++) {
      if (_isSafeZone(2, y)) continue;
      walls.add(GamePoint(2, y));
      walls.add(GamePoint(gridWidth - 3, y));
    }
  }

  bool _isSafeZone(int x, int y) {
    final int centerX = gridWidth ~/ 2;
    final int centerY = gridHeight ~/ 2;
    final int dx = (x - centerX).abs();
    // final int dy = (y - centerY).abs();

    // Center Spawn Area - REMOVED to allow center blocks in Zen patterns
    // if (dx <= 1 && dy <= 2) return true;

    // Fallback Spawn Line (Vertical below center)
    if (dx == 0 && y >= centerY + 3 && y <= centerY + 8) return true;

    return false;
  }

  void _generateBeginnerObstacles(Random random) {
    _obstacles = [];
    final int clusterCount = 3 + random.nextInt(2); // 3..4 clusters

    bool isNearSpawnZone(GamePoint p) {
      final int centerX = gridWidth ~/ 2;
      final int centerY = gridHeight ~/ 2;
      return (p.x - centerX).abs() <= 3 && (p.y - centerY).abs() <= 5;
    }

    for (int c = 0; c < clusterCount; c++) {
      bool placed = false;
      for (int attempt = 0; attempt < 60 && !placed; attempt++) {
        final bool horizontal = random.nextBool();
        final int length = 2 + random.nextInt(2); // 2..3, never single
        final int startX = random.nextInt(gridWidth);
        final int startY = random.nextInt(gridHeight);

        final List<GamePoint> cluster = [];
        bool valid = true;
        for (int i = 0; i < length; i++) {
          final int x = horizontal ? startX + i : startX;
          final int y = horizontal ? startY : startY + i;
          final GamePoint p = GamePoint(x, y);
          if (x < 0 ||
              x >= gridWidth ||
              y < 0 ||
              y >= gridHeight ||
              !_isPlayable(p) ||
              _obstacles.contains(p) ||
              isNearSpawnZone(p)) {
            valid = false;
            break;
          }
          cluster.add(p);
        }

        if (valid && cluster.length >= 2) {
          _obstacles.addAll(cluster);
          placed = true;
        }
      }
    }
  }

  (List<GamePoint>, Direction) _buildInitialSpawn(Random random) {
    final List<GamePoint> candidateHeads = List<GamePoint>.from(_playableCells)
      ..shuffle(random);
    final List<Direction> dirs = List<Direction>.from(Direction.values);

    for (final head in candidateHeads) {
      dirs.shuffle(random);
      for (final dir in dirs) {
        final Direction behind = _opposite(dir);
        final GamePoint mid = _step(head, behind);
        final GamePoint tail = _step(mid, behind);
        final List<GamePoint> spawn = [head, mid, tail];

        final bool spawnValid = spawn.every(
          (p) => _isPlayable(p) && !_obstacles.contains(p),
        );
        if (!spawnValid) {
          continue;
        }

        final int requiredFree = 4 + random.nextInt(3); // 4..6
        if (!_hasFreeAhead(head, dir, requiredFree, spawn.toSet())) {
          continue;
        }

        return (spawn, dir);
      }
    }

    return (
      [GamePoint(10, 20), GamePoint(10, 21), GamePoint(10, 22)],
      Direction.up,
    );
  }

  Direction _opposite(Direction direction) {
    switch (direction) {
      case Direction.up:
        return Direction.down;
      case Direction.down:
        return Direction.up;
      case Direction.left:
        return Direction.right;
      case Direction.right:
        return Direction.left;
    }
  }

  GamePoint _step(GamePoint from, Direction direction) {
    int x = from.x;
    int y = from.y;
    switch (direction) {
      case Direction.up:
        y -= 1;
        break;
      case Direction.down:
        y += 1;
        break;
      case Direction.left:
        x -= 1;
        break;
      case Direction.right:
        x += 1;
        break;
    }

    if (x < 0) x = gridWidth - 1;
    if (x >= gridWidth) x = 0;
    if (y < 0) y = gridHeight - 1;
    if (y >= gridHeight) y = 0;
    return GamePoint(x, y);
  }

  bool _hasFreeAhead(
    GamePoint head,
    Direction direction,
    int minFree,
    Set<GamePoint> occupied,
  ) {
    GamePoint cursor = head;
    for (int i = 0; i < minFree; i++) {
      cursor = _step(cursor, direction);
      if (!_isPlayable(cursor) ||
          _obstacles.contains(cursor) ||
          occupied.contains(cursor)) {
        return false;
      }
    }
    return true;
  }

  bool _isFoodReachableFromSnake(GamePoint target) {
    if (_snake.isEmpty) {
      return true;
    }
    final GamePoint start = _snake.first;
    final Set<GamePoint> blocked = _obstacles.toSet()..addAll(_snake);
    blocked.remove(start);
    blocked.remove(target);

    final Set<GamePoint> visited = <GamePoint>{start};
    final List<GamePoint> queue = <GamePoint>[start];
    int index = 0;
    while (index < queue.length) {
      final GamePoint current = queue[index++];
      if (current == target) {
        return true;
      }
      for (final dir in Direction.values) {
        final GamePoint next = _step(current, dir);
        if (!_isPlayable(next) ||
            blocked.contains(next) ||
            visited.contains(next)) {
          continue;
        }
        visited.add(next);
        queue.add(next);
      }
    }
    return false;
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _cancelLightsOutFoodTimer();
    for (final player in _sfxPlayers) {
      player.dispose();
    }
    super.dispose();
  }
}
