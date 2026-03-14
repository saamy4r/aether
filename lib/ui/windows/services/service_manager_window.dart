import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/service_model.dart';
import '../../../providers/service_provider.dart';

class ServiceManagerWindowContent extends ConsumerStatefulWidget {
  const ServiceManagerWindowContent({super.key, required this.vpsId});
  final String vpsId;

  @override
  ConsumerState<ServiceManagerWindowContent> createState() =>
      _ServiceManagerWindowContentState();
}

class _ServiceManagerWindowContentState
    extends ConsumerState<ServiceManagerWindowContent> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceProvider(widget.vpsId));

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AetherColors.accent),
      );
    }

    if (!state.isAvailable) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_applications_outlined,
                size: 48, color: AetherColors.textSecondary),
            SizedBox(height: 12),
            Text('systemd not found on this host',
                style: TextStyle(
                    color: AetherColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    final filtered = _applyFilter(state.services, _filter);

    return Column(
      children: [
        _ControlBar(
          total: state.services.length,
          onRefresh: () =>
              ref.read(serviceProvider(widget.vpsId).notifier).refresh(),
        ),
        _FilterRow(
          selected: _filter,
          services: state.services,
          onChanged: (f) => setState(() => _filter = f),
        ),
        if (state.errorMessage != null)
          Container(
            color: AetherColors.accentRed.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.warning_amber,
                    size: 12, color: AetherColors.accentRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(
                        color: AetherColors.accentRed, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        const _ListHeader(),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No services match',
                    style: TextStyle(
                        color: AetherColors.textSecondary, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ServiceRow(
                    service: filtered[i],
                    vpsId: widget.vpsId,
                  ),
                ),
        ),
      ],
    );
  }

  List<ServiceModel> _applyFilter(List<ServiceModel> all, _Filter f) =>
      switch (f) {
        _Filter.all      => all,
        _Filter.active   => all.where((s) => s.activeState == ServiceActiveState.active).toList(),
        _Filter.inactive => all.where((s) => s.isInactive).toList(),
        _Filter.failed   => all.where((s) => s.isFailed).toList(),
      };
}

// ── Control bar ──────────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.total, required this.onRefresh});
  final int total;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Text('$total services',
              style: const TextStyle(
                  color: AetherColors.textSecondary, fontSize: 11)),
          const Spacer(),
          GestureDetector(
            onTap: onRefresh,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.refresh,
                  size: 16, color: AetherColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chips ─────────────────────────────────────────────────────────────

enum _Filter { all, active, inactive, failed }

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.services,
    required this.onChanged,
  });
  final _Filter selected;
  final List<ServiceModel> services;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final counts = {
      _Filter.all:      services.length,
      _Filter.active:   services.where((s) => s.activeState == ServiceActiveState.active).length,
      _Filter.inactive: services.where((s) => s.isInactive).length,
      _Filter.failed:   services.where((s) => s.isFailed).length,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Row(
        children: _Filter.values.map((f) {
          final active = f == selected;
          final label = switch (f) {
            _Filter.all      => 'All',
            _Filter.active   => 'Active',
            _Filter.inactive => 'Inactive',
            _Filter.failed   => 'Failed',
          };
          final color = switch (f) {
            _Filter.all      => AetherColors.accent,
            _Filter.active   => AetherColors.accentGreen,
            _Filter.inactive => AetherColors.textSecondary,
            _Filter.failed   => AetherColors.accentRed,
          };
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => onChanged(f),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: 0.15)
                      : AetherColors.glassBase,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: active
                        ? color.withValues(alpha: 0.5)
                        : AetherColors.glassBorder,
                  ),
                ),
                child: Text(
                  '${label} (${counts[f]})',
                  style: TextStyle(
                      color: active ? color : AetherColors.textSecondary,
                      fontSize: 10),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Column widths — kept in one place so header and rows stay in sync.
const double _kStatusW  = 68.0;   // "Status" badge column
const double _kActionsW = 120.0;  // icon-button actions column

// ── Column header ─────────────────────────────────────────────────────────────

class _ListHeader extends StatelessWidget {
  const _ListHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AetherColors.glassBase,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: const Row(
        children: [
          SizedBox(width: 14), // dot
          SizedBox(width: 6),
          Expanded(
            child: Text('Service',
                style: TextStyle(
                    color: AetherColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: _kStatusW,
            child: Text('Status',
                style: TextStyle(
                    color: AetherColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: _kActionsW,
            child: Text('Actions',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: AetherColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Service row ───────────────────────────────────────────────────────────────

class _ServiceRow extends ConsumerWidget {
  const _ServiceRow({required this.service, required this.vpsId});
  final ServiceModel service;
  final String vpsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(serviceProvider(vpsId).notifier);
    final s = service;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AetherColors.glassBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _dotColor(s),
            ),
          ),
          const SizedBox(width: 6),
          // Unit name + description
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: const TextStyle(
                      color: AetherColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                if (s.description.isNotEmpty)
                  Text(
                    s.description,
                    style: const TextStyle(
                        color: AetherColors.textSecondary, fontSize: 9),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Column 2 — Status badge
          SizedBox(
            width: _kStatusW,
            child: _SubStateBadge(s.subState),
          ),
          // Column 3 — Actions (icon buttons, right-aligned, never wrap)
          SizedBox(
            width: _kActionsW,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!s.isRunning)
                  _ActionIcon(
                    icon: Icons.play_arrow_rounded,
                    color: AetherColors.accentGreen,
                    tooltip: 'Start',
                    onTap: () => notifier.startService(s.name),
                  ),
                if (s.isRunning) ...[
                  _ActionIcon(
                    icon: Icons.stop_rounded,
                    color: AetherColors.accentRed,
                    tooltip: 'Stop',
                    onTap: () => notifier.stopService(s.name),
                  ),
                  _ActionIcon(
                    icon: Icons.restart_alt,
                    color: AetherColors.accent,
                    tooltip: 'Restart',
                    onTap: () => notifier.restartService(s.name),
                  ),
                  _ActionIcon(
                    icon: Icons.refresh,
                    color: AetherColors.accentTeal,
                    tooltip: 'Reload',
                    onTap: () => notifier.reloadService(s.name),
                  ),
                ],
                if (s.loadState == 'loaded')
                  _ActionIcon(
                    icon: Icons.remove_circle_outline,
                    color: AetherColors.accentYellow,
                    tooltip: 'Disable',
                    onTap: () => notifier.disableService(s.name),
                  )
                else if (s.loadState != 'masked')
                  _ActionIcon(
                    icon: Icons.check_circle_outline,
                    color: AetherColors.accentTeal,
                    tooltip: 'Enable',
                    onTap: () => notifier.enableService(s.name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor(ServiceModel s) {
    if (s.isFailed) return AetherColors.accentRed;
    if (s.isRunning) return AetherColors.accentGreen;
    if (s.activeState == ServiceActiveState.active) return AetherColors.accentTeal;
    if (s.activeState == ServiceActiveState.activating ||
        s.activeState == ServiceActiveState.deactivating) {
      return AetherColors.accentYellow;
    }
    return AetherColors.textSecondary;
  }
}

// ── Sub-state badge ───────────────────────────────────────────────────────────

class _SubStateBadge extends StatelessWidget {
  const _SubStateBadge(this.subState);
  final ServiceSubState subState;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (subState) {
      ServiceSubState.running => ('running', AetherColors.accentGreen),
      ServiceSubState.dead    => ('dead',    AetherColors.textSecondary),
      ServiceSubState.exited  => ('exited',  AetherColors.accentTeal),
      ServiceSubState.waiting => ('waiting', AetherColors.accentYellow),
      ServiceSubState.stop    => ('stop',    AetherColors.accentRed),
      ServiceSubState.failed  => ('failed',  AetherColors.accentRed),
      ServiceSubState.unknown => ('—',       AetherColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Action icon button ────────────────────────────────────────────────────────

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

// kept for any future text-label usage
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10),
        ),
      ),
    );
  }
}
