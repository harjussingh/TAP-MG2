import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// One selectable ingredient in the builder.
///
/// A full-width row rather than a grid tile, because the row has space for the
/// name, the extra charge and the energy on one line, and because a list
/// scanned top to bottom is faster to read than a grid scanned in two
/// directions. Selection is shown three ways at once — tinted fill, coloured
/// border and a filled check — so it never depends on colour alone.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.emoji,
    required this.name,
    required this.isSelected,
    required this.onTap,
    this.priceLabel,
    this.detail,
    this.available = true,
    this.multiSelect = false,
  });

  final String emoji;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  /// The extra charge, e.g. "+ $2.00". Null when the option is included.
  final String? priceLabel;

  /// A second line, usually the energy contribution.
  final String? detail;

  /// Sold-out options stay visible so the customer understands why a choice
  /// is unavailable, which is what the client asked for.
  final bool available;

  /// Draws a square check for a group that allows several choices, and a
  /// circle for a group that allows one.
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);

    final selected = isSelected && available;
    final border = selected ? AppColors.primary : AppColors.border;

    return Semantics(
      selected: selected,
      enabled: available,
      button: true,
      label: '$name${priceLabel == null ? '' : ', $priceLabel'}'
          '${available ? '' : ', out of stock'}',
      child: Opacity(
        opacity: available ? 1 : 0.5,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Material(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            child: InkWell(
              onTap: available ? onTap : null,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border:
                      Border.all(color: border, width: selected ? 1.8 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusInput),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: AppTypography.body
                                  .copyWith(fontWeight: FontWeight.w600)),
                          if (!available)
                            Text('Out of stock',
                                style: AppTypography.label
                                    .copyWith(color: AppColors.error))
                          else if (priceLabel != null || detail != null)
                            Text(
                              [
                                if (priceLabel != null) priceLabel!,
                                if (detail != null) detail!,
                              ].join('  ·  '),
                              style: AppTypography.secondary,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _Check(selected: selected, square: multiSelect),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected, required this.square});

  final bool selected;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(7) : null,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: 1.8,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 15, color: AppColors.onPrimary)
          : null,
    );
  }
}
