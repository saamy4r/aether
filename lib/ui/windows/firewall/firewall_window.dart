import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/firewall_models.dart';
import '../../../providers/firewall_provider.dart';

// Quick-rule definitions
const _quickRules = [
  (label: 'SSH',   port: 22,   proto: 'tcp'),
  (label: 'HTTP',  port: 80,   proto: 'tcp'),
  (label: 'HTTPS', port: 443,  proto: 'tcp'),
  (label: 'MySQL', port: 3306, proto: 'tcp'),
];

class FirewallWindowContent extends ConsumerWidget {
  const FirewallWindowContent({super.key, required this.vpsId});
  final String vpsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firewallProvider(vpsId));
    final notifier = ref.read(firewallProvider(vpsId).notifier);

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AetherColors.accent),
      );
    }

    if (!state.ufwAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_outlined,
                  size: 48, color: AetherColors.textSecondary),
              const SizedBox(height: 12),
              const Text(
                'Firewall (UFW) not detected',
                style: TextStyle(
                    color: AetherColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AetherColors.glassBase,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AetherColors.glassBorder),
                ),
                child: const Text(
                  'sudo apt install -y ufw',
                  style: TextStyle(
                    color: AetherColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Global controls bar
        _GlobalBar(state: state, notifier: notifier),
        const Divider(color: AetherColors.glassBorder, height: 1),

        // Quick rules
        _QuickRulesRow(state: state, notifier: notifier, vpsId: vpsId),
        const Divider(color: AetherColors.glassBorder, height: 1),

        // Error bar
        if (state.errorMessage != null)
          Container(
            color: AetherColors.accentRed.withOpacity(0.12),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

        // Column headers
        Container(
          color: AetherColors.glassBase,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: const Row(
            children: [
              SizedBox(width: 16), // dot
              SizedBox(width: 8),
              SizedBox(
                  width: 38,
                  child: Text('PROTO',
                      style: TextStyle(
                          color: AetherColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600))),
              SizedBox(
                  width: 50,
                  child: Text('PORT',
                      style: TextStyle(
                          color: AetherColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  child: Text('PROCESS',
                      style: TextStyle(
                          color: AetherColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600))),
              SizedBox(
                  width: 68,
                  child: Text('STATUS',
                      style: TextStyle(
                          color: AetherColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600))),
              SizedBox(width: 80), // actions
            ],
          ),
        ),

        // Port list
        Expanded(
          child: state.ports.isEmpty
              ? const Center(
                  child: Text('No listening ports detected',
                      style:
                          TextStyle(color: AetherColors.textSecondary)))
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: state.ports.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AetherColors.glassBorder, height: 1),
                  itemBuilder: (ctx, i) => _PortRow(
                    entry: state.ports[i],
                    notifier: notifier,
                    context: ctx,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Global Controls Bar ───────────────────────────────────────────────────────

class _GlobalBar extends StatelessWidget {
  const _GlobalBar({required this.state, required this.notifier});
  final FirewallState state;
  final FirewallNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final isActive = state.ufwEnabled == UfwEnabled.active;
    final isInactive = state.ufwEnabled == UfwEnabled.inactive;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AetherColors.accentGreen
                  : isInactive
                      ? AetherColors.accentRed
                      : AetherColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive
                ? 'UFW Active'
                : isInactive
                    ? 'UFW Inactive'
                    : 'UFW Unknown',
            style: TextStyle(
              color: isActive
                  ? AetherColors.accentGreen
                  : AetherColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _BarButton(
            label: 'Enable',
            color: AetherColors.accentGreen,
            onTap: isInactive ? () => notifier.enableUfw() : null,
          ),
          const SizedBox(width: 4),
          _BarButton(
            label: 'Disable',
            color: AetherColors.accentRed,
            onTap: isActive ? () => notifier.disableUfw() : null,
          ),
          const SizedBox(width: 4),
          _BarButton(
            label: 'Reload',
            color: AetherColors.accent,
            onTap: isActive ? () => notifier.reloadUfw() : null,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => notifier.refresh(),
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

class _BarButton extends StatelessWidget {
  const _BarButton(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: enabled ? color.withOpacity(0.4) : AetherColors.glassBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? color : AetherColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ── Quick Rules Row ───────────────────────────────────────────────────────────

class _QuickRulesRow extends StatelessWidget {
  const _QuickRulesRow(
      {required this.state, required this.notifier, required this.vpsId});
  final FirewallState state;
  final FirewallNotifier notifier;
  final String vpsId;

  UfwPortStatus _statusFor(int port) {
    for (final p in state.ports) {
      if (p.port == port) return p.ufwStatus;
    }
    // Port not listening but may have a rule
    for (final r in state.rules) {
      if (r.to.startsWith('$port/') || r.to == '$port') {
        return r.action == 'ALLOW' || r.action == 'LIMIT'
            ? UfwPortStatus.allowed
            : UfwPortStatus.denied;
      }
    }
    return UfwPortStatus.unknown;
  }

  int? _ruleNumberFor(int port) {
    for (final p in state.ports) {
      if (p.port == port && p.ufwRuleNumber != null) return p.ufwRuleNumber;
    }
    for (final r in state.rules) {
      if (r.to.startsWith('$port/') || r.to == '$port') return r.number;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          const Text('Quick: ',
              style: TextStyle(
                  color: AetherColors.textSecondary, fontSize: 11)),
          ..._quickRules.map((qr) {
            final status = _statusFor(qr.port);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _QuickChip(
                label: '${qr.label} ${qr.port}',
                status: status,
                onTap: () => _handleChipTap(
                    context, qr.port, qr.proto, status, _ruleNumberFor(qr.port)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _handleChipTap(BuildContext context, int port, String proto,
      UfwPortStatus status, int? ruleNumber) async {
    if (status == UfwPortStatus.unknown) {
      notifier.allowPort(port, proto);
    } else if (status == UfwPortStatus.allowed) {
      if (port == 22) {
        final ok = await _showSshWarning(context);
        if (ok != true) return;
      }
      if (ruleNumber != null) {
        notifier.deleteRule(ruleNumber);
      }
    } else if (status == UfwPortStatus.denied) {
      if (ruleNumber != null) {
        notifier.deleteRule(ruleNumber);
      }
    }
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip(
      {required this.label, required this.status, required this.onTap});
  final String label;
  final UfwPortStatus status;
  final VoidCallback onTap;

  Color get _dotColor => switch (status) {
        UfwPortStatus.allowed => AetherColors.accentGreen,
        UfwPortStatus.denied  => AetherColors.accentRed,
        UfwPortStatus.unknown => AetherColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AetherColors.glassBase,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AetherColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _dotColor),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: AetherColors.textPrimary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Port Row ──────────────────────────────────────────────────────────────────

class _PortRow extends StatelessWidget {
  const _PortRow(
      {required this.entry,
      required this.notifier,
      required this.context});
  final PortEntry entry;
  final FirewallNotifier notifier;
  final BuildContext context;

  Color get _dotColor => switch (entry.ufwStatus) {
        UfwPortStatus.allowed => AetherColors.accentGreen,
        UfwPortStatus.denied  => AetherColors.accentRed,
        UfwPortStatus.unknown => AetherColors.textSecondary,
      };

  String get _statusLabel => switch (entry.ufwStatus) {
        UfwPortStatus.allowed => 'ALLOWED',
        UfwPortStatus.denied  => 'DENIED',
        UfwPortStatus.unknown => '—',
      };

  Color get _statusColor => switch (entry.ufwStatus) {
        UfwPortStatus.allowed => AetherColors.accentGreen,
        UfwPortStatus.denied  => AetherColors.accentRed,
        UfwPortStatus.unknown => AetherColors.textSecondary,
      };

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: _dotColor),
          ),
          const SizedBox(width: 8),
          // Proto
          SizedBox(
            width: 38,
            child: Text(entry.proto,
                style: const TextStyle(
                    color: AetherColors.textSecondary, fontSize: 11)),
          ),
          // Port
          SizedBox(
            width: 50,
            child: Text(entry.port.toString(),
                style: const TextStyle(
                    color: AetherColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          // Process
          Expanded(
            child: Text(
              entry.process.isNotEmpty ? entry.process : '—',
              style: const TextStyle(
                  color: AetherColors.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status label
          SizedBox(
            width: 68,
            child: Text(_statusLabel,
                style: TextStyle(color: _statusColor, fontSize: 11)),
          ),
          // Actions
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActions(ctx),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext ctx) {
    switch (entry.ufwStatus) {
      case UfwPortStatus.allowed:
        return [
          _ActionButton(
            label: 'Deny',
            color: AetherColors.accentRed,
            onTap: () => _onDeny(ctx),
          ),
        ];
      case UfwPortStatus.denied:
        return [
          _ActionButton(
            label: 'Allow',
            color: AetherColors.accentGreen,
            onTap: () => notifier.allowPort(entry.port, entry.proto),
          ),
        ];
      case UfwPortStatus.unknown:
        return [
          _ActionButton(
            label: 'Allow',
            color: AetherColors.accentGreen,
            onTap: () => notifier.allowPort(entry.port, entry.proto),
          ),
          const SizedBox(width: 4),
          _ActionButton(
            label: 'Deny',
            color: AetherColors.accentRed,
            onTap: () => _onDeny(ctx),
          ),
        ];
    }
  }

  Future<void> _onDeny(BuildContext ctx) async {
    if (entry.port == 22) {
      final ok = await _showSshWarning(ctx);
      if (ok != true) return;
    }
    if (entry.ufwStatus == UfwPortStatus.allowed &&
        entry.ufwRuleNumber != null) {
      notifier.deleteRule(entry.ufwRuleNumber!);
    } else {
      notifier.denyPort(entry.port, entry.proto);
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.label, required this.color, required this.onTap});
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
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 10)),
      ),
    );
  }
}

// ── Safety dialog ─────────────────────────────────────────────────────────────

Future<bool?> _showSshWarning(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AetherColors.surfaceDeep,
        title: const Text('SSH Lock Warning',
            style: TextStyle(color: AetherColors.accentYellow)),
        content: const Text(
          'Blocking port 22 will disconnect your current SSH session '
          'and may lock you out permanently.\n\n'
          'Are you absolutely sure?',
          style: TextStyle(color: AetherColors.textSecondary),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AetherColors.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block Anyway',
                style: TextStyle(color: AetherColors.accentRed)),
          ),
        ],
      ),
    );
