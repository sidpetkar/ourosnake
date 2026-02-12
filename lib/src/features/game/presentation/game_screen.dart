import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_snake_game/src/features/game/logic/game_provider.dart';
import 'package:flutter_snake_game/src/features/game/painting/snake_painter.dart';
import 'package:flutter_snake_game/src/features/settings/presentation/settings_screen.dart';
import 'package:flutter_snake_game/src/core/theme/app_theme.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  AnimationController? _homeSlideController;
  Animation<double>? _homeSlideAnimation;
  double _homeSlideProgress = 0.0;
  bool _isHomeDragging = false;
  bool _isHomeHolding = false;
  int _homeLevelIndex = 0;
  double _homeSlideWidth = 1.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
       vsync: this, 
       duration: const Duration(milliseconds: 1000),
    );
    _ensureHomeSlideController();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _homeSlideController?.dispose();
    super.dispose();
  }

  AnimationController _ensureHomeSlideController() {
    return _homeSlideController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_homeSlideAnimation != null && mounted) {
          setState(() {
            _homeSlideProgress = _homeSlideAnimation!.value;
          });
        }
      });
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Access state
    final gameProvider = Provider.of<GameProvider>(context);

    if (gameProvider.status == GameStatus.initial) {
      return _buildHomeScreen(context, gameProvider);
    }
    
    // Manage animation based on state
    if (gameProvider.status == GameStatus.paused || gameProvider.status == GameStatus.gameOver) {
      if (!_animationController.isAnimating) {
        _animationController.repeat(reverse: false);
      }
    } else {
      _animationController.stop();
      _animationController.reset();
    }

    // Calculate aspect ratio based on grid dimensions (20/30 = 0.66)
    final double aspectRatio = GameProvider.gridWidth / GameProvider.gridHeight;

    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          gameProvider.handleSwipeUpdate(details);
        },
        onPanEnd: (details) {
          gameProvider.handleSwipe(details);
        },
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // --- HEADER (Scores) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreBlock(
                      context, 
                      "SCORE", 
                      gameProvider.score,
                      true, // In game score is always relevant
                      textColor: AppTheme.foodOrange,
                    ),
                    _buildScoreBlock(
                      context, 
                      "HIGH", 
                      gameProvider.highScore,
                      false, // Grey for high score
                      textColor: AppTheme.darkText,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // --- GAME BOARD ---
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.90,
                  color: AppTheme.creamBackground,
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: SnakePainter(
                            snake: gameProvider.snake,
                            obstacles: gameProvider.obstacles,
                            playableCells: gameProvider.playableCells,
                            food: gameProvider.food,
                            direction: gameProvider.direction,
                            gridWidth: gameProvider.width,
                            gridHeight: gameProvider.height,
                            animationValue: _animationController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // --- FOOTER (Buttons) ---
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: _buildFooter(context, gameProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeScreen(BuildContext context, GameProvider provider) {
    final homeSlideController = _ensureHomeSlideController();

    if (_homeLevelIndex != provider.currentLevel.index &&
        !homeSlideController.isAnimating &&
        !_isHomeDragging &&
        _homeSlideProgress == 0.0) {
      _homeLevelIndex = provider.currentLevel.index;
    }

    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _onHomeDragStart(),
        onHorizontalDragUpdate: (details) => _onHomeDragUpdate(details),
        onHorizontalDragEnd: (details) => _onHomeDragEnd(details, provider),
        onLongPressStart: (_) => _onHomeLongPressStart(),
        onLongPressEnd: (_) => _onHomeLongPressEnd(provider),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.leaderboard_outlined, color: AppTheme.darkText),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: AppTheme.darkText),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 80),
              
              // Logo
              Image.asset(
                'assets/logo-no-bg.png',
                width: 80, 
                height: 80,
              ),
              
              const SizedBox(height: 32),
              
              Text(
                "SELECT GAME",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 14,
                  letterSpacing: 2.0,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Swipeable Carousel Area (Expanded to take available space)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _homeSlideWidth = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
                    final double textSpacing = _homeSlideWidth * 0.72;
                    final int nextIndex = _wrapLevelIndex(_homeLevelIndex + 1);
                    final int prevIndex = _wrapLevelIndex(_homeLevelIndex - 1);
                    final bool draggingRight = _homeSlideProgress >= 0;
                    final int incomingIndex = draggingRight ? prevIndex : nextIndex;
                    final bool showIncoming = _homeSlideProgress.abs() > 0.0001;
                    final double currentDx = _homeSlideProgress * textSpacing;
                    final double incomingDx = draggingRight
                        ? currentDx - textSpacing
                        : currentDx + textSpacing;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRect(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (showIncoming)
                                Transform.translate(
                                  offset: Offset(incomingDx, 0),
                                  child: _buildLevelText(context, GameLevel.values[incomingIndex]),
                                ),
                              Transform.translate(
                                offset: Offset(currentDx, 0),
                                child: _buildLevelText(context, GameLevel.values[_homeLevelIndex]),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_left_rounded, size: 40, color: AppTheme.darkText),
                                onPressed: () => _animateHomeStep(provider, -1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_right_rounded, size: 40, color: AppTheme.darkText),
                                onPressed: () => _animateHomeStep(provider, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Start Button
              Padding(
                padding: const EdgeInsets.only(bottom: 48.0),
                child: _TextButton(
                  text: "START",
                  onTap: provider.startGame,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLevelText(BuildContext context, GameLevel level) {
    return Text(
      _levelName(level),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: AppTheme.darkText.withValues(alpha: 0.55),
            fontSize: 28,
          ),
    );
  }

  String _levelName(GameLevel level) {
    switch (level) {
      case GameLevel.beginner:
        return "Noob";
      case GameLevel.intermediate:
        return "I've Got It";
      case GameLevel.advanced:
        return "Zen Master";
      case GameLevel.lightsOut:
        return "Lights Out";
    }
  }

  int _wrapLevelIndex(int index) {
    final int length = GameLevel.values.length;
    return ((index % length) + length) % length;
  }

  void _onHomeDragStart() {
    _isHomeDragging = true;
    final homeSlideController = _ensureHomeSlideController();
    if (homeSlideController.isAnimating) {
      homeSlideController.stop();
    }
  }

  void _onHomeDragUpdate(DragUpdateDetails details) {
    setState(() {
      _homeSlideProgress = (_homeSlideProgress + (details.delta.dx / _homeSlideWidth)).clamp(-1.0, 1.0);
    });
  }

  void _onHomeDragEnd(DragEndDetails details, GameProvider provider) {
    _isHomeDragging = false;
    if (_isHomeHolding) {
      return;
    }
    _settleHomeSlide(provider, details.velocity.pixelsPerSecond.dx);
  }

  void _onHomeLongPressStart() {
    _isHomeHolding = true;
    final homeSlideController = _ensureHomeSlideController();
    if (homeSlideController.isAnimating) {
      homeSlideController.stop();
    }
  }

  void _onHomeLongPressEnd(GameProvider provider) {
    _isHomeHolding = false;
    if (!_isHomeDragging) {
      _settleHomeSlide(provider, 0);
    }
  }

  void _animateHomeStep(GameProvider provider, int delta) {
    final homeSlideController = _ensureHomeSlideController();
    if (homeSlideController.isAnimating) {
      homeSlideController.stop();
    }
    _isHomeDragging = false;
    _isHomeHolding = false;
    _homeSlideProgress = 0;
    final double target = delta < 0 ? 1.0 : -1.0;
    _homeSlideAnimation = Tween<double>(begin: 0.0, end: target).animate(
      CurvedAnimation(parent: homeSlideController, curve: Curves.easeOutCubic),
    );
    homeSlideController
      ..duration = const Duration(milliseconds: 220)
      ..forward(from: 0).whenComplete(() {
        _finalizeHomeLevelStep(provider, target);
      });
  }

  void _settleHomeSlide(GameProvider provider, double velocityX) {
    final double normalizedVelocity = velocityX / _homeSlideWidth;
    double target;
    if (normalizedVelocity.abs() > 1.8) {
      target = normalizedVelocity > 0 ? 1.0 : -1.0;
    } else if (_homeSlideProgress.abs() > 0.22) {
      target = _homeSlideProgress > 0 ? 1.0 : -1.0;
    } else {
      target = 0.0;
    }

    final homeSlideController = _ensureHomeSlideController();
    if (homeSlideController.isAnimating) {
      homeSlideController.stop();
    }
    _homeSlideAnimation = Tween<double>(begin: _homeSlideProgress, end: target).animate(
      CurvedAnimation(parent: homeSlideController, curve: Curves.easeOutCubic),
    );
    homeSlideController
      ..duration = const Duration(milliseconds: 180)
      ..forward(from: 0).whenComplete(() {
        _finalizeHomeLevelStep(provider, target);
      });
  }

  void _finalizeHomeLevelStep(GameProvider provider, double target) {
    if (!mounted) {
      return;
    }
    if (target == 1.0) {
      _homeLevelIndex = _wrapLevelIndex(_homeLevelIndex - 1);
      provider.setLevel(GameLevel.values[_homeLevelIndex]);
    } else if (target == -1.0) {
      _homeLevelIndex = _wrapLevelIndex(_homeLevelIndex + 1);
      provider.setLevel(GameLevel.values[_homeLevelIndex]);
    }
    setState(() {
      _homeSlideProgress = 0.0;
    });
  }


  Widget _buildScoreBlock(BuildContext context, String label, int value, bool isPlaying, {Color? textColor}) {
    Color scoreColor = textColor ?? (isPlaying ? AppTheme.foodOrange : AppTheme.foodOrange.withValues(alpha: 0.5));
    // If not playing (initial), show 0 logic? User wants "always show 0 with food color but low opacity"
    // Wait, "back to current screen but there i still see old score".
    // So if Initial/Home -> show 0 (low opacity). If Playing -> show actual score (full opacity).
    
    int displayValue = value;
    // Actually, gameProvider resets score on StartGame. 
    // But on "Home" (Initial), gameProvider.score might still be the old score if we didn't reset it?
    // Let's check provider.endGame(). it sets status to initial but doesn't reset score.
    // User wants to see 0.
    
    // So we can override display here.
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Text(
          displayValue.toString(),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: 40,
            color: scoreColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, GameProvider provider) {
    switch (provider.status) {
      case GameStatus.initial:
        return Center(
          child: _TextButton(
            text: "START",
            onTap: provider.startGame,
          ),
        );
      case GameStatus.playing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TextButton(
              text: "HOME",
              onTap: provider.endGame,
            ),
            _TextButton(
              text: "PAUSE",
              onTap: provider.pauseGame,
            ),
          ],
        );
      case GameStatus.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TextButton(
              text: "HOME",
              onTap: provider.endGame,
            ),
            _TextButton(
              text: "RESUME",
              onTap: provider.pauseGame,
            ),
          ],
        );
      case GameStatus.gameOver:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TextButton(
              text: "HOME",
              onTap: provider.endGame,
            ),
            _TextButton(
              text: "RESTART",
              onTap: provider.startGame,
            ),
          ],
        );
    }
  }
}

class _TextButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _TextButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
