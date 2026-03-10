import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/server_stats.dart';
import '../../../providers/dashboard_provider.dart';
import '../../common/gauge_arc.dart';
import '../../common/sparkline.dart';

class DashboardWindow extends ConsumerWidget {
  const DashboardWindow({super.key, required this.vpsId});
  final String vpsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider(vpsId));
    final stats = dash.stats;

    if (dash.errorMessage != null && stats == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_wifi_off, color: AetherColors.accentRed),
            const SizedBox(height: 8),
            Text(dash.errorMessage!,
                style: const TextStyle(color: AetherColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(dashboardProvider(vpsId).notifier).retry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (stats == null) {
      return const Center(
        child: CircularProgressIndicator(color: AetherColors.accent),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UptimeRow(stats: stats),
          const SizedBox(height: 12),
          _CpuSection(stats: stats, history: dash.cpuHistory),
          const SizedBox(height: 12),
          _MemSection(stats: stats),
          const SizedBox(height: 12),
          _DiskSection(disks: stats.disks),
          if (stats.network != null) ...[
            const SizedBox(height: 12),
            _NetworkSection(net: stats.network!),
          ],
        ],
      ),
    );
  }
}

class _UptimeRow extends StatelessWidget {
  const _UptimeRow({required this.stats});
  final ServerStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 12, color: AetherColors.textSecondary),
        const SizedBox(width: 4),
        Text('Up ${stats.uptimeFormatted}',
            style: const TextStyle(
                color: AetherColors.textSecondary, fontSize: 11)),
        const Spacer(),
        Text(
          'Load: ${stats.cpu.loadAvg.map((v) => v.toStringAsFixed(2)).join(' ')}',
          style: const TextStyle(color: AetherColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _CpuSection extends StatelessWidget {
  const _CpuSection({required this.stats, required this.history});
  final ServerStats stats;
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GaugeArc(
              value: stats.cpu.usagePercent,
              label: 'CPU',
              color: _cpuColor(stats.cpu.usagePercent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 40,
                child: Sparkline(
                  data: history.isEmpty ? [0.0] : history,
                  color: _cpuColor(stats.cpu.usagePercent),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _cpuColor(double v) {
    if (v > 80) return AetherColors.accentRed;
    if (v > 60) return AetherColors.accentYellow;
    return AetherColors.accent;
  }
}

class _MemSection extends StatelessWidget {
  const _MemSection({required this.stats});
  final ServerStats stats;

  @override
  Widget build(BuildContext context) {
    final mem = stats.mem;
    final usedGb = (mem.usedBytes / 1e9).toStringAsFixed(1);
    final totalGb = (mem.totalBytes / 1e9).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('RAM', style: TextStyle(
                color: AetherColors.textSecondary, fontSize: 11)),
            const Spacer(),
            Text('$usedGb / $totalGb GB',
                style: const TextStyle(
                    color: AetherColors.textPrimary, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        _ProgressBar(
          value: mem.usagePercent / 100,
          color: mem.usagePercent > 85
              ? AetherColors.accentRed
              : AetherColors.accentTeal,
        ),
      ],
    );
  }
}

class _DiskSection extends StatelessWidget {
  const _DiskSection({required this.disks});
  final List<DiskMount> disks;

  @override
  Widget build(BuildContext context) {
    if (disks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Disk', style: TextStyle(
            color: AetherColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        ...disks.take(4).map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(d.mountPoint,
                    style: const TextStyle(
                        color: AetherColors.textPrimary, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 5,
                child: _ProgressBar(
                  value: d.usagePercent / 100,
                  color: d.usagePercent > 90
                      ? AetherColors.accentRed
                      : AetherColors.accent,
                ),
              ),
              const SizedBox(width: 4),
              Text('${d.usagePercent.round()}%',
                  style: const TextStyle(
                      color: AetherColors.textSecondary, fontSize: 10)),
            ],
          ),
        )),
      ],
    );
  }
}

class _NetworkSection extends StatelessWidget {
  const _NetworkSection({required this.net});
  final NetworkStats net;

  String _fmt(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.round()}B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)}K/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)}M/s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.arrow_downward, size: 12, color: AetherColors.accentTeal),
        const SizedBox(width: 2),
        Text(_fmt(net.rxBytesPerSec),
            style: const TextStyle(
                color: AetherColors.textPrimary, fontSize: 11)),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_upward, size: 12, color: AetherColors.accentYellow),
        const SizedBox(width: 2),
        Text(_fmt(net.txBytesPerSec),
            style: const TextStyle(
                color: AetherColors.textPrimary, fontSize: 11)),
        const SizedBox(width: 4),
        Text('(${net.interface_})',
            style: const TextStyle(
                color: AetherColors.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: AetherColors.glassBase,
        valueColor: AlwaysStoppedAnimation(color),
        minHeight: 6,
      ),
    );
  }
}
