import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60000),
    );
    _ensureHomeSlideController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _animationController.dispose();
    _homeSlideController?.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      gameProvider.setDirection(Direction.up);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      gameProvider.setDirection(Direction.down);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      gameProvider.setDirection(Direction.left);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      gameProvider.setDirection(Direction.right);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      if (gameProvider.status == GameStatus.playing) {
        gameProvider.pauseGame();
      } else if (gameProvider.status == GameStatus.paused) {
        gameProvider.pauseGame();
      } else if (gameProvider.status == GameStatus.gameOver ||
                 gameProvider.status == GameStatus.initial) {
        gameProvider.startGame();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  AnimationController _ensureHomeSlideController() {
    return _homeSlideController ??=
        AnimationController(
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
  Widget build(BuildContext context) {
    // Access state
    final gameProvider = Provider.of<GameProvider>(context);
    final bool isLightsOut = gameProvider.currentLevel == GameLevel.lightsOut;

    if (gameProvider.status == GameStatus.initial) {
      if (_animationController.isAnimating) {
        _animationController.stop();
        _animationController.reset();
      }
      return _buildHomeScreen(context, gameProvider);
    }

    // Keep animation running while playing and after death, but freeze on pause.
    if (gameProvider.status == GameStatus.paused) {
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
    } else if (!_animationController.isAnimating) {
      _animationController.repeat(reverse: false);
    }

    // Calculate aspect ratio based on grid dimensions (20/30 = 0.66)
    final double aspectRatio = GameProvider.gridWidth / GameProvider.gridHeight;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: isLightsOut
            ? AppTheme.lightsOutBackground
            : AppTheme.creamBackground,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focusNode.requestFocus(),
          onPanUpdate: (details) {
            gameProvider.handleSwipeUpdate(details);
          },
          onPanEnd: (details) {
            gameProvider.handleSwipe(details);
          },
          child: SafeArea(
            bottom: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalH = constraints.maxHeight;
                final totalW = constraints.maxWidth;

                // Reserve space for header (~12%) and footer (~8%)
                final headerH = totalH * 0.12;
                final footerH = totalH * 0.08;
                final boardMaxH = totalH - headerH - footerH;

                // Compute board width: fit by height first, then clamp to 90% of width
                final boardWidthFromHeight = boardMaxH * aspectRatio;
                final boardWidthFromWidth = totalW * 0.90;
                final boardW = boardWidthFromHeight < boardWidthFromWidth
                    ? boardWidthFromHeight
                    : boardWidthFromWidth;
                final boardH = boardW / aspectRatio;

                return SizedBox(
                  height: totalH,
                  child: Column(
                    children: [
                      SizedBox(height: totalH * 0.02),
                      // --- HEADER (Scores) aligned to grid width ---
                      Center(
                        child: SizedBox(
                          width: boardW,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildScoreBlock(
                                context,
                                "SCORE",
                                gameProvider.score,
                                true,
                                textColor: AppTheme.foodOrange,
                                labelColor: isLightsOut
                                    ? AppTheme.lightsOutText.withValues(alpha: 0.75)
                                    : null,
                              ),
                              _buildScoreBlock(
                                context,
                                "HIGH",
                                gameProvider.highScore,
                                false,
                                textColor: isLightsOut
                                    ? AppTheme.lightsOutText
                                    : AppTheme.darkText,
                                labelColor: isLightsOut
                                    ? AppTheme.lightsOutText.withValues(alpha: 0.70)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // --- GAME BOARD ---
                      Center(
                        child: SizedBox(
                          width: boardW,
                          height: boardH,
                          child: Container(
                            color: isLightsOut
                                ? AppTheme.lightsOutBoardBackground
                                : AppTheme.creamBackground,
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
                                    currentLevel: gameProvider.currentLevel,
                                    gridWidth: gameProvider.width,
                                    gridHeight: gameProvider.height,
                                    snakeTickSpeedMs: gameProvider.currentTickSpeedMs,
                                    foodVisible: gameProvider.foodVisible,
                                    isGameOver: gameProvider.status == GameStatus.gameOver,
                                    animationValue: _animationController.value,
                                    animationCycleMs:
                                        _animationController.duration!.inMilliseconds,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // --- FOOTER (Buttons) aligned to grid width ---
                      Center(
                        child: SizedBox(
                          width: boardW,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: totalH * 0.02),
                            child: _buildFooter(
                              context,
                              gameProvider,
                              isLightsOut: isLightsOut,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── Header: Leaderboard (left) · Settings (right) ──
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // TODO: navigate to leaderboard
                      },
                      child: const Icon(
                        Icons.leaderboard_outlined,
                        color: AppTheme.darkText,
                        size: 24,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.settings_outlined,
                        color: AppTheme.darkText,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Logo
              Image.asset('assets/logo-no-bg.png', width: 80, height: 80),

              const SizedBox(height: 24),

              Text(
                "SELECT GAME",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 14,
                  letterSpacing: 2.0,
                ),
              ),

              const SizedBox(height: 16),

              // Swipeable Carousel Area -- drag handler scoped to this widget only
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _onHomeDragStart(),
                  onHorizontalDragUpdate: (details) => _onHomeDragUpdate(details),
                  onHorizontalDragEnd: (details) => _onHomeDragEnd(details, provider),
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      _homeSlideWidth = innerConstraints.maxWidth <= 0
                          ? 1.0
                          : innerConstraints.maxWidth;
                      final double textSpacing = _homeSlideWidth * 0.72;
                      final int nextIndex = _wrapLevelIndex(_homeLevelIndex + 1);
                      final int prevIndex = _wrapLevelIndex(_homeLevelIndex - 1);
                      final bool draggingRight = _homeSlideProgress >= 0;
                      final int incomingIndex = draggingRight
                          ? prevIndex
                          : nextIndex;
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
                                    child: _buildLevelText(
                                      context,
                                      GameLevel.values[incomingIndex],
                                    ),
                                  ),
                                Transform.translate(
                                  offset: Offset(currentDx, 0),
                                  child: _buildLevelText(
                                    context,
                                    GameLevel.values[_homeLevelIndex],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => _animateHomeStep(provider, -1),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.arrow_left_rounded,
                                    size: 40,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _animateHomeStep(provider, 1),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.arrow_right_rounded,
                                    size: 40,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const Spacer(),

              // Start Button -- OUTSIDE the drag GestureDetector so taps always work
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: GestureDetector(
                  onTap: provider.startGame,
                  child: Text(
                    "START",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.darkText.withValues(alpha: 0.6),
                    ),
                  ),
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
      _homeSlideProgress =
          (_homeSlideProgress + (details.delta.dx / _homeSlideWidth)).clamp(
            -1.0,
            1.0,
          );
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
    _homeSlideAnimation = Tween<double>(begin: _homeSlideProgress, end: target)
        .animate(
          CurvedAnimation(
            parent: homeSlideController,
            curve: Curves.easeOutCubic,
          ),
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

  Widget _buildScoreBlock(
    BuildContext context,
    String label,
    int value,
    bool isPlaying, {
    Color? textColor,
    Color? labelColor,
  }) {
    Color scoreColor =
        textColor ??
        (isPlaying
            ? AppTheme.foodOrange
            : AppTheme.foodOrange.withValues(alpha: 0.5));
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
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: labelColor),
        ),
        const SizedBox(height: 4),
        Text(
          displayValue.toString(),
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(fontSize: 40, color: scoreColor),
        ),
      ],
    );
  }

  Widget _buildFooter(
    BuildContext context,
    GameProvider provider, {
    bool isLightsOut = false,
  }) {
    final Color buttonColor = isLightsOut
        ? AppTheme.lightsOutText.withValues(alpha: 0.85)
        : AppTheme.darkText.withValues(alpha: 0.6);
    switch (provider.status) {
      case GameStatus.initial:
        return Center(
          child: _TextButton(
            text: "START",
            onTap: provider.startGame,
            color: buttonColor,
          ),
        );
      case GameStatus.playing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TextButton(
              text: "HOME",
              onTap: provider.endGame,
              color: buttonColor,
            ),
            _TextButton(
              text: "PAUSE",
              onTap: provider.pauseGame,
              color: buttonColor,
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
              color: buttonColor,
            ),
            _TextButton(
              text: "RESUME",
              onTap: provider.pauseGame,
              color: buttonColor,
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
              color: buttonColor,
            ),
            _TextButton(
              text: "RESTART",
              onTap: provider.startGame,
              color: buttonColor,
            ),
          ],
        );
    }
  }
}

class _TextButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color? color;

  const _TextButton({required this.text, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ),
    );
  }
}
