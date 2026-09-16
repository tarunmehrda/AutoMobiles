import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/pressable.dart';
import '../../state/admin_state.dart';

class _Slide {
  const _Slide(this.eyebrow, this.title, this.body, this.icon);
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
}

const _slides = [
  _Slide(
    'Job cards',
    'Open a card in under a minute',
    'Registration, complaint, accessories and the promised time. Every card '
        'gets its own number the moment it opens.',
    Icons.description_rounded,
  ),
  _Slide(
    'Billing',
    'Jobs, spares and lubes in one bill',
    'Add labour and parts as the work happens. The estimate, the invoice and '
        'the mechanic copy all read from the same list.',
    Icons.receipt_long_rounded,
  ),
  _Slide(
    'Follow up',
    'Nobody slips through',
    'Pending balances stay visible, service reminders go out on schedule, and '
        'every closed card keeps its history against the vehicle.',
    Icons.notifications_active_rounded,
  ),
];

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    ref.read(adminProvider.notifier).completeOnboarding();
    context.go('/login');
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _done();
      return;
    }
    _controller.nextPage(duration: Motion.base, curve: Motion.enter);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final last = _index == _slides.length - 1;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, Gap.sm, Gap.md, 0),
                child: Pressable(
                  onTap: _done,
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.md),
                    child: Text('Skip', style: AppType.labelM.c(p.inkMuted)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.lg, Gap.page, Gap.xxl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++) ...[
                        AnimatedContainer(
                          duration: Motion.base,
                          curve: Motion.spring,
                          height: 6,
                          width: i == _index ? 26 : 6,
                          decoration: BoxDecoration(
                            color: i == _index ? p.accent : p.line,
                            borderRadius: R.all(R.pill),
                          ),
                        ),
                        if (i != _slides.length - 1)
                          const SizedBox(width: Gap.sm),
                      ],
                    ],
                  ),
                  const SizedBox(height: Gap.xxl),
                  GButton.accent(
                    label: last ? 'Get started' : 'Next',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Entrance(
            scaleFrom: 0.9,
            child: Container(
              height: 132,
              width: 132,
              decoration: BoxDecoration(
                gradient: p.inverseGradient,
                borderRadius: R.all(R.xxl),
                boxShadow: Shadows.lifted(p),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: R.all(R.xxl),
                      child: CustomPaint(
                        painter: BlueprintPainter(
                            color: p.onInverse, opacity: 0.08),
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(slide.icon, size: 54, color: p.volt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.h2),
          Entrance(
            index: 1,
            child: Text(slide.eyebrow.toUpperCase(),
                style: AppType.over.c(p.accentInk)),
          ),
          const SizedBox(height: Gap.sm),
          Entrance(
            index: 2,
            child: Text(slide.title, style: AppType.d1.c(p.ink)),
          ),
          const SizedBox(height: Gap.md),
          Entrance(
            index: 3,
            child: Text(slide.body, style: AppType.bodyL.c(p.inkMuted)),
          ),
        ],
      ),
    );
  }
}
