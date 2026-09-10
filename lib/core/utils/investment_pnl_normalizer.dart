/// Converts investment P/L records into the canonical signed representation.
///
/// Older Firestore records may store a positive absolute amount for losses.
/// Keeping this conversion pure makes those records safe to consume without a
/// destructive migration.
double normalizeInvestmentPnlDiff({
  required double rawDiff,
  required String? pnlType,
}) {
  switch (pnlType?.trim().toLowerCase()) {
    case 'profit':
      return rawDiff.abs();
    case 'loss':
      return -rawDiff.abs();
    default:
      return rawDiff;
  }
}
