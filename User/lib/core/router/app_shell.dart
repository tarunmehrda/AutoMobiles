import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import '../widgets/pressable.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Four tabs, because there are only four things a customer does here: see
/// where their car is, look at what they have booked, keep their vehicles,
/// and change their own details.
const _tabs = <_Tab>[
  _Tab('Home', Icons.home_outlined, Icons.home_rounded),
  _Tab('Bookings', Icons.calendar_month_outlined,
      Icons.calendar_month_rounded),
  _Tab('Vehicles', Icons.directions_car_outlined,
      Icons.directions_car_rounded),
  _Tab('Profile', Icons.person_outline_rounded, Icons.person_rounded),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final upcoming = ref.watch(upcomingBookingsProvider).length;

    return Scaffold(
      backgroundColor: p.canvas,
      body: shell,
      bottomNavigationBar: _NavBar(
        index: shell.currentIndex,
        onTap: (i) => _go(context, i),
        badges: {1: upcoming},
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.onTap,
    this.badges = const {},
  });

  final int index;
  final ValueChanged<int> onTap;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
        boxShadow: p.isDark ? null : Shadows.lifted(p),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth / _tabs.length;
              return Stack(
                children: [
                  // Sliding accent rail above the selected tab.
                  AnimatedPositioned(
                    duration: Motion.base,
                    curve: Motion.spring,
                    left: w * index + w * 0.5 - 14,
                    top: 0,
                    child: Container(
                      height: 3,
                      width: 28,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(R.pill)),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        SizedBox(
                          width: w,
                          child: _NavItem(
                            tab: _tabs[i],
                            selected: i == index,
                            badge: badges[i] ?? 0,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.badge,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final color = selected ? p.accent : p.inkFaint;
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      haptic: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: Motion.base,
                curve: Motion.spring,
                child: Icon(selected ? tab.activeIcon : tab.icon,
                    size: 23, color: color),
              ),
              if (badge > 0)
                Positioned(
                  right: -7,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: R.all(R.pill),
                      border: Border.all(color: p.surface, width: 1.6),
                    ),
                    child: Center(
                      child: Text(badge > 9 ? '9+' : '$badge',
                          style: AppType.labelS.s(9).c(p.onAccent)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: Motion.fast,
            style: AppType.labelS
                .s(10.5)
                .c(color)
                .w(selected ? FontWeight.w700 : FontWeight.w500),
            child: Text(tab.label),
          ),
        ],
      ),
    );
  }
}
