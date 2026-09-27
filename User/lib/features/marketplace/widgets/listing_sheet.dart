import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_image.dart';
import '../../../data/models/marketplace.dart';
import '../../../data/repo/marketplace_gateway.dart';

/// One listing in full, from the browse list, with the one thing a buyer
/// can do about it: ask.
///
/// Tapping a listing used to do nothing, so a buyer saw a price and a
/// thumbnail and had no way to find out more or to act on it. "Ask about
/// this part" files an ordinary part request with the listing written into
/// it — addressed to the selling workshop when the listing says which one —
/// and the answer comes back as a quote under Wanted like any other.
///
/// True when a request was sent, so the page can reload its lists.
Future<bool> showListingSheet(
  BuildContext context,
  WidgetRef ref,
  PartListing listing,
) async {
  final sent = await GFeedback.sheet<bool>(
    context,
    title: listing.title.isEmpty ? 'Part for sale' : listing.title,
    subtitle: [
      if (listing.vehicleText.isNotEmpty) listing.vehicleText,
      if (listing.city.isNotEmpty) listing.city,
    ].join('  •  '),
    child: _ListingSheet(
      listing: listing,
      ask: () => ref.read(marketplaceGatewayProvider).createRequest(
            partName: listing.title,
            detail: 'About listing: ${listing.title} — '
                '${Fmt.money(listing.price)} (${listing.condition.label})\n'
                'Listing ID: ${listing.id}',
            vehicleText: listing.vehicleText,
            garageId: listing.garageId,
          ),
    ),
  );
  if (sent != true || !context.mounted) return false;
  GFeedback.success(context, "Sent — you'll get a quote under Wanted");
  return true;
}

class _ListingSheet extends StatefulWidget {
  const _ListingSheet({required this.listing, required this.ask});

  final PartListing listing;

  /// `createRequest`, already filled in from the listing.
  final Future<({String code, int photosFailed})?> Function() ask;

  @override
  State<_ListingSheet> createState() => _ListingSheetState();
}

class _ListingSheetState extends State<_ListingSheet> {
  bool _sending = false;
  String? _error;

  Future<void> _ask() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final sent = await widget.ask();
    if (!mounted) return;
    if (sent == null) {
      // Said here: a toast would render behind this sheet.
      setState(() {
        _sending = false;
        _error = 'Could not send that. Check your connection and try again.';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final l = widget.listing;
    final facts = <(String, String)>[
      ('Condition', l.condition.label),
      if (l.partNo.isNotEmpty) ('Part no.', l.partNo),
      if (l.vehicleText.isNotEmpty) ('Fits', l.vehicleText),
      if (l.city.isNotEmpty) ('City', l.city),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page,
          Gap.h1 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: l.photos.isEmpty
                ? const GImage(url: null, fallbackIcon: Icons.settings_outlined)
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: l.photos.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: Gap.sm),
                    itemBuilder: (context, i) => AspectRatio(
                      aspectRatio: l.photos.length == 1 ? 16 / 9 : 1,
                      child: GImage(
                        url: l.photos[i],
                        fallbackIcon: Icons.settings_outlined,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: Text(Fmt.money(l.price),
                    style: AppType.moneyL.c(p.ink)),
              ),
              GPill(label: l.condition.label, tone: GTone.neutral),
            ],
          ),
          const SizedBox(height: Gap.md),
          for (final f in facts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(f.$1, style: AppType.bodyM.c(p.inkMuted)),
                  ),
                  Flexible(
                    flex: 2,
                    child: Text(f.$2,
                        textAlign: TextAlign.right,
                        style: AppType.labelL.c(p.ink)),
                  ),
                ],
              ),
            ),
          if (l.detail.trim().isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Text(l.detail.trim(), style: AppType.bodyM.c(p.inkSoft)),
          ],
          if (_error != null) ...[
            const SizedBox(height: Gap.lg),
            Text(_error!, style: AppType.bodyS.c(p.danger)),
          ],
          const SizedBox(height: Gap.xl),
          GButton.accent(
            label: 'Ask about this part',
            icon: Icons.chat_bubble_outline_rounded,
            loading: _sending,
            onPressed: _sending ? null : _ask,
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Asking does not commit you to buying it.',
            textAlign: TextAlign.center,
            style: AppType.bodyS.c(p.inkFaint),
          ),
        ],
      ),
    );
  }
}
