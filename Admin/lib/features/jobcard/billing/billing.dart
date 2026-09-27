import 'package:flutter/material.dart';

import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import 'bill_jobs_page.dart';
import 'bill_lube_page.dart';
import 'bill_spare_page.dart';

export 'bill_jobs_page.dart';
export 'bill_lube_page.dart';
export 'bill_spare_page.dart';
export 'master_form_page.dart';

/// Open the billing screen for [kind] and wait for what was picked.
///
/// The three screens are separate widgets on purpose — they share a masthead
/// and a commit bar and nothing else — but every caller wants the same thing
/// from them, which is a list of lines or nothing. This is that one door, so
/// the job card, the counter sale and the purchase order do not each carry a
/// switch over the three.
///
/// Returns null when the counter backed out, which is not the same as an
/// empty list and must not be treated as one: backing out leaves the bill
/// alone, and the Put-on-bill button is disabled until there is something to
/// put on it.
Future<List<LineItem>?> openBillPicker(BuildContext context, LineKind kind) =>
    Navigator.of(context).push<List<LineItem>>(
      MaterialPageRoute(
        builder: (_) => switch (kind) {
          LineKind.job => const BillJobsPage(),
          LineKind.spare => const BillSparePage(),
          LineKind.lube => const BillLubePage(),
        },
      ),
    );
