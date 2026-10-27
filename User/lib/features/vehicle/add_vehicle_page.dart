import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_image.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../data/seed/media.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import 'widgets/brand_tile.dart';

class AddVehiclePage extends ConsumerStatefulWidget {
  const AddVehiclePage({super.key, this.editingId});

  final String? editingId;

  @override
  ConsumerState<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends ConsumerState<AddVehiclePage> {
  final _page = PageController();
  int _step = 0;

  VehicleBrand? _brand;
  VehicleModel? _model;
  FuelType? _fuel;
  Transmission? _transmission;
  int _year = DateTime.now().year - 2;

  final _reg = TextEditingController();
  final _odo = TextEditingController();
  final _vin = TextEditingController();
  String? _variant;
  DateTime? _insurance;
  DateTime? _puc;

  static const _labels = ['Brand', 'Model', 'Configuration', 'Details'];

  bool get _editing => widget.editingId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  void _loadForEdit() {
    final v = ref.read(appControllerProvider).vehicleById(widget.editingId);
    if (v == null) return;
    setState(() {
      // A car added by hand has a brand the catalogue does not know. It
      // still needs one here, or Save quietly does nothing on it for ever.
      _brand = Seed.brandByName(v.brand) ??
          VehicleBrand(id: 'custom', name: v.brand, logoUrl: '');
      _model = Seed.models.firstWhere(
        (m) => m.name == v.model,
        orElse: () => VehicleModel(
            id: 'custom', brandId: _brand?.id ?? '', name: v.model, body: v.body),
      );
      _fuel = v.fuel;
      _transmission = v.transmission;
      _year = v.year;
      _variant = v.variant;
      _insurance = v.insuranceExpiry;
      _puc = v.pucExpiry;
      _reg.text = v.regNumber;
      _odo.text = v.odometerKm == 0 ? '' : v.odometerKm.toString();
      _vin.text = v.vin ?? '';
      _step = 3;
    });
    _page.jumpToPage(3);
  }

  @override
  void dispose() {
    _page.dispose();
    _reg.dispose();
    _odo.dispose();
    _vin.dispose();
    super.dispose();
  }

  void _goto(int step) {
    setState(() => _step = step);
    _page.animateToPage(step, duration: Motion.base, curve: Motion.emphasized);
  }

  void _back() {
    if (_step == 0 || (_editing && _step == 3)) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
    }
    _goto(_step - 1);
  }

  bool get _detailsValid =>
      _reg.text.trim().length >= 6 && _fuel != null && _transmission != null;

