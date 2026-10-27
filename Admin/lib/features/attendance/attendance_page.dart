import '../../core/i18n/strings.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/attendance.dart';
import '../../data/models/entities.dart';
import '../../data/repo/attendance_gate.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import 'widgets/radius_dial.dart';

/// Punch in and punch out, if the phone can prove where it is.
///
/// The screen is arranged around one question — may this person punch right
/// now, and if not, why not — because that is the only question somebody
/// standing in a workshop doorway has. The location is checked on arrival
/// rather than on the button, so the answer is already on screen before
/// anybody reaches for it, and a refusal never arrives as a surprise after
/// a tap.
class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  Staff? _who;
  GateReading? _reading;
  bool _checking = false;
  bool _punching = false;

  /// Set once the first automatic check has run, so the card can say
  /// "checking" rather than "unknown" on the way in.
  bool _checkedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreWho();
      // The register behind the button decides whether it says In or Out,
      // so it is worth a round trip before the button is drawn.
      unawaited(ref.read(adminProvider.notifier).refreshAttendance());
      unawaited(_check());
    });
  }

  /// Whoever punched last on this handset, if they are still on the team.
  ///
  /// A shop where everybody carries their own phone never sees the picker
  /// after the first time; a shop with one phone on the counter finds the
  /// last person still selected, which is wrong about as often as it is
  /// right — hence the picker staying in plain sight rather than tucked
  /// into a menu.
  void _restoreWho() {
    final staff = _punchable(ref.read(staffProvider));
    if (staff.isEmpty) return;
    final saved = localStore.lastPuncher;
    setState(
      () => _who = staff.firstWhere(
        (s) => s.id == saved,
        orElse: () => staff.first,
      ),
    );
  }

  /// Who this person may punch for. The owner or a manager, on a shared
  /// counter phone, punches whoever is standing there; anybody else punches
  /// only the staff record that is them. The database holds the same line
  /// (31_staff_logins.sql).
  List<Staff> _punchable(List<Staff> all) {
    final access = ref.read(accessProvider);
    final active = all.where((s) => s.active);
    if (access.manageAttendance) return active.toList();
    return active.where((s) => s.id == access.staffId).toList();
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    final reading = await AttendanceGate.read(
      site: ref.read(attendanceSiteProvider),
      previous: _who == null
          ? null
          : Shift.lastAccepted(ref.read(attendanceProvider), _who!.id),
    );
    if (!mounted) return;
    setState(() {
      _reading = reading;
      _checking = false;
      _checkedOnce = true;
    });
  }

  Future<void> _punch(PunchKind kind) async {
    final who = _who;
    if (who == null || _punching) return;
    setState(() => _punching = true);
    final outcome = await ref
        .read(adminProvider.notifier)
        .punch(who: who, kind: kind);
    if (!mounted) return;
    setState(() {
      _punching = false;
      // The punch took a fresh reading of its own; showing the stale one
      // underneath the result it contradicts is how a screen starts lying.
      _reading = outcome.reading;
      _checkedOnce = true;
    });

    unawaited(localStore.setLastPuncher(who.id));

    if (outcome.block == PunchBlock.none) {
      GFeedback.success(
        context,
        '${who.name} ${kind.past.toLowerCase()} at ${Fmt.time(DateTime.now())}',
      );
      return;
    }
    if (outcome.block == PunchBlock.offline) {
      GFeedback.toast(
        context,
        'Recorded, but not verified by the workshop server'.tr,
        tone: GTone.warning,
        icon: Icons.cloud_off_rounded,
      );
      return;
    }
    await _refused(outcome);
  }

  /// A refusal gets a dialog, not a snackbar. It is the one outcome that
  /// needs reading, sometimes needs acting on, and must not slide away
  /// while somebody is still working out what happened.
  Future<void> _refused(PunchOutcome outcome) async {
    final block = outcome.block;
    final settings = block == PunchBlock.blocked || block == PunchBlock.reduced;
    final gps = block == PunchBlock.serviceOff;

    final act = await GFeedback.confirm(
      context,
      icon: block.isAbuse ? Icons.gpp_bad_rounded : Icons.error_outline_rounded,
      title: block.isAbuse ? 'Attendance refused'.tr : block.short,
      message: outcome.message,
      destructive: block.isAbuse,
      confirmLabel: settings
          ? 'Open Settings'.tr
          : gps
          ? 'Turn on GPS'.tr
          : 'Check again'.tr,
      cancelLabel: 'Close'.tr,
    );
    if (!act || !mounted) return;
    if (settings) {
      await Geolocator.openAppSettings();
    } else if (gps) {
      await Geolocator.openLocationSettings();
    }
    if (mounted) await _check();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final site = ref.watch(attendanceSiteProvider);
    final access = ref.watch(accessProvider);
    final staff = _punchable(ref.watch(staffProvider));
    final log = ref.watch(attendanceProvider);
    final onFloor = ref.watch(onFloorProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Attendance'.tr,
        subtitle: onFloor.isEmpty
            ? 'Nobody punched in'.tr
            : '{0} on the floor'.trf([onFloor.length]),
        actions: [
          GIconButton(
            icon: Icons.receipt_long_rounded,
            size: 40,
            tooltip: 'Register'.tr,
            onTap: () => context.push('/attendance/register'),
          ),
          if (access.workshopSettings) ...[
            const SizedBox(width: Gap.sm),
            GIconButton(
              icon: Icons.tune_rounded,
              size: 40,
              tooltip: 'Attendance location'.tr,
              onTap: () => context.push('/attendance/site'),
            ),
          ],
        ],
      ),
      body: site == null
          ? _NoSite(
              onSet: access.workshopSettings
                  ? () => context.push('/attendance/site')
                  : null,
            )
          : staff.isEmpty
          ? _NoTeam(
              onAdd: access.team ? () => context.push('/staff') : null,
              linked: access.manageAttendance || access.staffId.isNotEmpty,
            )
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(adminProvider.notifier).refreshAttendance();
                await _check();
              },
              child: _body(site, staff, log),
            ),
    );
  }

  Widget _body(
    AttendanceSite site,
    List<Staff> staff,
    List<AttendancePunch> log,
  ) {
    final who = _who;
    final next = who == null ? PunchKind.punchIn : Shift.next(log, who.id);
    final today = log.where((e) => _sameDay(e.at, DateTime.now())).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
      children: [
        _WhoCard(
          who: who,
          onDuty: who != null && Shift.onDuty(log, who.id),
          worked: who == null ? Duration.zero : Shift.worked(today, who.id),
          onTap: () => _pickWho(staff),
        ),
        const SizedBox(height: Gap.lg),
        Entrance(
          child: RadiusDial(
            site: site,
            reading: _reading,
            busy: _checking,
            settled: _checkedOnce,
          ),
        ),
        const SizedBox(height: Gap.md),
        _Verdict(
          site: site,
          reading: _reading,
          busy: _checking,
          onRecheck: _check,
        ),
        const SizedBox(height: Gap.lg),
        GButton(
          label: next.label,
          kind: next == PunchKind.punchIn
              ? GButtonKind.accent
              : GButtonKind.primary,
          icon: next == PunchKind.punchIn
              ? Icons.login_rounded
              : Icons.logout_rounded,
          loading: _punching,
          // Deliberately live even when the last reading says no. The check
          // on screen may be a minute old and the person may have walked
          // since; the punch takes its own fresh reading, and the backend
          // takes the decision. A button greyed out on stale evidence is a
          // door somebody cannot open while standing in it.
          onPressed: (_punching || who == null) ? null : () => _punch(next),
        ),
        const SizedBox(height: Gap.xxl),
        GSectionHeader(
          title: 'Today'.tr,
          subtitle: today.isEmpty
              ? 'Nothing marked yet'.tr
              : '{0} marked, {1} refused'.trf([
                  today.where((e) => e.accepted).length,
                  today.where((e) => !e.accepted).length,
                ]),
          padding: EdgeInsets.zero,
          actionLabel: 'Register'.tr,
          onAction: () => context.push('/attendance/register'),
        ),
        const SizedBox(height: Gap.sm),
        if (today.isEmpty)
          GEmptyState(
            icon: Icons.schedule_rounded,
            art: Art.done,
            compact: true,
            title: 'Nobody has punched today'.tr,
            message: 'The first punch of the day appears here.'.tr,
          )
        else
          for (final row in today) PunchRow(punch: row),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickWho(List<Staff> staff) async {
    final log = ref.read(attendanceProvider);
    await GFeedback.sheet<void>(
      context,
      title: 'Who is punching?'.tr,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GTileGroup(
              children: [
                for (final s in staff)
                  GTile(
                    title: s.name,
                    subtitle: [
                      if (s.skill.isNotEmpty) s.skill,
                      Shift.onDuty(log, s.id)
                          ? 'On the floor'.tr
                          : 'Off duty'.tr,
                    ].join('  •  '),
                    leading: GAvatar(
                      initials: Fmt.initials(s.name),
                      size: 38,
                      tone: Shift.onDuty(log, s.id)
                          ? GTone.success
                          : GTone.neutral,
                    ),
                    showChevron: false,
                    trailing: s.id == _who?.id
                        ? Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: context.c.accent,
                          )
                        : null,
                    onTap: () {
                      setState(() => _who = s);
                      unawaited(localStore.setLastPuncher(s.id));
                      Navigator.of(context).pop();
                      // A different person has a different last punch, so
                      // the teleport check has a different baseline.
                      unawaited(_check());
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Who is punching, and where their shift stands.
class _WhoCard extends StatelessWidget {
  const _WhoCard({
    required this.who,
    required this.onDuty,
    required this.worked,
    required this.onTap,
  });

  final Staff? who;
  final bool onDuty;
  final Duration worked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return GCard(
      onTap: onTap,
      child: Row(
        children: [
          GAvatar(
            initials: who == null ? '?' : Fmt.initials(who!.name),
            size: 46,
            tone: onDuty ? GTone.success : GTone.ink,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  who?.name ?? 'Pick who is punching'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.h1.c(p.ink),
                ),
                const SizedBox(height: 2),
                // Both halves grow in Hindi, and this sits inside an
                // already-narrow column beside the avatar. Letting each
                // give way keeps the status and the hours on one line
                // instead of pushing the row off the card.
                Row(
                  children: [
                    Flexible(
                      child: GPill(
                        label: onDuty ? 'On the floor'.tr : 'Off duty'.tr,
                        tone: onDuty ? GTone.success : GTone.neutral,
                        dot: true,
                        compact: true,
                      ),
                    ),
                    if (worked > Duration.zero) ...[
                      const SizedBox(width: Gap.sm),
                      Flexible(
                        child: Text(
                          '{0} today'.trf([_hhmm(worked)]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyS.c(p.inkMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.unfold_more_rounded, size: 20, color: p.inkFaint),
        ],
      ),
    );
  }

  static String _hhmm(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m}m';
  }
}

/// The sentence under the dial: what the reading means, and the way out of
/// it when it means no.
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.site,
    required this.reading,
    required this.busy,
    required this.onRecheck,
  });

  final AttendanceSite site;
  final GateReading? reading;
  final bool busy;
  final Future<void> Function() onRecheck;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final r = reading;

    final (tone, text) = switch (r) {
      null when busy => (GTone.info, 'Checking where this phone is…'),
      null => (GTone.neutral, 'Tap Check again to place this phone.'),
      _ => (
        r.ok ? GTone.success : (r.block.isAbuse ? GTone.danger : GTone.warning),
        AttendanceGate.explain(r.block, site: site, reading: r),
      ),
    };
    final t = toneOf(context, tone);

    return GCard(
      color: t.bg,
      borderColor: t.fg.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                r == null
                    ? Icons.my_location_rounded
                    : r.ok
                    ? Icons.verified_rounded
                    : r.block.isAbuse
                    ? Icons.gpp_bad_rounded
                    : Icons.warning_amber_rounded,
                size: 19,
                color: t.fg,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text(text, style: AppType.bodyS.c(t.fg))),
            ],
          ),
          if (r != null && r.note.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(
              'Noted: {0}'.trf([r.note]),
              style: AppType.bodyS.s(11.5).c(t.fg.withValues(alpha: 0.75)),
            ),
          ],
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  r == null || !r.located
                      ? 'No fix yet'.tr
                      : 'Fix ±{0} m · allowed within {1}'.trf([
                          r.accuracyM.round(),
                          AttendanceGate.metres(site.radiusM),
                        ]),
                  style: AppType.bodyS.s(11.5).c(p.inkMuted),
                ),
              ),
              GButton(
                label: busy ? 'Checking'.tr : 'Check again'.tr,
                kind: GButtonKind.ghost,
                size: GButtonSize.sm,
                expand: false,
                loading: busy,
                onPressed: busy ? null : () => onRecheck(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line of the register, used by this screen and the register itself.
class PunchRow extends StatelessWidget {
  const PunchRow({super.key, required this.punch, this.showName = true});

  final AttendancePunch punch;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final refused = !punch.accepted;
    final tone = refused
        ? (punch.block.isAbuse ? GTone.danger : GTone.warning)
        : (punch.kind == PunchKind.punchIn ? GTone.success : GTone.neutral);
    final t = toneOf(context, tone);

    return Container(
      margin: EdgeInsets.only(bottom: Gap.sm),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.md),
        border: Border.all(
          color: refused ? t.fg.withValues(alpha: 0.3) : p.line,
        ),
        boxShadow: Shadows.soft(p),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(color: t.bg, borderRadius: R.all(R.sm)),
            child: Icon(
              refused
                  ? (punch.block.isAbuse
                        ? Icons.gpp_bad_rounded
                        : Icons.block_rounded)
                  : (punch.kind == PunchKind.punchIn
                        ? Icons.login_rounded
                        : Icons.logout_rounded),
              size: 17,
              color: t.fg,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        showName
                            ? '${punch.staffName} · ${punch.kind.label}'
                            : punch.kind.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelL.c(p.ink),
                      ),
                    ),
                    Text(
                      Fmt.time(punch.at),
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GPill(
                      label: refused ? punch.block.short : 'Marked'.tr,
                      tone: tone,
                      compact: true,
                    ),
                    // An unverified punch is the phone's unchecked word for
                    // it, and the register says so rather than letting it
                    // pass for a checked one.
                    if (!punch.verified)
                      GPill(
                        label: 'Not verified'.tr,
                        tone: GTone.warning,
                        compact: true,
                      ),
                    if (punch.mocked)
                      GPill(
                        label: 'Mock GPS'.tr,
                        tone: GTone.danger,
                        compact: true,
                      ),
                    Text(
                      "${AttendanceGate.metres(punch.distanceM)} away${punch.accuracyM > 0 ? ' · ±${punch.accuracyM.round()} m' : ''}",
                      style: AppType.bodyS.s(11.5).c(p.inkFaint),
                    ),
                  ],
                ),
                if (punch.note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(punch.note, style: AppType.bodyS.s(11.5).c(p.inkFaint)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSite extends StatelessWidget {
  const _NoSite({required this.onSet});

  /// Null for somebody who cannot set it: they are told who can.
  final VoidCallback? onSet;

  @override
  Widget build(BuildContext context) => GEmptyState(
    icon: Icons.location_searching_rounded,
    art: Art.searching,
    title: 'No attendance location yet'.tr,
    message: onSet == null
        ? 'The owner pins the workshop once. Punching in opens after that.'.tr
        : 'Stand in the workshop and pin it once. After that, staff can only punch in from within the circle you set.'
              .tr,
    actionLabel: onSet == null ? null : 'Set the location'.tr,
    onAction: onSet,
  );
}

class _NoTeam extends StatelessWidget {
  const _NoTeam({required this.onAdd, this.linked = true});

  final VoidCallback? onAdd;

  /// False for a staff login the owner never tied to a person on the team,
  /// which is the one thing that person can do nothing about.
  final bool linked;

  @override
  Widget build(BuildContext context) => GEmptyState(
    icon: Icons.engineering_rounded,
    art: Art.customers,
    title: linked
        ? 'Nobody on the team yet'.tr
        : 'Your login is not on the team list'.tr,
    message: linked
        ? 'Attendance is marked against a person, so add the team before anybody can punch in.'
              .tr
        : 'Ask the owner to give you app access from your name under Staff.'.tr,
    actionLabel: onAdd == null ? null : 'Add a mechanic'.tr,
    onAction: onAdd,
  );
}
