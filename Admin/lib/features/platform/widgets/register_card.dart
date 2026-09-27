import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/repo/platform_gateway.dart';

/// One partner in the register, with what only the platform holds:
/// listed, verified, and blocked.
///
/// The commission rate used to be a third row here. It moved to
/// Settings → Commission, beside what each partner owes, so that the partner list
/// is about who is on the register and the rate is set in exactly one place.
class RegisterCard extends ConsumerStatefulWidget {
  const RegisterCard({
    super.key,
    required this.garage,
    required this.onChanged,
  });

  final RegisteredGarage garage;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<RegisterCard> createState() => _RegisterCardState();
}

class _RegisterCardState extends ConsumerState<RegisterCard> {
  bool _busy = false;

  Future<void> _set({bool? listed, bool? verified, bool? blocked}) async {
    setState(() => _busy = true);
    final error = await ref.read(platformGatewayProvider).setListing(
          widget.garage.id,
          listed: listed,
          verified: verified,
          blocked: blocked,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      GFeedback.error(context, error);
      return;
    }
    await widget.onChanged();
  }

  /// Listing a workshop that has never said where it is puts a row in the
  /// customer's search that can never carry a distance. Worth a question
  /// rather than a silent yes.
  Future<void> _toggleListed(bool next) async {
    final g = widget.garage;
    if (next && !g.located) {
      final go = await GFeedback.confirm(
        context,
        title: 'List without a location?',
        message: '${g.name} has not set its coordinates. It will show up in '
            'searches by name, but never in "within 5 km". Ask them to set '
            'their location from the customer app first.',
        confirmLabel: 'List anyway',
      );
      if (!go) return;
    }
    await _set(listed: next);
  }

  /// Blocking takes a workshop out of customer search at once, so it is
  /// asked about. Unblocking does not re-list it; that stays a choice.
  Future<void> _toggleBlocked() async {
    final g = widget.garage;
    if (!g.blocked) {
      final go = await GFeedback.confirm(
        context,
        title: 'Block ${g.name.isEmpty ? 'this workshop' : g.name}?',
        message: 'It leaves customer search straight away and cannot be '
            'listed until you unblock it. Its staff keep their console and '
            'their job cards.',
        confirmLabel: 'Block',
        destructive: true,
        icon: Icons.block_rounded,
      );
      if (!go) return;
    }
    await _set(blocked: !g.blocked);
  }

  Future<void> _call() async {
    final uri = Uri.parse('tel:${widget.garage.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final g = widget.garage;

    return AnimatedContainer(
      duration: Motion.fast,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.rLg,
        border: Border.all(
          color: g.blocked ? p.accent : p.line,
          width: g.blocked ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            g.name.isEmpty ? 'Unnamed workshop' : g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.h3.c(p.ink),
                          ),
                        ),
                        if (g.verified) ...[
                          const SizedBox(width: Gap.xs),
                          Icon(Icons.verified_rounded,
                              size: 15, color: p.accentInk),
                        ],
                      ],
                    ),
                    const SizedBox(height: Gap.xxs),
                    Text(
                      [
                        if (g.owner.isNotEmpty) g.owner,
                        if (g.where.isNotEmpty) g.where,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                  ],
                ),
              ),
              if (g.phone.isNotEmpty)
                Pressable(
                  onTap: _call,
                  scale: 0.9,
                  child: Container(
                    height: 34,
                    width: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.surfaceSunken,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.line),
                    ),
                    child: Icon(Icons.call_rounded, size: 16, color: p.ink),
                  ),
                ),
            ],
          ),

          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              if (g.blocked)
                const GPill(
                  label: 'Blocked',
                  tone: GTone.danger,
                  compact: true,
                ),
              GPill(
                label: '${g.members} staff',
                tone: GTone.neutral,
                compact: true,
              ),
              GPill(
                label: '${g.cards} cards',
                tone: GTone.neutral,
                compact: true,
              ),
              GPill(
                label: g.located ? 'Located' : 'No location',
                tone: g.located ? GTone.success : GTone.warning,
                compact: true,
              ),
              // Registered before the PIN was required. Customers see a
              // listed workshop with no PIN beside its name, so chase these.
              if (!Fmt.isPin(g.pin))
                const GPill(
                  label: 'No PIN code',
                  tone: GTone.warning,
                  compact: true,
                ),
            ],
          ),

          const Divider(height: Gap.xxl),

          _Toggle(
            label: 'Listed in customer search',
            value: g.listed,
            busy: _busy,
            onChanged: _toggleListed,
          ),
          _Toggle(
            label: 'Verified',
            value: g.verified,
            busy: _busy,
            onChanged: (v) => _set(verified: v),
          ),
          const SizedBox(height: Gap.xs),
          _BlockRow(
            blocked: g.blocked,
            busy: _busy,
            onTap: _toggleBlocked,
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
      children: [
        Expanded(child: Text(label, style: AppType.bodyM.c(p.ink))),
        Switch.adaptive(
          value: value,
          onChanged: busy ? null : onChanged,
        ),
      ],
    );
  }
}

/// Block / Unblock. While blocked the whole row turns orange, so a blocked
/// partner reads as blocked from across the room, not by a small switch.
class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.blocked,
    required this.busy,
    required this.onTap,
  });

  final bool blocked;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final fg = blocked ? p.onAccent : p.ink;
    return AnimatedContainer(
      duration: Motion.fast,
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
      decoration: BoxDecoration(
        color: blocked ? p.accent : p.surfaceSunken,
        borderRadius: R.rMd,
        border: Border.all(color: blocked ? p.accent : p.line),
      ),
      child: Row(
        children: [
          Icon(
            blocked ? Icons.block_rounded : Icons.shield_outlined,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blocked ? 'Blocked' : 'Active',
                  style: AppType.labelM.c(fg),
                ),
                Text(
                  blocked
                      ? 'Hidden from customers. Unblock to allow listing.'
                      : 'Blocking hides it from customers.',
                  style: AppType.bodyS.c(
                    blocked ? p.onAccent.withValues(alpha: 0.85) : p.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Pressable(
            onTap: busy ? null : onTap,
            scale: 0.95,
            child: AnimatedContainer(
              duration: Motion.fast,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: blocked ? p.onAccent : p.surface,
                borderRadius: R.all(R.pill),
                border: Border.all(color: blocked ? p.onAccent : p.danger),
              ),
              child: busy
                  ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: blocked ? p.accent : p.danger,
                      ),
                    )
                  : Text(
                      blocked ? 'Unblock' : 'Block',
                      style: AppType.labelM.c(blocked ? p.accent : p.danger),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