  void _save() {
    if (!_detailsValid || _brand == null || _model == null) return;
    final controller = ref.read(appControllerProvider.notifier);
    final km = int.tryParse(_odo.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

    if (_editing) {
      final existing =
          ref.read(appControllerProvider).vehicleById(widget.editingId)!;
      controller.updateVehicle(existing.copyWith(
        brand: _brand!.name,
        model: _model!.name,
        regNumber: _reg.text.trim().toUpperCase(),
        fuel: _fuel,
        transmission: _transmission,
        year: _year,
        body: _model!.body,
        variant: _variant,
        odometerKm: km,
        insuranceExpiry: _insurance,
        pucExpiry: _puc,
        vin: _vin.text.trim().isEmpty ? null : _vin.text.trim().toUpperCase(),
      ));
      GFeedback.success(context, 'Vehicle updated');
      context.pop();
      return;
    }

    final vehicle = Vehicle(
      id: newId('veh'),
      brand: _brand!.name,
      model: _model!.name,
      regNumber: _reg.text.trim().toUpperCase(),
      fuel: _fuel!,
      transmission: _transmission!,
      year: _year,
      body: _model!.body,
      variant: _variant,
      odometerKm: km,
      // Blank stays blank. These used to be made up — insurance due in 128
      // days, PUC in 21, a service 186 days ago — and the reminders then
      // counted down to dates nobody had given us. The screens say "Not
      // set" instead, and the first real service fills the last one in.
      insuranceExpiry: _insurance,
      pucExpiry: _puc,
      vin: _vin.text.trim().isEmpty ? null : _vin.text.trim().toUpperCase(),
    );

    controller.addVehicle(vehicle);
    HapticFeedback.mediumImpact();
    if (ref.read(appControllerProvider).vehicles.length == 1) {
      context.go('/home');
    } else {
      context.pop();
    }
    GFeedback.success(context, '${vehicle.title} added to your garage');
  }

  /// A car that is not in the catalogue, typed in by hand.
  ///
  /// Without this a customer with an older import or a rare model had no way
  /// past the Brand step, and the router will not let anyone in without a
  /// vehicle — they were locked out of the app. The car goes on through the
  /// same fuel, gearbox and details steps as any other, as a catalogue entry
  /// with the id `custom`, which every photo and logo lookup already treats
  /// as "draw the body type" and "draw a monogram".
  ///
  /// [askBrand] when the brand itself is missing (or was typed in before),
  /// with [brandHint] — whatever they had searched for — filled in.
  Future<void> _addUnlisted({
    required bool askBrand,
    String brandHint = '',
  }) async {
    final typed = _model?.id == 'custom' ? _model : null;
    final picked = await GFeedback.sheet<_UnlistedCar>(
      context,
      title: askBrand ? 'Add your car' : 'Add your ${_brand?.name ?? ''} model',
      subtitle: 'Type it as it reads on your RC',
      child: _UnlistedCarSheet(
        askBrand: askBrand,
        brand: brandHint,
        model: typed?.name ?? '',
        body: typed?.body,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (askBrand) {
        _brand = VehicleBrand(id: 'custom', name: picked.brand, logoUrl: '');
      }
      _model = VehicleModel(
        id: 'custom',
        brandId: _brand?.id ?? 'custom',
        name: picked.model,
        body: picked.body,
      );
      _variant = null;
    });
    _goto(2);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final firstRun = ref.watch(vehiclesProvider).isEmpty && !_editing;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: p.canvas,
        appBar: GHeader(
          title: _editing ? 'Edit vehicle' : 'Add your vehicle',
          subtitle: _editing ? null : _labels[_step],
          onBack: _back,
          showBack: !firstRun || _step > 0,
          actions: [
            if (firstRun && _step == 0)
              GButton.ghost(
                label: 'Skip',
                size: GButtonSize.sm,
                onPressed: () => GFeedback.info(context,
                    'A vehicle is needed before you can book a service.'),
              ),
          ],
          bottom: _editing
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.page, Gap.xs, Gap.page, Gap.lg),
                  child: GStepProgress(
                      step: _step, total: 4, labels: _labels),
                ),
        ),
        body: PageView(
          controller: _page,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _BrandStep(
              selected: _brand,
              onSelect: (b) {
                setState(() {
                  _brand = b;
                  _model = null;
                });
                _goto(1);
              },
              onUnlisted: (query) =>
                  _addUnlisted(askBrand: true, brandHint: query),
            ),
            _ModelStep(
              brand: _brand,
              selected: _model,
              onSelect: (m) {
                setState(() {
                  _model = m;
                  _variant = null;
                });
                _goto(2);
              },
              onUnlisted: () => _addUnlisted(
                askBrand: _brand?.id == 'custom',
                brandHint: _brand?.id == 'custom' ? _brand!.name : '',
              ),
            ),
            _ConfigStep(
              model: _model,
              fuel: _fuel,
              transmission: _transmission,
              year: _year,
              onFuel: (f) => setState(() => _fuel = f),
              onTransmission: (t) => setState(() => _transmission = t),
              onYear: (y) => setState(() => _year = y),
              onNext: () => _goto(3),
            ),
            _DetailsStep(
              brand: _brand,
              model: _model,
              fuel: _fuel,
              transmission: _transmission,
              year: _year,
              reg: _reg,
              odo: _odo,
              vin: _vin,
              variant: _variant,
              insurance: _insurance,
              puc: _puc,
              onVariant: (v) => setState(() => _variant = v),
              onInsurance: (d) => setState(() => _insurance = d),
              onPuc: (d) => setState(() => _puc = d),
              onChanged: () => setState(() {}),
            ),
          ],
        ),
        bottomNavigationBar: _step == 3
            ? GBottomBar(
                child: GButton.accent(
                  label: _editing ? 'Save changes' : 'Add vehicle',
                  icon: _editing ? Icons.check_rounded : Icons.add_rounded,
                  onPressed: _detailsValid ? _save : null,
                ),
              )
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — brand
// ---------------------------------------------------------------------------

