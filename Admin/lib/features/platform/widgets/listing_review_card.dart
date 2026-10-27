import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_net_image.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/repo/platform_gateway.dart';
import '../platform_page.dart' show toneForStatus;

/// A part listing awaiting approval.
///
/// Approve and Reject are only offered while there is a decision to make.
/// A listing already live, sold or withdrawn shows its state and nothing to
/// press — re-approving an approved listing is not a thing anybody needs.
class ListingReviewCard extends ConsumerStatefulWidget {
  const ListingReviewCard({
    super.key,
    required this.listing,
    required this.onChanged,
  });

  final PlatformListing listing;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<ListingReviewCard> createState() => _ListingReviewCardState();
}

class _ListingReviewCardState extends ConsumerState<ListingReviewCard> {
  bool _busy = false;

  Future<void> _decide(bool approve, {String note = ''}) async {
    setState(() => _busy = true);
    final error = await ref.read(platformGatewayProvider).decideListing(
          widget.listing.id,
          approve: approve,
          rejectNote: note,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      GFeedback.error(context, error);
      return;
    }
    await widget.onChanged();
  }

  /// A rejection the seller cannot act on is worse than no rejection at all,
  /// so the reason is asked for rather than optional.
  Future<void> _reject() async {
    final note = TextEditingController();
    final done = await GFeedback.sheet<bool>(
      context,
      title: 'Reject listing',
      subtitle: widget.listing.title,
      // Disposed by the sheet once its fields are gone, not by this await
      // while they are still animating out.
      disposing: [note],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: note,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Why',
                hintText: 'The seller sees this. Tell them what to fix.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Gap.xl),
            Builder(
              builder: (context) => FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reject'),
              ),
            ),
          ],
        ),
      ),
    );
    final text = note.text;
    if (done == true) await _decide(false, note: text);
  }

  bool get _decidable =>
      widget.listing.status == 'pending' ||
      widget.listing.status == 'rejected';

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final l = widget.listing;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.rLg,
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GNetImage(
                url: l.photos.isEmpty ? null : l.photos.first,
                fallbackIcon: Icons.settings_outlined,
                radius: R.sm,
                height: 64,
                width: 64,
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.title.isEmpty ? 'Untitled listing' : l.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelL.c(p.ink),
                    ),
                    const SizedBox(height: Gap.xxs),
                    Text(
                      [
                        if (l.vehicleText.isNotEmpty) l.vehicleText,
                        if (l.city.isNotEmpty) l.city,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                    const SizedBox(height: Gap.sm),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(Fmt.money(l.price),
                            style: AppType.money.c(p.ink)),
                        GPill(
                            label: l.condition,
                            tone: GTone.neutral,
                            compact: true),
                        GPill(
                          label: l.status,
                          tone: toneForStatus(l.status),
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (l.detail.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Text(l.detail, style: AppType.bodyS.c(p.inkSoft)),
          ],

          if (l.partNo.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text('Part no. ${l.partNo}',
                style: AppType.labelS.c(p.inkMuted)),
          ],

          if (l.status == 'rejected' && l.rejectNote.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: p.dangerSoft,
                borderRadius: R.rMd,
              ),
              child: Text(l.rejectNote, style: AppType.bodyS.c(p.danger)),
            ),
          ],

          if (_decidable) ...[
            const Divider(height: Gap.xxl),
            Row(
              children: [
                Expanded(
                  child: _Action(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    tone: p.success,
                    filled: true,
                    enabled: !_busy,
                    onTap: () => _decide(true),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: _Action(
                    label: 'Reject',
                    icon: Icons.close_rounded,
                    tone: p.danger,
                    filled: false,
                    enabled: !_busy && l.status != 'rejected',
                    onTap: _reject,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.tone,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tone;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      enabled: enabled,
      onTap: onTap,
      scale: 0.97,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? tone : p.surface,
            borderRadius: R.rMd,
            border: Border.all(color: filled ? tone : p.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: filled ? Colors.white : tone),
              const SizedBox(width: Gap.sm),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelM.c(filled ? Colors.white : tone)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
