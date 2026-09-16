import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final _comment = TextEditingController();
  double _overall = 0;
  final Map<String, double> _aspects = {};
  final Set<String> _tags = {};
  bool _saving = false;

  static const _aspectNames = [
    ('Service quality', Icons.build_circle_rounded),
    ('Staff behaviour', Icons.people_alt_rounded),
    ('Timeliness', Icons.schedule_rounded),
    ('Transparency', Icons.visibility_rounded),
    ('Pickup & drop', Icons.local_shipping_rounded),
  ];

  static const _goodTags = [
    'On time',
    'Fair pricing',
    'Clear estimate',
    'Car came back clean',
    'Polite staff',
    'Good communication',
  ];

  static const _badTags = [
    'Took longer than promised',
    'Price higher than quoted',
    'Poor communication',
    'Work not complete',
    'Car not cleaned',
  ];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_overall == 0) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final note = [
      if (_tags.isNotEmpty) _tags.join(', '),
      if (_comment.text.trim().isNotEmpty) _comment.text.trim(),
    ].join(' — ');

    ref.read(appControllerProvider.notifier).rateBooking(
          widget.bookingId,
          _overall,
          note.isEmpty ? null : note,
        );
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _saving = false);
    GFeedback.success(context, 'Thanks — your feedback reached the workshop');
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final booking = ref.watch(bookingProvider(widget.bookingId));
    if (booking == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Rate service'),
        body: const GEmptyState(
          icon: Icons.star_outline_rounded,
          title: 'Booking not found',
          message: 'We could not load this service.',
        ),
      );
    }

    final tags = _overall >= 4 ? _goodTags : _badTags;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'How did we do?',
        subtitle: booking.code,
        actions: [
          GButton.ghost(
            label: 'Skip',
            size: GButtonSize.sm,
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          Entrance(
            child: Column(
              children: [
                const SizedBox(height: Gap.md),
                _Stars(
                  value: _overall,
                  size: 44,
                  onChanged: (v) => setState(() => _overall = v),
                ),
                const SizedBox(height: Gap.md),
                GSwap(
                  child: Text(
                    key: ValueKey(_overall),
                    switch (_overall) {
                      0 => 'Tap a star to rate',
                      1 => 'We let you down',
                      2 => 'Below expectations',
                      3 => 'It was okay',
                      4 => 'Good experience',
                      _ => 'Excellent, thank you!',
                    },
                    style: AppType.h1.c(_overall == 0 ? p.inkMuted : p.ink),
                  ),
                ),
              ],
            ),
          ),

          if (_overall > 0) ...[
            const SizedBox(height: Gap.h1),
            Entrance(
              key: const ValueKey('aspects'),
              child: Text('Rate the details', style: AppType.h1.c(p.ink)),
            ),
            const SizedBox(height: Gap.md),
            for (var i = 0; i < _aspectNames.length; i++)
              if (_aspectNames[i].$1 != 'Pickup & drop' ||
                  booking.mode == ServiceMode.pickup)
                Entrance(
                  index: i,
                  stagger: const Duration(milliseconds: 40),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Gap.md),
                    child: Row(
                      children: [
                        Icon(_aspectNames[i].$2, size: 18, color: p.inkMuted),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(_aspectNames[i].$1,
                              style: AppType.labelM.c(p.ink)),
                        ),
                        _Stars(
                          value: _aspects[_aspectNames[i].$1] ?? 0,
                          size: 20,
                          onChanged: (v) => setState(
                              () => _aspects[_aspectNames[i].$1] = v),
                        ),
                      ],
                    ),
                  ),
                ),

            const SizedBox(height: Gap.xl),
            Text(
              _overall >= 4 ? 'What went well?' : 'What went wrong?',
              style: AppType.h1.c(p.ink),
            ),
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final t in tags)
                  Pressable(
                    onTap: () => setState(() {
                      if (!_tags.remove(t)) _tags.add(t);
                    }),
                    scale: 0.94,
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      padding: const EdgeInsets.symmetric(
                          horizontal: Gap.lg, vertical: Gap.md),
                      decoration: BoxDecoration(
                        color: _tags.contains(t) ? p.ink : p.surface,
                        borderRadius: R.all(R.pill),
                        border: Border.all(
                            color: _tags.contains(t) ? p.ink : p.line),
                      ),
                      child: Text(
                        t,
                        style: AppType.labelM.c(_tags.contains(t)
                            ? (p.isDark ? p.canvas : Colors.white)
                            : p.inkSoft),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: Gap.xl),
            GField(
              label: 'Anything else? (optional)',
              hint: 'Your words go straight to the workshop manager',
              controller: _comment,
              maxLines: 4,
            ),
          ],
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: 'Submit feedback',
          loading: _saving,
          onPressed: _overall == 0 ? null : _submit,
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({
    required this.value,
    required this.onChanged,
    this.size = 32,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          Pressable(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(i.toDouble());
            },
            scale: 0.8,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.06),
              child: AnimatedScale(
                scale: value >= i ? 1.0 : 0.9,
                duration: Motion.fast,
                curve: Motion.spring,
                child: Icon(
                  value >= i ? Icons.star_rounded : Icons.star_border_rounded,
                  size: size,
                  color: value >= i ? const Color(0xFFFFB020) : p.line,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
