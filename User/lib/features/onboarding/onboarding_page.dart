import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_button.dart';
import '../../state/app_state.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = [
    (
      eyebrow: 'Book',
      title: 'Every service,\none tap away',
      body:
          'Real prices, real slots and a live estimate of how long it takes. '
          'No phone calls, no waiting for a callback.',
    ),
    (
      eyebrow: 'Track',
      title: 'Watch the work,\nnot the clock',
      body:
          'Photos from the ramp, the technician on the job and a timeline that '
          'updates the moment something changes.',
    ),
    (
      eyebrow: 'Approve',
      title: 'Nothing is repaired\nuntil you say yes',
      body:
          'Every extra job is quoted first, with parts and labour split out. '
          'Approve what you want, skip the rest.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: Motion.base, curve: Motion.emphasized);
    }
  }

  void _finish() {
    ref.read(appControllerProvider.notifier).completeOnboarding();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.lg, 0),
              child: Row(
                children: [
                  const Spacer(),
                  if (_index < _slides.length - 1)
                    GButton.ghost(
                      label: 'Skip',
                      size: GButtonSize.sm,
                      onPressed: _finish,
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                    // The words take the height they need and the picture
                    // gets whatever is left. It used to be the other way
                    // round -- a fixed share for each -- and a large system
                    // font pushed the copy off the bottom of a short phone.
                    child: Column(
                      children: [
                        const SizedBox(height: Gap.xl),
                        Expanded(
                          child: Center(
                            // A mock of the app's own screens, drawn at one
                            // size and scaled down to fit. It is decoration,
                            // so the device font size is not applied to it.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: MediaQuery.withNoTextScaling(
                                child: SizedBox(
                                  width: 340,
                                  child: _Illustration(index: i),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Gap.xl),
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Entrance(
                                key: ValueKey('eyebrow$i'),
                                child: Text(s.eyebrow.toUpperCase(),
                                    style: AppType.over.c(p.accentInk)),
                              ),
                              const SizedBox(height: Gap.md),
                              Entrance(
                                key: ValueKey('title$i'),
                                index: 1,
                                child: Text(s.title, style: AppType.d1.c(p.ink)),
                              ),
                              const SizedBox(height: Gap.md),
                              Entrance(
                                key: ValueKey('body$i'),
                                index: 2,
                                child: Text(s.body,
                                    style: AppType.bodyL.c(p.inkMuted)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.lg, Gap.page, Gap.xxl),
              child: Row(
                children: [
                  _Dots(count: _slides.length, index: _index),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: GButton.accent(
                      label: _index == _slides.length - 1
                          ? 'Get started'
                          : 'Next',
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: _next,
                    ),
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

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          AnimatedContainer(
            duration: Motion.base,
            curve: Motion.spring,
            height: 6,
            width: i == index ? 26 : 6,
            decoration: BoxDecoration(
              color: i == index ? p.accent : p.line,
              borderRadius: R.all(R.pill),
            ),
          ),
          if (i != count - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

/// Hand-built previews of the real UI rather than stock artwork.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.clamp(0.0, 360.0);
        return SizedBox(
          width: w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: w * 0.82,
                width: w * 0.82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    p.accent.withValues(alpha: 0.14),
                    p.accent.withValues(alpha: 0.0),
                  ]),
                ),
              ),
              switch (index) {
                0 => _BookingPreview(width: w),
                1 => _TrackPreview(width: w),
                _ => _ApprovePreview(width: w),
              },
            ],
          ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.width, this.dark = false});

  final Widget child;
  final double width;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Entrance(
      scaleFrom: 0.94,
      duration: Motion.lazy,
      child: Container(
        width: width * 0.86,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: dark ? p.inverse : p.surface,
          borderRadius: R.all(R.xl),
          border: Border.all(color: dark ? Colors.transparent : p.line),
          boxShadow: Shadows.lifted(p),
        ),
        child: child,
      ),
    );
  }
}

class _BookingPreview extends StatelessWidget {
  const _BookingPreview({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return _Shell(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                    color: p.accentSoft, borderRadius: R.all(R.sm)),
                child: Icon(Icons.build_circle_rounded,
                    color: p.accentInk, size: 20),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Standard service', style: AppType.h3.c(p.ink)),
                    Text('15 services • 6 hrs',
                        style: AppType.labelS.c(p.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Text('₹3,032', style: AppType.moneyL.s(22).c(p.ink)),
              const SizedBox(width: Gap.sm),
              Text('₹4,299',
                  style: AppType.moneyS.c(p.inkFaint).copyWith(
                      decoration: TextDecoration.lineThrough,
                      decorationColor: p.inkFaint)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: p.successSoft, borderRadius: R.all(R.xs)),
                child: Text('30% OFF', style: AppType.labelS.c(p.success)),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              for (final t in ['10:00', '11:00', '2:00'])
                Padding(
                  padding: const EdgeInsets.only(right: Gap.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.md, vertical: Gap.sm),
                    decoration: BoxDecoration(
                      color: t == '11:00' ? p.ink : p.surfaceSunken,
                      borderRadius: R.all(R.sm),
                    ),
                    child: Text(t,
                        style: AppType.labelS.c(t == '11:00'
                            ? (p.isDark ? p.canvas : Colors.white)
                            : p.inkMuted)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackPreview extends StatelessWidget {
  const _TrackPreview({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    const steps = [
      ('Vehicle received', true),
      ('Inspection complete', true),
      ('Repair in progress', false),
      ('Ready for delivery', false),
    ];
    return _Shell(
      width: width,
      dark: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 8,
                width: 8,
                decoration:
                    BoxDecoration(color: p.volt, shape: BoxShape.circle),
              ),
              const SizedBox(width: Gap.sm),
              Text('LIVE', style: AppType.over.c(p.volt)),
              const Spacer(),
              Text('ETA 5:30 PM',
                  style: AppType.labelS.c(p.onInverse.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: Gap.lg),
          for (var i = 0; i < steps.length; i++)
            SizedBox(
              height: 38,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        height: 14,
                        width: 14,
                        decoration: BoxDecoration(
                          color: steps[i].$2 ? p.accent : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: steps[i].$2
                                ? p.accent
                                : p.onInverse.withValues(alpha: 0.25),
                            width: 2,
                          ),
                        ),
                        child: steps[i].$2
                            ? Icon(Icons.check_rounded,
                                size: 9, color: p.onAccent)
                            : null,
                      ),
                      if (i != steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: steps[i].$2
                                ? p.accent.withValues(alpha: 0.4)
                                : p.onInverse.withValues(alpha: 0.12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: Gap.md),
                  Text(
                    steps[i].$1,
                    style: AppType.labelM.c(steps[i].$2
                        ? p.onInverse
                        : p.onInverse.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ApprovePreview extends StatelessWidget {
  const _ApprovePreview({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return _Shell(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ESTIMATE • V1', style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.md),
          for (final item in [
            ('Front brake pads', '₹3,100', true),
            ('Brake fluid flush', '₹1,260', true),
            ('Air filter', '₹1,040', false),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Row(
                children: [
                  Container(
                    height: 20,
                    width: 20,
                    decoration: BoxDecoration(
                      color: item.$3 ? p.accent : Colors.transparent,
                      borderRadius: R.all(6),
                      border: Border.all(
                          color: item.$3 ? p.accent : p.line, width: 1.6),
                    ),
                    child: item.$3
                        ? Icon(Icons.check_rounded,
                            size: 13, color: p.onAccent)
                        : null,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                      child: Text(item.$1, style: AppType.labelM.c(p.ink))),
                  Text(item.$2, style: AppType.moneyS.c(p.inkSoft)),
                ],
              ),
            ),
          const SizedBox(height: Gap.xs),
          GDashedLinePreview(color: p.line),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Text('Approved', style: AppType.labelM.c(p.inkMuted)),
              const Spacer(),
              Text('₹4,360', style: AppType.money.c(p.accentInk)),
            ],
          ),
        ],
      ),
    );
  }
}

class GDashedLinePreview extends StatelessWidget {
  const GDashedLinePreview({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final n = (c.maxWidth / 9).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
              n, (_) => Container(width: 5, height: 1, color: color)),
        );
      },
    );
  }
}
