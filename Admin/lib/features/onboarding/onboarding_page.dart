import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/admin_state.dart';
import 'widgets/language_step.dart';
import 'widgets/permission_step.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

/// Which stage of first run is currently active.
enum _Stage { language, permissions }

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  _Stage _stage = _Stage.language;

  void _done() {
    ref.read(adminProvider.notifier).completeOnboarding();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Language and permissions: what the app speaks, then what it needs.
    if (_stage == _Stage.language) {
      return LanguageStep(
        onContinue: () => setState(() => _stage = _Stage.permissions),
      );
    }
    return PermissionStep(onDone: _done);
  }
}
