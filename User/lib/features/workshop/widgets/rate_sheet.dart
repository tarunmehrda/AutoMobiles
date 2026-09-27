import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/workshop.dart';
import '../../../state/app_state.dart';
import '../../../state/providers.dart';

/// "Rate this service" under a closed job card, or "You rated 4★ — change"
/// once the customer has.
///
/// It reads the card back out of the store by id rather than trusting the
/// one it was handed: the booking details sheet holds a copy from when it
/// opened, and without the lookup the label would still invite a first
/// rating after the refresh that `reviewCard` does had brought the new one
/// in. Nothing at all for a card that is not closed — the workshop cannot
/// take a rating before then, and the button would only lead to a refusal.
class RateButton extends ConsumerWidget {
  const RateButton({super.key, required this.card});

  final WorkshopCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(workshopCardProvider(card.id)) ?? card;
    if (!live.isClosed) return const SizedBox.shrink();
    final stars = live.myStars;
    return GButton(
      label: stars == null ? 'Rate this service' : 'You rated $stars★ — change',
      icon: stars == null ? Icons.star_outline_rounded : Icons.star_rounded,
      kind: GButtonKind.outline,
      size: GButtonSize.md,
      onPressed: () => showRateSheet(context, ref, live),
    );
  }
}

/// Stars and an optional comment for a finished job card, sent through
/// `reviewCard` to the workshop's Feedback screen.
///
/// Everything that happens after Submit is said inside the sheet — the
/// spinner, a refusal, and the thank-you. It is opened over the booking
/// details sheet as well as over a page, and a toast from there renders
/// behind both sheets where nobody sees it.
///
/// True when a rating was saved.
Future<bool> showRateSheet(
  BuildContext context,
  WidgetRef ref,
  WorkshopCard card,
) async {
  final saved = await GFeedback.sheet<bool>(
    context,
    title: card.myStars == null ? 'Rate this service' : 'Change your rating',
    subtitle: [
      if (card.garageName.isNotEmpty) card.garageName,
      '#${card.number}',
    ].join('  •  '),
    child: _RateSheet(
      card: card,
      submit: (stars, comment) => ref
          .read(appControllerProvider.notifier)
          .reviewCard(card, stars: stars, comment: comment),
    ),
  );
  return saved ?? false;
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.card, required this.submit});

  final WorkshopCard card;

  /// `reviewCard`, bound to the card. Null back means it was saved.
  final Future<String?> Function(int stars, String comment) submit;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  static const _words = ['Poor', 'Below par', 'Okay', 'Good', 'Excellent'];

  late int _stars = (widget.card.myStars ?? 5).clamp(1, 5);
  late final _comment = TextEditingController(text: widget.card.myComment);
  bool _saving = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.submit(_stars, _comment.text.trim());
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
      _done = error == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;

    if (_done) {
      return Padding(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, Gap.h1 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.check_circle_rounded, size: 48, color: p.success),
            const SizedBox(height: Gap.md),
            Text('Thanks for rating',
                textAlign: TextAlign.center, style: AppType.h1.c(p.ink)),
            const SizedBox(height: Gap.xs),
            Text(
              'The workshop sees your $_stars★ in their feedback.',
              textAlign: TextAlign.center,
              style: AppType.bodyM.c(p.inkMuted),
            ),
            const SizedBox(height: Gap.xl),
            GButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                Pressable(
                  onTap: _saving ? null : () => setState(() => _stars = i),
                  scale: 0.85,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
                    child: Icon(
                      i <= _stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 42,
                      color: i <= _stars ? p.warning : p.inkFaint,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(_words[_stars - 1],
              textAlign: TextAlign.center,
              style: AppType.labelM.c(p.inkMuted)),
          const SizedBox(height: Gap.xl),
          GField(
            label: 'Comment (optional)',
            hint: 'What went well, or what could be better?',
            controller: _comment,
            maxLines: 4,
            maxLength: 500,
            enabled: !_saving,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: Gap.md),
            Text(_error!, style: AppType.bodyS.c(p.danger)),
          ],
          const SizedBox(height: Gap.xl),
          GButton.accent(
            label: 'Submit',
            icon: Icons.send_rounded,
            loading: _saving,
            onPressed: _saving ? null : _send,
          ),
        ],
      ),
    );
  }
}
