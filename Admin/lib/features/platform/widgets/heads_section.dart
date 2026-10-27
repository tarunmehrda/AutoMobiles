import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/g_state.dart';
import '../../../data/repo/platform_gateway.dart';

/// The partner heads — the Gmail accounts that run this platform section —
/// each with a switch. A head that is off sees their own workshop and
/// nothing of the platform until another head switches them back on.
///
/// A head can add another by Gmail address (33_add_partner_head.sql); the
/// new head is on from the start. Nobody is removed from here: a head added
/// by mistake is switched off. The database keeps at least one head on, so
/// the platform cannot lock itself out.
class HeadsSection extends ConsumerStatefulWidget {
  const HeadsSection({super.key});

  @override
  ConsumerState<HeadsSection> createState() => _HeadsSectionState();
}

class _HeadsSectionState extends ConsumerState<HeadsSection> {
  List<PlatformHead>? _heads;
  bool _loading = true;
  String? _busy;
  final _email = TextEditingController();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
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

  Future<void> _add() async {
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty) return;
    final go = await GFeedback.confirm(
      context,
      icon: Icons.admin_panel_settings_outlined,
      title: 'Make $email a partner head?',
      message: 'Once they sign in to this app with that address they see '
          'every partner, request, listing and commission, and can add '
          'heads of their own.',
      confirmLabel: 'Add head',
    );
    if (!go || !mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _adding = true);
    final error = await ref.read(platformGatewayProvider).addHead(email);
    if (!mounted) return;
    setState(() => _adding = false);
    if (error != null) {
      GFeedback.error(context, error);
      return;
    }
    _email.clear();
    GFeedback.success(context, '$email is now a partner head');
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
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: const GEmptyState(
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
          const SizedBox(height: Gap.xl),
          Text('Add a head', style: AppType.labelM.c(p.ink)),
          const SizedBox(height: Gap.sm),
          GField(
            hint: 'name@gmail.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_adding) _add();
            },
          ),
          const SizedBox(height: Gap.md),
          GButton(
            label: 'Add head',
            icon: Icons.person_add_alt_1_rounded,
            loading: _adding,
            onPressed: _adding ? null : _add,
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'They become a head the moment they sign in to this app with '
            'that address.',
            style: AppType.bodyS.c(p.inkMuted),
          ),
        ],
      ),
    );
  }
}
