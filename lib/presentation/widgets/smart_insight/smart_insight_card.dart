import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/ai_insight_controller.dart';
import '../../../core/models/ai_insight_result.dart';
import '../../../core/models/financial_snapshot.dart';
import '../../../core/utils/theme.dart';
import '../../smart_insight/evidence_presentation.dart';

class SmartInsightCard extends StatefulWidget {
  const SmartInsightCard({super.key});

  @override
  State<SmartInsightCard> createState() => _SmartInsightCardState();
}

class _SmartInsightCardState extends State<SmartInsightCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<AiInsightController>();
      // This only prepares the deterministic snapshot and checks cache. It
      // cannot call Firebase AI; Generate and Refresh remain explicit actions.
      if (controller.status == AiInsightControllerStatus.idle) {
        controller.prepareSnapshot();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AiInsightController>();
    final snapshot = controller.snapshot;
    final visibleInsight = controller.insight ?? controller.cachedInsight;
    final isRefreshing =
        controller.status == AiInsightControllerStatus.generating &&
        visibleInsight != null;

    return Semantics(
      container: true,
      label: 'Smart Insight',
      child: _InsightSurface(
        child: visibleInsight != null && snapshot != null
            ? _InsightContent(
                insight: visibleInsight,
                snapshot: snapshot,
                stale: controller.isStale,
                refreshing: isRefreshing,
                refreshError: controller.refreshError,
                cachedGeneratedAt: controller.cachedGeneratedAt,
                onRefresh: controller.isLoading
                    ? null
                    : () {
                        controller.refreshInsight();
                      },
              )
            : controller.isLoading
            ? const _InitialLoadingState()
            : controller.status == AiInsightControllerStatus.failure
            ? _FailureState(
                message:
                    controller.userFacingError ??
                    'AI insight is temporarily unavailable.',
                onRetry: () {
                  controller.generateInsight();
                },
              )
            : _EmptyState(
                onGenerate: () {
                  controller.generateInsight();
                },
              ),
      ),
    );
  }
}

class _InsightSurface extends StatelessWidget {
  const _InsightSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.extension<AppThemeColors>()!;
    final gradient = isDark
        ? [appColors.authGradientStart, appColors.authGradientEnd]
        : [const Color(0xFFEAF1FF), const Color(0xFFF6ECFF)];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : colors.onSurface.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

class _InsightContent extends StatelessWidget {
  const _InsightContent({
    required this.insight,
    required this.snapshot,
    required this.stale,
    required this.refreshing,
    required this.refreshError,
    required this.cachedGeneratedAt,
    required this.onRefresh,
  });

  final AiInsightResult insight;
  final FinancialSnapshot snapshot;
  final bool stale;
  final bool refreshing;
  final String? refreshError;
  final DateTime? cachedGeneratedAt;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLazy = snapshot.context.mode == FinancialMode.lazy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _InsightHeading(),
            const Spacer(),
            _SeverityChip(severity: insight.severity),
          ],
        ),
        const SizedBox(height: 14),
        if (stale) ...[
          _Notice(
            icon: Icons.history_rounded,
            message:
                'Your financial data has changed since this insight was generated.',
          ),
          const SizedBox(height: 14),
        ],
        Text(
          insight.headline,
          key: const Key('smart-insight-headline'),
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 21,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        _InsightSection(title: 'What happened', text: insight.whatHappened),
        if (!isLazy) ...[
          const SizedBox(height: 14),
          _InsightSection(title: 'Why', text: insight.why),
        ],
        const SizedBox(height: 14),
        _InsightSection(title: 'What you can do', text: insight.action),
        if (refreshing) ...[
          const SizedBox(height: 16),
          const _RefreshProgress(),
        ],
        if (refreshError != null) ...[
          const SizedBox(height: 16),
          _RefreshFailure(message: refreshError!),
        ],
        const SizedBox(height: 18),
        _InsightActions(
          stale: stale,
          cachedGeneratedAt: cachedGeneratedAt,
          onViewEvidence: stale
              ? null
              : () => _showEvidence(context, insight, snapshot),
          onRefresh: onRefresh,
        ),
      ],
    );
  }

  void _showEvidence(
    BuildContext context,
    AiInsightResult result,
    FinancialSnapshot currentSnapshot,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SmartInsightEvidenceSheet(
        evidenceKeys: result.evidenceKeys,
        snapshot: currentSnapshot,
      ),
    );
  }
}

