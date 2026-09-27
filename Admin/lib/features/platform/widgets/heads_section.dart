import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_state.dart';
import '../../../data/repo/platform_gateway.dart';

/// The partner heads — the Gmail accounts that run this platform section —
/// each with a switch. A head that is off sees their own workshop and
/// nothing of the platform until another head switches them back on.
///
/// Who is on the list is set in the SQL editor (27_partner_heads.sql) and
/// nowhere else; this screen only turns them on and off. The database keeps
/// at least one head on, so the platform cannot lock itself out.
class HeadsSection extends ConsumerStatefulWidget {
  const HeadsSection({super.key});

  @override
  ConsumerState<HeadsSection> createState() => _HeadsSectionState();
}

class _HeadsSectionState extends ConsumerState<HeadsSection> {
  List<PlatformHead>? _heads;
  bool _loading = true;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final heads = await ref.read(platformGatewayProvider).heads();
    if (!mounted) return;
    setState(() {
      _heads = heads ?? _heads;
      _loading = false;
    });
  }

  Future<void> _toggle(PlatformHead h, bool on) async {
    if (h.me && !on) {
      final go = await GFeedback.confirm(
        context,
        icon: Icons.admin_panel_settings_outlined,
        title: 'Switch yourself off?',
        message: 'You will lose the platform section straight away. Only '
            'another partner head can switch you back on.',
        confirmLabel: 'Switch off',
      );
      if (!go || !mounted) return;
    }
    setState(() => _busy = h.email);
    final error = await ref.read(platformGatewayProvider).setHead(h.email, on);
    if (!mounted) return;
    setState(() => _busy = null);
    if (error != null) {
      GFeedback.error(context, error);
      return;
    }
    if (h.me && !on) {
      ref.invalidate(isPlatformAdminProvider);
      context.canPop() ? context.pop() : context.go('/home');
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final heads = _heads;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(Gap.page),
        child: GSkeleton(height: 140),
      );
    }
    if (heads == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 320,
            child: GEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load the partner heads',
              message: 'Pull down to try again.',
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: p.accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.sm,
            ),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: R.rLg,
              border: Border.all(color: p.line),
            ),
            child: Column(
              children: [
                for (final h in heads)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.bodyM.c(p.ink),
                            ),
                            Text(
                              [
                                h.enabled ? 'On' : 'Off',
                                if (h.me) 'You',
                              ].join(' • '),
                              style: AppType.bodyS.c(
                                h.enabled ? p.success : p.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: h.enabled,
                        onChanged:
                            _busy == null ? (v) => _toggle(h, v) : null,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          Text(
            'A partner head sees every partner, request, listing and '
            'commission. Switched off, they keep their own workshop and lose '
            'only this section. At least one head always stays on.',
            style: AppType.bodyS.c(p.inkMuted),
          ),
        ],
      ),
    );
  }
}