class _BrandStep extends StatefulWidget {
  const _BrandStep({
    required this.selected,
    required this.onSelect,
    required this.onUnlisted,
  });

  final VehicleBrand? selected;
  final ValueChanged<VehicleBrand> onSelect;

  /// "My car's brand isn't listed", with whatever is in the search box.
  final ValueChanged<String> onUnlisted;

  @override
  State<_BrandStep> createState() => _BrandStepState();
}

class _BrandStepState extends State<_BrandStep> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final q = _query.trim().toLowerCase();
    final all = Seed.brands
        .where((b) => q.isEmpty || b.name.toLowerCase().contains(q))
        .toList();
    final popular = all.where((b) => b.popular).toList();
    final rest = all.where((b) => !b.popular).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
            child: GSearchBar(
              hint: 'Search 18 brands',
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              onClear: _query.isEmpty
                  ? null
                  : () {
                      _search.clear();
                      setState(() => _query = '');
                    },
            ),
          ),
        ),
        // Above the lists, not at the end of them: the customer who needs it
        // is the one who has just not found their brand, and should not have
        // to scroll past eighteen others to learn there is a way through.
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
            child: _UnlistedRow(
              title: "My car's brand isn't listed",
              subtitle: 'Type in the brand and model yourself',
              onTap: () => widget.onUnlisted(_query.trim()),
            ),
          ),
        ),
        if (all.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: GEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No brand matched',
              message:
                  'Try a shorter search, or pick the closest brand — you can '
                  'correct the details in the next step.',
            ),
          ),
        if (popular.isNotEmpty) ...[
          _sectionHeader(context, 'Popular in your city'),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            sliver: SliverGrid(
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: Gap.md,
                crossAxisSpacing: Gap.md,
                mainAxisExtent: BrandTile.height(
                  context,
                  (MediaQuery.sizeOf(context).width -
                          Gap.page * 2 -
                          Gap.md * 2) /
                      3,
                ),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => Entrance(
                  index: i,
                  stagger: const Duration(milliseconds: 35),
                  child: BrandTile(
                    brand: popular[i],
                    selected: popular[i].id == widget.selected?.id,
                    onTap: () => widget.onSelect(popular[i]),
                  ),
                ),
                childCount: popular.length,
              ),
            ),
          ),
        ],
        if (rest.isNotEmpty) ...[
          _sectionHeader(context, 'All brands'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
            sliver: SliverList.separated(
              itemCount: rest.length,
              separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
              itemBuilder: (context, i) => Entrance(
                index: i,
                stagger: const Duration(milliseconds: 25),
                child: Pressable(
                  onTap: () => widget.onSelect(rest[i]),
                  child: Container(
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: R.all(R.md),
                      border: Border.all(color: p.line),
                    ),
                    child: Row(
                      children: [
                        BrandBadge(brand: rest[i], size: 38),
                        const SizedBox(width: Gap.md),
                        Expanded(
                            child: Text(rest[i].name,
                                style: AppType.labelL.c(p.ink))),
                        Icon(Icons.chevron_right_rounded,
                            color: p.inkFaint, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) =>
      SliverToBoxAdapter(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
          child: Text(title.toUpperCase(),
              style: AppType.over.c(context.c.inkFaint)),
        ),
      );
}

// ---------------------------------------------------------------------------
// Step 2 — model
// ---------------------------------------------------------------------------

class _ModelStep extends StatelessWidget {
  const _ModelStep({
    required this.brand,
    required this.selected,
    required this.onSelect,
    required this.onUnlisted,
  });

  final VehicleBrand? brand;
  final VehicleModel? selected;
  final ValueChanged<VehicleModel> onSelect;

  /// "My model isn't listed".
  final VoidCallback onUnlisted;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (brand == null) {
      return const GEmptyState(
        icon: Icons.directions_car_rounded,
        title: 'Pick a brand first',
        message: 'Go back a step and choose the manufacturer.',
      );
    }
    final models = Seed.modelsOf(brand!.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      children: [
        Row(
          children: [
            BrandBadge(brand: brand!, size: 44),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brand!.name, style: AppType.h1.c(p.ink)),
                  Text(
                      models.isEmpty
                          ? 'Added by hand'
                          : '${models.length} models serviced',
                      style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        _UnlistedRow(
          title: selected?.id == 'custom'
              ? 'Change ${selected!.name}'
              : "My model isn't listed",
          subtitle: 'Type in the model and pick its body type',
          onTap: onUnlisted,
        ),
        const SizedBox(height: Gap.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: Gap.md,
            crossAxisSpacing: Gap.md,
            mainAxisExtent: 152,
          ),
          itemCount: models.length,
          itemBuilder: (context, i) {
            final m = models[i];
            final isSel = m.id == selected?.id;
            return Entrance(
              index: i,
              stagger: const Duration(milliseconds: 35),
              child: Pressable(
                onTap: () => onSelect(m),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: R.all(R.lg),
                    border: Border.all(
                        color: isSel ? p.accent : p.line,
                        width: isSel ? 1.8 : 1),
                    boxShadow: Shadows.soft(p),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A real photograph of the car, so people recognise
                      // their own model instead of reading a list of names.
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            GImage(
                              url: Media.carPhoto(m.id, body: m.body),
                              radius: 0,
                              fallbackIcon: _bodyIcon(m.body),
                              tint: brand!.color,
                            ),
                            if (isSel)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                    color: p.accent.withValues(alpha: 0.14)),
                              ),
                            if (isSel)
                              Positioned(
                                top: Gap.sm,
                                right: Gap.sm,
                                child: Container(
                                  height: 24,
                                  width: 24,
                                  decoration: BoxDecoration(
                                      color: p.accent, shape: BoxShape.circle),
                                  child: Icon(Icons.check_rounded,
                                      size: 15, color: p.onAccent),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.md, Gap.sm, Gap.md, Gap.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: AppType.h3.c(isSel ? p.accentInk : p.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(m.body.label,
                                style: AppType.labelS.c(p.inkMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The way out of the catalogue on the Brand and Model steps — a row in the
/// same frame as the brand list, so it reads as one more choice rather than
/// as an error.
class _UnlistedRow extends StatelessWidget {
  const _UnlistedRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: R.all(R.sm),
              ),
              child: Icon(Icons.edit_rounded, size: 18, color: p.accentInk),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.labelL.c(p.ink)),
                  Text(subtitle, style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.inkFaint, size: 20),
          ],
        ),
      ),
    );
  }
}

/// What the hand-typed form hands back.
typedef _UnlistedCar = ({String brand, String model, BodyType body});

/// Brand (when it is the brand that is missing), model and body type for a
/// car the catalogue does not have.
///
/// The body type is asked for rather than guessed: it picks the photo the
/// rest of the app shows for the car and travels to the workshop with it,
/// and a made-up "Hatchback" on somebody's SUV is exactly the sort of
/// invented detail this page has stopped writing.
class _UnlistedCarSheet extends StatefulWidget {
  const _UnlistedCarSheet({
    required this.askBrand,
    this.brand = '',
    this.model = '',
    this.body,
  });

  final bool askBrand;
  final String brand;
  final String model;
  final BodyType? body;

  @override
  State<_UnlistedCarSheet> createState() => _UnlistedCarSheetState();
}

class _UnlistedCarSheetState extends State<_UnlistedCarSheet> {
  late final _brand = TextEditingController(text: widget.brand);
  late final _model = TextEditingController(text: widget.model);
  late BodyType? _body = widget.body;

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    super.dispose();
  }

  bool get _ready =>
      (!widget.askBrand || _brand.text.trim().isNotEmpty) &&
      _model.text.trim().isNotEmpty &&
      _body != null;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          Gap.page,
          Gap.lg,
          Gap.page,
          Gap.h1 +
              MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.askBrand) ...[
            GField(
              label: 'Brand',
              hint: 'e.g. Chevrolet',
              controller: _brand,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 40,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Gap.lg),
          ],
          GField(
            label: 'Model',
            hint: 'e.g. Beat LT',
            controller: _model,
            autofocus: !widget.askBrand,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.lg),
          Text('Body type', style: AppType.labelM.c(p.inkSoft)),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final b in BodyType.values)
                _OptionChip(
                  label: b.label,
                  icon: _bodyIcon(b),
                  selected: _body == b,
                  onTap: () => setState(() => _body = b),
                ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          GButton.accent(
            label: 'Continue',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: _ready
                ? () => Navigator.of(context).pop<_UnlistedCar>((
                      brand: _brand.text.trim(),
                      model: _model.text.trim(),
                      body: _body!,
                    ))
                : null,
          ),
        ],
      ),
    );
  }
}

IconData _bodyIcon(BodyType b) => switch (b) {
      BodyType.hatchback => Icons.directions_car_filled_rounded,
      BodyType.sedan => Icons.directions_car_rounded,
      BodyType.suv => Icons.airport_shuttle_rounded,
      BodyType.muv => Icons.airport_shuttle_rounded,
      BodyType.luxury => Icons.workspace_premium_rounded,
      BodyType.ev => Icons.electric_car_rounded,
    };

// ---------------------------------------------------------------------------
// Step 3 — configuration
// ---------------------------------------------------------------------------

class _ConfigStep extends StatelessWidget {
  const _ConfigStep({
    required this.model,
    required this.fuel,
    required this.transmission,
    required this.year,
    required this.onFuel,
    required this.onTransmission,
    required this.onYear,
    required this.onNext,
  });

  final VehicleModel? model;
  final FuelType? fuel;
  final Transmission? transmission;
  final int year;
  final ValueChanged<FuelType> onFuel;
  final ValueChanged<Transmission> onTransmission;
  final ValueChanged<int> onYear;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final years = List.generate(
        26, (i) => DateTime.now().year - i);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xxl),
            children: [
              Entrance(
                child: Text('How is it specced?', style: AppType.d3.c(p.ink)),
              ),
              const SizedBox(height: Gap.xs),
              Entrance(
                index: 1,
                child: Text(
                  'Fuel and gearbox change which oils, filters and parts we '
                  'stock for your visit.',
                  style: AppType.bodyM.c(p.inkMuted),
                ),
              ),
              const SizedBox(height: Gap.xxl),
              Entrance(
                index: 2,
                child: _group(
                  context,
                  'Fuel type',
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      for (final f in FuelType.values)
                        _OptionChip(
                          label: f.label,
                          icon: f.icon,
                          selected: fuel == f,
                          onTap: () => onFuel(f),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gap.xxl),
              Entrance(
                index: 3,
                child: _group(
                  context,
                  'Transmission',
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      for (final t in Transmission.values)
                        _OptionChip(
                          label: t.label,
                          selected: transmission == t,
                          onTap: () => onTransmission(t),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gap.xxl),
              Entrance(
                index: 4,
                child: _group(
                  context,
                  'Manufacturing year',
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: years.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
                      itemBuilder: (context, i) => _OptionChip(
                        label: '${years[i]}',
                        selected: years[i] == year,
                        onTap: () => onYear(years[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        GBottomBar(
          child: GButton.accent(
            label: 'Continue',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed:
                fuel != null && transmission != null ? onNext : null,
          ),
        ),
      ],
    );
  }

  Widget _group(BuildContext context, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppType.over.c(context.c.inkFaint)),
        const SizedBox(height: Gap.md),
        child,
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final fg = selected ? (p.isDark ? p.canvas : Colors.white) : p.inkSoft;
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        decoration: BoxDecoration(
          color: selected ? p.ink : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: selected ? p.ink : p.line),
          boxShadow: selected ? Shadows.soft(p) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: AppType.labelM.c(fg)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4 — details
// ---------------------------------------------------------------------------

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.brand,
    required this.model,
    required this.fuel,
    required this.transmission,
    required this.year,
    required this.reg,
    required this.odo,
    required this.vin,
    required this.variant,
    required this.insurance,
    required this.puc,
    required this.onVariant,
    required this.onInsurance,
    required this.onPuc,
    required this.onChanged,
  });

  final VehicleBrand? brand;
  final VehicleModel? model;
  final FuelType? fuel;
  final Transmission? transmission;
  final int year;
  final TextEditingController reg;
  final TextEditingController odo;
  final TextEditingController vin;
  final String? variant;
  final DateTime? insurance;
  final DateTime? puc;
  final ValueChanged<String?> onVariant;
  final ValueChanged<DateTime?> onInsurance;
  final ValueChanged<DateTime?> onPuc;
  final VoidCallback onChanged;

  Future<void> _pickDate(
      BuildContext context, DateTime? current, ValueChanged<DateTime?> set) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now.add(const Duration(days: 90)),
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) set(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final variants = model?.variants ?? const <String>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      children: [
        Entrance(
          child: Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              gradient: p.inverseGradient,
              borderRadius: R.all(R.lg),
            ),
            child: Row(
              children: [
                GImage(
                  url: Media.carPhoto(model?.id, body: model?.body),
                  height: 52,
                  width: 74,
                  radius: R.sm,
                  fallbackIcon: _bodyIcon(model?.body ?? BodyType.hatchback),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${brand?.name ?? ''} ${model?.name ?? ''}'.trim(),
                          style: AppType.h2.c(p.onInverse)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          fuel?.label,
                          transmission?.label,
                          '$year',
                        ].whereType<String>().join(' • '),
                        style: AppType.labelS
                            .c(p.onInverse.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.xxl),
        Entrance(
          index: 1,
          child: GField(
            label: 'Registration number',
            hint: 'PB65 AB 1234',
            controller: reg,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => onChanged(),
            inputFormatters: [
              LengthLimitingTextInputFormatter(13),
              UpperCaseFormatter(),
            ],
            prefix: Icon(Icons.confirmation_number_outlined,
                size: 19, color: p.inkMuted),
            helper: 'Printed on your RC and number plate',
          ),
        ),
        if (variants.isNotEmpty) ...[
          const SizedBox(height: Gap.xl),
          Entrance(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Variant (optional)',
                    style: AppType.labelM.c(p.inkSoft)),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final v in variants)
                      _OptionChip(
                        label: v,
                        selected: variant == v,
                        onTap: () => onVariant(variant == v ? null : v),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Gap.xl),
        Entrance(
          index: 3,
          child: GField(
            label: 'Current odometer reading',
            hint: '42300',
            controller: odo,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
            prefix: Icon(Icons.speed_rounded, size: 19, color: p.inkMuted),
            suffix: Text('km', style: AppType.labelM.c(p.inkMuted)),
            helper: 'Helps us recommend the right service interval',
          ),
        ),
        const SizedBox(height: Gap.xl),
        Entrance(
          index: 4,
          child: Row(
            children: [
              Expanded(
                child: GPickerField(
                  label: 'Insurance expiry',
                  value: insurance == null ? null : Fmt.date(insurance!),
                  placeholder: 'Optional',
                  leadingIcon: Icons.verified_user_outlined,
                  icon: Icons.calendar_month_rounded,
                  onTap: () => _pickDate(context, insurance, onInsurance),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: GPickerField(
                  label: 'PUC expiry',
                  value: puc == null ? null : Fmt.date(puc!),
                  placeholder: 'Optional',
                  leadingIcon: Icons.eco_outlined,
                  icon: Icons.calendar_month_rounded,
                  onTap: () => _pickDate(context, puc, onPuc),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        Entrance(
          index: 5,
          child: GField(
            label: 'VIN / chassis number (optional)',
            hint: 'MA3EYD32S00123456',
            controller: vin,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(17),
              UpperCaseFormatter(),
            ],
            prefix: Icon(Icons.tag_rounded, size: 19, color: p.inkMuted),
            helper: 'Lets us order the exact parts for your car',
          ),
        ),
        const SizedBox(height: Gap.xxl),
        Entrance(
          index: 6,
          child: Row(
            children: [
              Icon(Icons.lock_rounded, size: 15, color: p.inkFaint),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  'Vehicle details stay on your account and are shared only with '
                  'the workshop handling your booking.',
                  style: AppType.bodyS.c(p.inkFaint),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Keeps registration and VIN fields upper-case as the user types.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
