import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/models/vps_model.dart';
import '../../core/models/window_state.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/glass_settings_provider.dart';
import '../../providers/vps_connection_provider.dart';
import '../../providers/window_manager_provider.dart';
import '../common/gauge_arc.dart';
import '../common/glass_container.dart';
import '../common/sparkline.dart';

/// Live desktop widget that shows CPU/RAM stats for a connected VPS.
/// Tap to open the full Dashboard window.
class VpsStatsWidget extends ConsumerWidget {
  const VpsStatsWidget({super.key, required this.vps, this.onTap});
  final VpsModel vps;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(vpsConnectionProvider(vps.id));
    final isConnected = conn.valueOrNull?.isConnected == true;

    if (!isConnected) return const SizedBox.shrink();

    final glass = ref.watch(glassSettingsProvider);
    return GestureDetector(
      onTap: onTap ?? () => _openDashboard(context, ref),
      child: GlassContainer(
        borderRadius: 16,
        color: glass.windowColor,
        blurSigma: glass.blur,
        child: SizedBox(
          width: 200,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _WidgetBody(vps: vps),
          ),
        ),
      ),
    );
  }

  void _openDashboard(BuildContext context, WidgetRef ref) {
    final screen = MediaQuery.sizeOf(context);
    final windowId = '${vps.id}_dashboard';
    ref.read(windowManagerProvider.notifier).openWindow(
      WindowManagerNotifier.makeWindow(
        windowId: windowId,
        vpsId: vps.id,
        type: WindowType.dashboard,
        title: 'Dashboard — ${vps.label}',
        screen: screen,
      ),
    );
  }
}

class _WidgetBody extends ConsumerWidget {
  const _WidgetBody({required this.vps});
  final VpsModel vps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider(vps.id));
    final stats = dash.stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.circle, size: 7, color: AetherColors.accentTeal),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                vps.label,
                style: const TextStyle(
                  color: AetherColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.open_in_new, size: 10,
                color: AetherColors.textSecondary),
          ],
        ),

        if (stats == null) ...[
          const SizedBox(height: 12),
          const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AetherColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ] else ...[
          const SizedBox(height: 10),

          // CPU row
          Row(
            children: [
              GaugeArc(
                value: stats.cpu.usagePercent,
                label: 'CPU',
                size: 56,
                strokeWidth: 6,
                color: _cpuColor(stats.cpu.usagePercent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stats.cpu.usagePercent.toStringAsFixed(1)}% used',
                      style: const TextStyle(
                          color: AetherColors.textPrimary, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Load ${stats.cpu.loadAvg[0].toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: AetherColors.textSecondary, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    if (dash.cpuHistory.length > 1)
                      SizedBox(
                        height: 20,
                        child: Sparkline(
                          data: dash.cpuHistory,
                          color: _cpuColor(stats.cpu.usagePercent),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(color: AetherColors.glassBorder, height: 1),
          const SizedBox(height: 8),

          // RAM row
          _RamRow(
            usedBytes: stats.mem.usedBytes,
            totalBytes: stats.mem.totalBytes,
            usagePercent: stats.mem.usagePercent,
          ),

          const SizedBox(height: 8),

          // Uptime
          Row(
            children: [
              const Icon(Icons.access_time, size: 10,
                  color: AetherColors.textSecondary),
              const SizedBox(width: 3),
              Text(
                'Up ${stats.uptimeFormatted}',
                style: const TextStyle(
                    color: AetherColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _cpuColor(double v) {
    if (v > 80) return AetherColors.accentRed;
    if (v > 60) return AetherColors.accentYellow;
    return AetherColors.accent;
  }
}

class _RamRow extends StatelessWidget {
  const _RamRow({
    required this.usedBytes,
    required this.totalBytes,
    required this.usagePercent,
  });
  final int usedBytes;
  final int totalBytes;
  final double usagePercent;

  String _gb(int bytes) => '${(bytes / 1e9).toStringAsFixed(1)}G';

  @override
  Widget build(BuildContext context) {
    final ramColor = usagePercent > 85
        ? AetherColors.accentRed
        : AetherColors.accentTeal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('RAM',
                style: TextStyle(
                    color: AetherColors.textSecondary, fontSize: 10)),
            const Spacer(),
            Text(
              '${_gb(usedBytes)} / ${_gb(totalBytes)}',
              style: const TextStyle(
                  color: AetherColors.textPrimary, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (usagePercent / 100).clamp(0.0, 1.0),
            backgroundColor: AetherColors.glassBase,
            valueColor: AlwaysStoppedAnimation(ramColor),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
