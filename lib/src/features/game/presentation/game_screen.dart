import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_snake_game/src/features/game/logic/game_provider.dart';
import 'package:flutter_snake_game/src/features/game/painting/snake_painter.dart';
import 'package:flutter_snake_game/src/core/theme/app_theme.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access state
    final gameProvider = Provider.of<GameProvider>(context);

    // Calculate aspect ratio based on grid dimensions (20/30 = 0.66)
    // The screen in screenshot is roughly that ratio.
    final double aspectRatio = GameProvider.gridWidth / GameProvider.gridHeight;

    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
                    _buildScoreBlock(context, "SCORE", gameProvider.score),
                    _buildScoreBlock(context, "HIGH", gameProvider.highScore),
                  ],
                ),
              ),

              const Spacer(),

              // --- GAME BOARD ---
              // Wrapped in a container with rounded corners and border
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.90,
                  decoration: BoxDecoration(
                    color: AppTheme.creamBackground,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppTheme.containerBorder,
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: CustomPaint(
                        painter: SnakePainter(
                          snake: gameProvider.snake,
                          food: gameProvider.food,
                          gridWidth: gameProvider.width,
                          gridHeight: gameProvider.height,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Game Over Overlay (Conditional, but maybe integrated directly or separate?)
              // For simplicity, we just show "Game Over"? No, user wanted "Restart" button at bottom.
              // So the board just freezes on Game Over.

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

  Widget _buildScoreBlock(BuildContext context, String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 40),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, GameProvider provider) {
    // States:
    // 1. Initial -> START
    // 2. Playing -> EXIT  PAUSE
    // 3. Paused -> EXIT  RESUME
    // 4. GameOver -> EXIT  RESTART

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
              text: "EXIT",
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
              text: "EXIT",
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
              text: "EXIT",
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
