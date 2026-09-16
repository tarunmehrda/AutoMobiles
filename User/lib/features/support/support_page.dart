import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/providers.dart';

class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final live = ref.watch(spotlightBookingProvider);
    final tickets = ref.watch(ticketsProvider);
    final chat = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: CustomScrollView(
        slivers: [
          const GSliverHeader(
            eyebrow: 'We are here',
            title: 'Support',
            subtitle: 'Real people at the workshop, not a call centre',
          ),

          // --- quick contact --------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
              child: Entrance(
                index: 0,
                child: Row(
                  children: [
                    Expanded(
                      child: _ContactTile(
                        icon: Icons.call_rounded,
                        label: 'Call',
                        sub: 'Instant',
                        color: p.success,
                        onTap: () => _launch('tel:${Seed.garage.phone}'),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _ContactTile(
                        icon: Icons.chat_rounded,
                        label: 'WhatsApp',
                        sub: 'Share photos',
                        color: const Color(0xFF25D366),
                        onTap: () =>
                            _launch('https://wa.me/${Seed.garage.whatsapp}'),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _ContactTile(
                        icon: Icons.forum_rounded,
                        label: 'Chat',
                        sub: chat.isEmpty ? 'Start' : '${chat.length} messages',
                        color: p.info,
                        onTap: () => context.push('/chat'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- live booking ----------------------------------------------
          if (live != null)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
                child: Entrance(
                  index: 1,
                  child: GCard(
                    onTap: () => context.push('/booking/${live.id}'),
                    child: Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: p.accentSoft,
                            borderRadius: R.all(R.sm),
                          ),
                          child: Icon(live.stage.icon,
                              size: 20, color: p.accentInk),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Question about ${live.code}?',
                                  style: AppType.labelL.c(p.ink)),
                              Text(live.stage.label,
                                  style: AppType.bodyS.c(p.inkMuted)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.inkFaint),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // --- help topics ------------------------------------------------
          SliverToBoxAdapter(
            child: GSectionHeader(
              eyebrow: 'Answers',
              title: 'Common questions',
              actionLabel: 'All FAQs',
              onAction: () => context.push('/help'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            sliver: SliverList.separated(
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
              itemBuilder: (context, i) => Entrance(
                index: i,
                stagger: const Duration(milliseconds: 40),
                child: GCard(
                  padding: const EdgeInsets.all(Gap.md),
                  onTap: () => context.push('/help'),
                  child: Row(
                    children: [
                      Icon(Icons.help_outline_rounded,
                          size: 18, color: p.inkMuted),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(Seed.faqs[i].question,
                            style: AppType.labelM.c(p.ink)),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: p.inkFaint),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- tickets ------------------------------------------------------
          SliverToBoxAdapter(
            child: GSectionHeader(
              eyebrow: 'Still stuck?',
              title: 'Complaints & tickets',
              actionLabel: tickets.isEmpty ? null : '${tickets.length} open',
              onAction: () => context.push('/tickets'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
              child: GTileGroup(
                children: [
                  GTile(
                    title: 'Raise a complaint',
                    subtitle: 'Billing, quality, delay or behaviour',
                    icon: Icons.report_gmailerrorred_rounded,
                    iconBg: p.dangerSoft,
                    iconColor: p.danger,
                    onTap: () => context.push('/tickets'),
                  ),
                  GTile(
                    title: 'My tickets',
                    subtitle: tickets.isEmpty
                        ? 'You have not raised any yet'
                        : '${tickets.length} raised',
                    icon: Icons.confirmation_number_outlined,
                    onTap: () => context.push('/tickets'),
                  ),
                  GTile(
                    title: 'Help centre',
                    subtitle: 'Guides on booking, estimates and payments',
                    icon: Icons.menu_book_rounded,
                    onTap: () => context.push('/help'),
                  ),
                ],
              ),
            ),
          ),

          // --- garage -------------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h3),
              child: GCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store_mall_directory_rounded,
                            size: 18, color: p.inkMuted),
                        const SizedBox(width: Gap.sm),
                        Text(Seed.garage.name,
                            style: AppType.labelL.c(p.ink)),
                      ],
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(Seed.garage.address,
                        style: AppType.bodyS.c(p.inkMuted)),
                    const SizedBox(height: 4),
                    Text(Seed.garage.openHours,
                        style: AppType.bodyS.c(p.inkMuted)),
                    const SizedBox(height: Gap.md),
                    Row(
                      children: [
                        const GPill(
                            label: 'GST registered', tone: GTone.neutral),
                        const SizedBox(width: Gap.sm),
                        GPill(
                            label: '${Seed.garage.rating} ★',
                            tone: GTone.success),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Column(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: R.all(R.sm),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: Gap.sm),
            Text(label, style: AppType.labelM.c(p.ink)),
            Text(sub,
                style: AppType.labelS.s(10).c(p.inkFaint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
