import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_snake_game/src/core/theme/app_theme.dart';
import 'package:flutter_snake_game/src/features/game/logic/game_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _buildFooter(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final Uri url = Uri.parse('https://x.com/siddhantpetkar');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: AppTheme.darkText.withValues(alpha: 0.6),
              ),
          children: const [
            TextSpan(text: 'Made with ❤️ by '),
            TextSpan(
              text: '@siddhantpetkar',
              style: TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.creamBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'SETTINGS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.darkText,
                fontSize: 16,
              ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              _SettingToggleTile(
                title: 'SOUND',
                value: provider.soundEnabled,
                onChanged: provider.setSoundEnabled,
              ),
              const SizedBox(height: 12),
              _SettingToggleTile(
                title: 'VIBRATION',
                value: provider.vibrationEnabled,
                onChanged: provider.setVibrationEnabled,
              ),
              const SizedBox(height: 12),
              _SettingToggleTile(
                title: 'THROUGH WALLS',
                value: provider.wrapWallsEnabled,
                onChanged: provider.setWrapWallsEnabled,
              ),
              const Spacer(),
              _buildFooter(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingToggleTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.containerBorder, width: 1.2),
        borderRadius: BorderRadius.circular(6),
        color: AppTheme.creamBackground,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.darkText.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppTheme.foodOrange, // Red thumb when active
            activeTrackColor: AppTheme.containerBorder, // Grey track when active
            inactiveTrackColor: AppTheme.containerBorder, // Grey track when inactive
            inactiveThumbColor: AppTheme.containerBorder.withValues(alpha: 0.8), // Grey thumb when inactive
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
