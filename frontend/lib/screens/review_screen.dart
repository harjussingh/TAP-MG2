import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/filter_chip_bar.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.order});

  final Order order;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const _tags = [
    'Taste \u{1F60B}',
    'Speed \u26A1',
    'Accuracy \u2713',
    'App experience \u{1F4F1}',
  ];

  int _rating = 0;
  final Set<String> _chosen = {};
  final TextEditingController _comment = TextEditingController();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _comment.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    AppScope.of(context).rateOrder(widget.order, _rating);
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    if (_submitted) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('\u{1F64F}', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Thanks for the feedback',
                      style: AppTypography.sectionHeading),
                  const SizedBox(height: AppSpacing.sm),
                  Text('It helps us tune the machine and the menu.',
                      textAlign: TextAlign.center,
                      style: AppTypography.secondary),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context)
                          .popUntil((route) => route.isFirst),
                      child: const Text('Back to menu'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ORDER #${widget.order.id}',
                style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary, letterSpacing: 1.2)),
            const Text('How was your poke? \u{1F963}'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _Panel(
            child: Column(
              children: [
                Text('Overall rating',
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        iconSize: 40,
                        onPressed: () => setState(() => _rating = i),
                        icon: Icon(
                          i <= _rating ? Icons.star : Icons.star_border,
                          color:
                              i <= _rating ? AppColors.primary : AppColors.border,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _Panel(
            label: 'What stood out?',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final tag in _tags)
                  SelectPill(
                    label: tag,
                    isSelected: _chosen.contains(tag),
                    onTap: () => setState(() {
                      if (!_chosen.remove(tag)) _chosen.add(tag);
                    }),
                  ),
              ],
            ),
          ),
          _Panel(
            label: 'Anything else? (optional)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _comment,
                  maxLines: 4,
                  maxLength: 300,
                  style: AppTypography.body,
                  decoration: const InputDecoration(
                    hintText: 'Tell us more about your experience...',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('${_comment.text.length}/300',
                    style: AppTypography.secondary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Disabled until a rating is given, since a review without one
          // carries no information.
          ElevatedButton(
            onPressed: _rating == 0 ? null : _submit,
            child: const Text('Submit review'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Skip for now'),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({this.label, required this.child});

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );
  }
}
