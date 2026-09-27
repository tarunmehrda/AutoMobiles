import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/marketplace.dart';

/// One part for sale.
///
/// [showStatus] is the difference between the browse list and the seller's
/// own: a buyer has no business knowing a listing was rejected, and a seller
/// has no way of finding out otherwise.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    this.showStatus = false,
    this.onTap,
    this.footer,
  });

  final PartListing listing;
  final bool showStatus;
  final VoidCallback? onTap;

  /// Under everything else, inside the card — the seller's own actions on
  /// the Selling tab.
  final Widget? footer;

  GTone get _tone => switch (listing.status) {
        ListingStatus.approved => GTone.success,
        ListingStatus.pending => GTone.warning,
        ListingStatus.rejected => GTone.danger,
        ListingStatus.sold => GTone.info,
        ListingStatus.withdrawn => GTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final photo = listing.photos.isEmpty ? null : listing.photos.first;

    final card = Container(
      padding: const EdgeInsets.all(Gap.md),
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
              ClipRRect(
                borderRadius: R.rMd,
                child: SizedBox(
                  height: 72,
                  width: 72,
                  child: photo == null
                      ? Container(
                          color: p.surfaceSunken,
                          child: Icon(Icons.settings_outlined,
                              size: 24, color: p.inkFaint),
                        )
                      : CachedNetworkImage(
                          imageUrl: photo,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: p.surfaceSunken),
                          errorWidget: (_, _, _) => Container(
                            color: p.surfaceSunken,
                            child: Icon(Icons.broken_image_outlined,
                                size: 20, color: p.inkFaint),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelL.c(p.ink),
                    ),
                    if (listing.vehicleText.isNotEmpty) ...[
                      const SizedBox(height: Gap.xxs),
                      Text(
                        listing.vehicleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyS.c(p.inkMuted),
                      ),
                    ],
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        Text(Fmt.money(listing.price),
                            style: AppType.money.c(p.ink)),
                        const SizedBox(width: Gap.sm),
                        GPill(
                          label: listing.condition.label,
                          tone: GTone.neutral,
                          compact: true,
                        ),
                        if (showStatus) ...[
                          const SizedBox(width: Gap.xs),
                          GPill(
                            label: listing.status.label,
                            tone: _tone,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Why it was turned down. Only ever on the seller's own list, and
          // only when there is something to say — a rejection with no reason
          // is worse than no rejection notice at all.
          if (showStatus &&
              listing.status == ListingStatus.rejected &&
              listing.rejectNote.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: p.dangerSoft,
                borderRadius: R.rMd,
              ),
              child: Text(listing.rejectNote,
                  style: AppType.bodyS.c(p.danger)),
            ),
          ],

          if (listing.city.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: p.inkFaint),
                const SizedBox(width: Gap.xs),
                Text(listing.city, style: AppType.labelS.c(p.inkFaint)),
              ],
            ),
          ],

          if (footer != null) ...[
            const SizedBox(height: Gap.md),
            footer!,
          ],
        ],
      ),
    );
    // [onTap] was declared and never wired, so tapping a listing did
    // nothing at all.
    if (onTap == null) return card;
    return Pressable(onTap: onTap, scale: 0.985, child: card);
  }
}
