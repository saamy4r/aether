import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/glass_settings_provider.dart';

class SettingsWindowContent extends ConsumerWidget {
  const SettingsWindowContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = ref.watch(glassSettingsProvider);
    final notifier = ref.read(glassSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        const _SectionHeader(icon: Icons.blur_on, label: 'Window Appearance'),
        const SizedBox(height: 4),
        const Text(
          'Changes apply live to all open windows.',
          style: TextStyle(color: AetherColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 12),

        _SliderRow(
          label: 'Background opacity',
          valueLabel: '${(glass.opacity * 100).round()}%',
          value: glass.opacity,
          min: GlassSettings.minOpacity,
          max: GlassSettings.maxOpacity,
          onChanged: (v) => notifier.setOpacity(v, persist: false),
          onChangeEnd: (v) => notifier.setOpacity(v),
        ),
        const SizedBox(height: 4),
        _SliderRow(
          label: 'Blur intensity',
          valueLabel: glass.blur.round().toString(),
          value: glass.blur,
          min: 0,
          max: GlassSettings.maxBlur,
          onChanged: (v) => notifier.setBlur(v, persist: false),
          onChangeEnd: (v) => notifier.setBlur(v),
        ),
        const SizedBox(height: 8),

        SwitchListTile(
          value: glass.darkGlass,
          onChanged: notifier.setDarkGlass,
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AetherColors.accent,
          title: const Text(
            'Dark glass tint',
            style: TextStyle(color: AetherColors.textPrimary, fontSize: 13),
          ),
          subtitle: const Text(
            'Recommended for light or white wallpapers',
            style: TextStyle(color: AetherColors.textSecondary, fontSize: 11),
          ),
        ),
        const SizedBox(height: 12),

        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: notifier.reset,
            icon: const Icon(Icons.restart_alt,
                size: 16, color: AetherColors.textSecondary),
            label: const Text(
              'Reset to defaults',
              style:
                  TextStyle(color: AetherColors.textSecondary, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AetherColors.accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AetherColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AetherColors.textPrimary, fontSize: 13)),
            Text(valueLabel,
                style: const TextStyle(
                    color: AetherColors.textSecondary, fontSize: 12)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AetherColors.accent,
            inactiveTrackColor: AetherColors.glassBorder,
            thumbColor: AetherColors.accent,
            overlayColor: AetherColors.accent.withValues(alpha: 0.15),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