class _InsightHeading extends StatelessWidget {
  const _InsightHeading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: colors.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'SMART INSIGHT',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 12,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGenerate});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InsightHeading(),
        const SizedBox(height: 14),
        Text(
          'Understand your financial picture',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Get an AI explanation of your current financial situation using verified Smart Pocket data.',
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text(
          'AI uses a financial summary calculated by Smart Pocket. Raw transaction notes and account details are not sent.',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('generate-insight-button'),
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Generate Insight'),
          ),
        ),
      ],
    );
  }
}

class _InitialLoadingState extends StatelessWidget {
  const _InitialLoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InsightHeading(),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 14),
              Text(
                'Analysing your verified financial snapshot...',
                key: const Key('smart-insight-loading-copy'),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InsightHeading(),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onSurface, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('retry-insight-button'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Try Again'),
        ),
      ],
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final FinancialSeverity severity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, color, background) = switch (severity) {
      FinancialSeverity.normal => (
        'Normal',
        colors.primary,
        colors.primaryContainer,
      ),
      FinancialSeverity.worthWatching => (
        'Worth Watching',
        colors.secondary,
        colors.secondaryContainer,
      ),
      FinancialSeverity.needsAttention => (
        'Needs Attention',
        colors.error,
        colors.errorContainer,
      ),
    };
    return Semantics(
      label: 'Severity: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          text,
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.onSecondaryContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.onSecondaryContainer,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshProgress extends StatelessWidget {
  const _RefreshProgress();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Refreshing your verified insight...',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

class _RefreshFailure extends StatelessWidget {
  const _RefreshFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Notice(icon: Icons.info_outline_rounded, message: message);
  }
}

class _InsightActions extends StatelessWidget {
  const _InsightActions({
    required this.stale,
    required this.cachedGeneratedAt,
    required this.onViewEvidence,
    required this.onRefresh,
  });

  final bool stale;
  final DateTime? cachedGeneratedAt;
  final VoidCallback? onViewEvidence;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metadata = stale
        ? 'Previous insight'
        : cachedGeneratedAt == null
        ? 'Verified data'
        : 'Updated ${DateFormat.jm().format(cachedGeneratedAt!.toLocal())}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metadata,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
        ),
        const SizedBox(height: 10),
        if (stale) ...[
          Text(
            'Evidence is unavailable for this outdated insight. Refresh to verify the insight against your latest financial data.',
            key: const Key('stale-evidence-unavailable-message'),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onViewEvidence != null)
              OutlinedButton.icon(
                key: const Key('view-evidence-button'),
                onPressed: onViewEvidence,
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('View Evidence'),
              ),
            FilledButton.icon(
              key: const Key('refresh-insight-button'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(stale ? 'Refresh Insight' : 'Refresh'),
            ),
          ],
        ),
      ],
    );
  }
}

class SmartInsightEvidenceSheet extends StatelessWidget {
  const SmartInsightEvidenceSheet({
    super.key,
    required this.evidenceKeys,
    required this.snapshot,
  });

  final List<String> evidenceKeys;
  final FinancialSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final evidence = evidenceKeys
        .map(
          (key) => EvidencePresentationResolver.resolve(
            snapshot: snapshot,
            evidenceKey: key,
          ),
        )
        .whereType<EvidencePresentation>()
        .toList(growable: false);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evidence',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'These values are calculated by Smart Pocket and were used to support this insight.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: evidence.length,
                  separatorBuilder: (_, __) => Divider(
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (_, index) {
                    final item = evidence[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: Text(
                        item.formattedValue,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Verified Data',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Verified Data',
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
