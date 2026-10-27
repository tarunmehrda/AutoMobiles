import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/access.dart';
import '../../data/models/entities.dart';
import '../../data/models/team.dart';
import '../../data/repo/garage_gateway.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// The team. Mechanics are assigned per job card and per line, which is what
/// makes the mechanic copy worth printing.
///
/// Each person can also be given the app: the owner names their email and a
/// role, and when that email signs in it lands in this workshop, seeing what
/// the role allows (31_staff_logins.sql). Who has it, and as what, is read
/// from the server each time the screen opens — it is not something this
/// phone can know on its own.
class StaffPage extends ConsumerStatefulWidget {
  const StaffPage({super.key});

  @override
  ConsumerState<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends ConsumerState<StaffPage> {
  Team? _team;
  bool _loading = false;

  /// True when the team could not be read, so the rows say "unknown"
  /// rather than "no app access" about people who may well have it.
  bool _failed = false;

  bool get _online => ref.read(garageGatewayProvider).enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTeam();
    });
  }

  Future<void> _loadTeam() async {
    if (!_online || !ref.read(accessProvider).team) return;
    setState(() => _loading = true);
    final team = await ref.read(garageGatewayProvider).team();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = team == null;
      _team = team ?? _team;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final staff = ref.watch(staffProvider);
    final data = ref.watch(adminDataProvider);
    final access = ref.watch(accessProvider);
    // Only the owner hands out the app; a manager may look.
    final grants = access.isOwner && _online;
    final edits = access.can('users', 'e');

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Staff'.tr,
        subtitle: '{0} on the team'.trf([staff.length]),
        actions: [
          if (edits)
            GIconButton(
              icon: Icons.add_rounded,
              size: 40,
              onTap: () => _editor(context, null),
            ),
        ],
      ),
      body: staff.isEmpty
          ? GEmptyState(
              icon: Icons.engineering_rounded,
              title: 'No mechanics yet'.tr,
              art: Art.customers,
              message:
                  'Add the team so work can be assigned per job card and per line on the mechanic copy.'
                      .tr,
              actionLabel: edits ? '+ Add Staff'.tr : null,
              onAction: edits ? () => _editor(context, null) : null,
            )
          : RefreshIndicator(
              onRefresh: _loadTeam,
              color: p.accent,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.md,
                  Gap.page,
                  Gap.h2,
                ),
                itemCount: staff.length + (grants ? 1 : 0),
                itemBuilder: (context, i) {
                  if (grants && i == 0) return const _AccessIntro();
                  final s = staff[grants ? i - 1 : i];
                  // How much work is sitting with this mechanic right now.
                  final live = data.jobCards
                      .where(
                        (j) =>
                            j.isOpen &&
                            (j.mechanicIds.contains(s.id) ||
                                j.items.any((e) => e.mechanicId == s.id)),
                      )
                      .length;

                  return _StaffRow(
                    staff: s,
                    live: live,
                    member: _team?.memberFor(s.id),
                    invite: _team?.inviteFor(s.id),
                    showAccess: access.team && _online,
                    loading: _loading && _team == null,
                    failed: _failed && _team == null,
                    onTap: edits ? () => _editor(context, s) : null,
                    onAccess: grants ? () => _accessSheet(context, s) : null,
                  );
                },
              ),
            ),
    );
  }

  // -------------------------------------------------------------------------
  // App access
  // -------------------------------------------------------------------------

  Future<void> _accessSheet(BuildContext context, Staff s) async {
    final team = _team;
    if (team == null) {
      await _loadTeam();
      if (!mounted || _team == null) {
        if (context.mounted) {
          GFeedback.error(
            context,
            'Could not reach the server. Check the connection and try again.'
                .tr,
          );
        }
        return;
      }
    }
    if (!context.mounted) return;
    final changed = await GFeedback.sheet<bool>(
      context,
      title: 'App access'.tr,
      subtitle: s.name,
      child: _AccessSheet(
        staff: s,
        member: _team!.memberFor(s.id),
        invite: _team!.inviteFor(s.id),
      ),
    );
    if (changed == true) await _loadTeam();
  }

  // -------------------------------------------------------------------------
  // The person
  // -------------------------------------------------------------------------

  Future<void> _editor(BuildContext context, Staff? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final skill = TextEditingController(text: existing?.skill ?? '');
    final role = TextEditingController(text: existing?.designation ?? '');
    final remarks = TextEditingController(text: existing?.remarks ?? '');
    var active = existing?.active ?? true;

    await GFeedback.sheet<void>(
      context,
      title: existing == null ? 'Add Staff'.tr : existing.name,
      // Owned by the sheet, not by this function: its future completes
      // when the sheet starts closing, and the fields go on reading these
      // all the way through the exit transition.
      disposing: [name, phone, skill, role, remarks],
      child: StatefulBuilder(
        builder: (context, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            Gap.page,
            Gap.lg,
            Gap.page,
            MediaQuery.of(context).viewInsets.bottom + Gap.h1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GField(
                label: 'Name'.tr,
                hint: 'Rahul Sharma'.tr,
                controller: name,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: Gap.lg),
              // What they are employed as. Picked from the usual floor
              // roles, or typed — every workshop has one nobody else does.
              GField(
                label: 'Employee role'.tr,
                hint: 'Mechanic, Helper, Electrician…'.tr,
                controller: role,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final r in kStaffDesignations)
                    ChoiceChip(
                      label: Text(r.tr),
                      selected: role.text == r,
                      onSelected: (_) => setSheet(() => role.text = r),
                    ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              GField(
                label: 'Contact No'.tr,
                hint: 'Optional'.tr,
                controller: phone,
                keyboardType: TextInputType.phone,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: Gap.lg),
              GField(
                label: 'Speciality'.tr,
                hint: 'Engine, electrical, denting…'.tr,
                controller: skill,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: Gap.lg),
              GField(
                label: 'Remarks'.tr,
                hint: 'Joined in March · Night shift'.tr,
                controller: remarks,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              if (existing != null) ...[
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active'.tr,
                            style: AppType.labelL.c(context.c.ink),
                          ),
                          Text(
                            'Inactive mechanics stay on old job cards but cannot be assigned new work'
                                .tr,
                            style: AppType.bodyS.c(context.c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: active,
                      onChanged: (v) => setSheet(() => active = v),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Gap.xxl),
              Row(
                children: [
                  if (existing != null) ...[
                    Expanded(
                      child: GButton(
                        label: 'Remove'.tr,
                        kind: GButtonKind.danger,
                        size: GButtonSize.md,
                        onPressed: () async {
                          // Somebody who can sign in is taken off the app
                          // first; a login pointing at a deleted person
                          // would see nothing and could not be managed.
                          final m = _team?.memberFor(existing.id);
                          if (m != null) {
                            GFeedback.error(
                              context,
                              'Remove their app access first.'.tr,
                            );
                            return;
                          }
                          ref
                              .read(adminProvider.notifier)
                              .removeStaff(existing.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: GButton.accent(
                      label: existing == null ? 'Add'.tr : 'Save'.tr,
                      size: GButtonSize.md,
                      onPressed: () {
                        // A mechanic with no name cannot be told apart on
                        // the assign list or the mechanic copy, so a blank
                        // name is still refused. It used to be refused in
                        // silence: the button looked dead and the counter
                        // kept tapping it. Saying why is the whole fix. The
                        // phone and speciality stay optional, so they get
                        // no such check.
                        if (name.text.trim().isEmpty) {
                          GFeedback.error(context, 'Enter a name first.'.tr);
                          return;
                        }
                        final ctrl = ref.read(adminProvider.notifier);
                        if (existing == null) {
                          ctrl.addStaff(
                            name: name.text.trim(),
                            phone: phone.text.trim(),
                            skill: skill.text.trim(),
                            designation: role.text.trim(),
                            remarks: remarks.text.trim(),
                          );
                        } else {
                          ctrl.updateStaff(
                            existing.copyWith(
                              name: name.text.trim(),
                              phone: phone.text.trim(),
                              skill: skill.text.trim(),
                              designation: role.text.trim(),
                              remarks: remarks.text.trim(),
                              active: active,
                            ),
                          );
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Says once, at the top, what "App access" on each row is for.
/// The roles a workshop floor usually has, offered as one-tap picks.
const kStaffDesignations = [
  'Mechanic',
  'Senior Mechanic',
  'Helper',
  'Electrician',
  'Denter',
  'Painter',
  'Washer',
  'Supervisor',
  'Accountant',
  'Receptionist',
];

class _AccessIntro extends StatelessWidget {
  const _AccessIntro();

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(color: p.accentSoft, borderRadius: R.all(R.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.phone_android_rounded, size: 20, color: p.accentInk),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              'Give a person the app: tap App access, add their email and pick a role. They sign in with that email and land in this workshop, seeing only what the role allows.'
                  .tr,
              style: AppType.bodyS.c(p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.staff,
    required this.live,
    required this.member,
    required this.invite,
    required this.showAccess,
    required this.loading,
    required this.failed,
    required this.onTap,
    required this.onAccess,
  });

  final Staff staff;
  final int live;
  final TeamMember? member;
  final TeamInvite? invite;
  final bool showAccess;
  final bool loading;
  final bool failed;
  final VoidCallback? onTap;
  final VoidCallback? onAccess;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final s = staff;
    final m = member;
    final inv = invite;

    final (String label, GTone tone, IconData icon) = loading
        ? ('Checking…'.tr, GTone.neutral, Icons.more_horiz_rounded)
        : failed
        ? ('App access unknown'.tr, GTone.neutral, Icons.cloud_off_rounded)
        : m != null
        ? (m.role.label, GTone.success, Icons.verified_user_rounded)
        : inv != null
        ? (
            '{0} · invited'.trf([inv.role.label]),
            GTone.warning,
            Icons.mark_email_unread_rounded,
          )
        : ('No app access'.tr, GTone.neutral, Icons.phone_android_rounded);

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GAvatar(
                  initials: Fmt.initials(s.name),
                  size: 42,
                  tone: s.active ? GTone.ink : GTone.neutral,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: AppType.h2.c(p.ink)),
                      Text(
                        [
                          if (s.designation.isNotEmpty) s.designation,
                          if (s.skill.isNotEmpty) s.skill,
                          if (s.phone.isNotEmpty) s.phone,
                        ].join('  •  '),
                        style: AppType.bodyS.c(p.inkMuted),
                      ),
                    ],
                  ),
                ),
                if (!s.active)
                  Flexible(
                    child: GPill(
                      label: 'Inactive'.tr,
                      tone: GTone.neutral,
                      compact: true,
                    ),
                  )
                else if (live > 0)
                  Flexible(
                    child: GPill(
                      label: '{0} on the floor'.trf([live]),
                      tone: GTone.accent,
                      compact: true,
                    ),
                  ),
              ],
            ),
            if (showAccess) ...[
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  GPill(label: label, tone: tone, icon: icon, compact: true),
                  if (m != null || inv != null) ...[
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        m?.email ?? inv!.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyS.c(p.inkMuted),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (onAccess != null)
                    Pressable(
                      onTap: onAccess,
                      scale: 0.95,
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: m == null && inv == null
                              ? p.accent
                              : p.surfaceSunken,
                          borderRadius: R.all(R.pill),
                          border: Border.all(
                            color: m == null && inv == null ? p.accent : p.line,
                          ),
                        ),
                        child: Text(
                          m == null && inv == null
                              ? 'Give app access'.tr
                              : 'Manage'.tr,
                          style: AppType.labelS.c(
                            m == null && inv == null ? p.onAccent : p.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Give, change or take away one person's app. Pops `true` when anything
/// changed, so the list re-reads the team.
class _AccessSheet extends ConsumerStatefulWidget {
  const _AccessSheet({
    required this.staff,
    required this.member,
    required this.invite,
  });

  final Staff staff;
  final TeamMember? member;
  final TeamInvite? invite;

  @override
  ConsumerState<_AccessSheet> createState() => _AccessSheetState();
}

class _AccessSheetState extends ConsumerState<_AccessSheet> {
  late final _email = TextEditingController(text: widget.invite?.email ?? '');
  late StaffRole _role =
      widget.member?.role ?? widget.invite?.role ?? StaffRole.mechanic;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  GarageGateway get _gw => ref.read(garageGatewayProvider);

  Future<void> _run(Future<String?> Function() call, String done) async {
    setState(() => _busy = true);
    final error = await call();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      GFeedback.error(context, error.tr);
      return;
    }
    GFeedback.success(context, done);
    Navigator.of(context).pop(true);
  }

  Future<void> _invite() async {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      GFeedback.error(context, 'Enter a valid email address.'.tr);
      return;
    }
    await _run(
      () => _gw.invite(staffId: widget.staff.id, email: email, role: _role),
      'Done. {0} can sign in with {1} now.'.trf([widget.staff.name, email]),
    );
  }

  Future<void> _saveRole() => _run(
    () => _gw.setRole(widget.member!.profileId, _role),
    '{0} is now {1}.'.trf([widget.staff.name, _role.label]),
  );

  Future<void> _remove() async {
    final ok = await GFeedback.confirm(
      context,
      title: 'Remove app access?'.tr,
      message:
          '{0} is signed out of this workshop on their next sync. Their name and the job cards they worked on stay.'
              .trf([widget.staff.name]),
      confirmLabel: 'Remove'.tr,
      destructive: true,
      icon: Icons.no_accounts_rounded,
    );
    if (!ok) return;
    await _run(
      () => _gw.removeAccess(widget.member!.profileId),
      'App access removed.'.tr,
    );
  }

  Future<void> _cancel() => _run(
    () => _gw.cancelInvite(widget.invite!.email),
    'Invitation cancelled.'.tr,
  );

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final m = widget.member;
    final inv = widget.invite;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Gap.page,
        Gap.lg,
        Gap.page,
        MediaQuery.of(context).viewInsets.bottom + Gap.h1,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (m != null)
            _Status(
              icon: Icons.verified_user_rounded,
              tone: GTone.success,
              title: 'Signs in as {0}'.trf([m.email]),
              body: m.lastSignIn == null
                  ? 'Has app access.'.tr
                  : 'Last signed in {0}.'.trf([Fmt.dateTime(m.lastSignIn!)]),
            )
          else if (inv != null)
            _Status(
              icon: Icons.mark_email_unread_rounded,
              tone: GTone.warning,
              title: 'Waiting for {0}'.trf([inv.email]),
              body:
                  'Ask them to install GaragePro Admin and sign in with this email. They join this workshop the moment they do.'
                      .tr,
            )
          else ...[
            GField(
              label: 'Their email'.tr,
              hint: 'name@gmail.com',
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'They sign in with this email, with Google or a password. Email only: a phone number cannot be used.'
                  .tr,
              style: AppType.bodyS.c(p.inkMuted),
            ),
          ],
          const SizedBox(height: Gap.xl),
          Text('Role'.tr, style: AppType.labelL.c(p.ink)),
          const SizedBox(height: Gap.sm),
          for (final r in StaffRole.invitable)
            GOptionRow(
              label: r.label,
              subtitle: r.blurb,
              selected: _role == r,
              onTap: _busy ? () {} : () => setState(() => _role = r),
            ),
          const SizedBox(height: Gap.lg),
          if (m != null) ...[
            GButton.accent(
              label: 'Save role'.tr,
              size: GButtonSize.md,
              loading: _busy,
              expand: true,
              onPressed: _busy || _role == m.role ? null : _saveRole,
            ),
            const SizedBox(height: Gap.md),
            GButton(
              label: 'Remove app access'.tr,
              kind: GButtonKind.danger,
              size: GButtonSize.md,
              expand: true,
              onPressed: _busy ? null : _remove,
            ),
          ] else if (inv != null) ...[
            GButton.accent(
              label: 'Update role'.tr,
              size: GButtonSize.md,
              loading: _busy,
              expand: true,
              onPressed: _busy || _role == inv.role
                  ? null
                  : () {
                      _email.text = inv.email;
                      _invite();
                    },
            ),
            const SizedBox(height: Gap.md),
            GButton(
              label: 'Cancel invitation'.tr,
              kind: GButtonKind.outline,
              size: GButtonSize.md,
              expand: true,
              onPressed: _busy ? null : _cancel,
            ),
          ] else
            GButton.accent(
              label: 'Give app access'.tr,
              icon: Icons.send_rounded,
              size: GButtonSize.md,
              loading: _busy,
              expand: true,
              onPressed: _busy ? null : _invite,
            ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final GTone tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final colors = toneOf(context, tone);
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(color: colors.bg, borderRadius: R.all(R.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.fg),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.labelL.c(p.ink)),
                const SizedBox(height: 2),
                Text(body, style: AppType.bodyS.c(p.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
