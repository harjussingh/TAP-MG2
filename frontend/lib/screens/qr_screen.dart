import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/robomos_logo.dart';
import 'continue_as_screen.dart';

/// Entry point. One QR code for the restaurant, so the table number is
/// entered by hand further along the flow.
class QrScreen extends StatelessWidget {
  const QrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.header,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),
              const RobomosWordmark(size: 60),
              const Spacer(),
              _Viewfinder(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ContinueAsScreen()),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Point your camera at the QR code at the entrance counter',
                textAlign: TextAlign.center,
                style: AppTypography.secondary,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _DownloadPrompt(),
                ),
                child: Text('Downloading the app for the first time?',
                    style: AppTypography.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Semantics(
      button: true,
      label: 'Scan the restaurant QR code',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: const Size(220, 220), painter: _CornerPainter()),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                    child: Icon(Icons.qr_code_scanner,
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Tap to scan',
                      style: AppTypography.body.copyWith(color: Colors.white)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 44.0;
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o.translate(dx * len, 0), paint);
      canvas.drawLine(o, o.translate(0, dy * len), paint);
    }
    corner(const Offset(0, 0), 1, 1);
    corner(Offset(size.width, 0), -1, 1);
    corner(Offset(0, size.height), 1, -1);
    corner(Offset(size.width, size.height), -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DownloadPrompt extends StatelessWidget {
  const _DownloadPrompt();

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Get Robomos Poke'),
      content: Text(
        'You need the app to order. It is free on Google Play.',
        style: AppTypography.body,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Not now')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context), child: const Text('Get the app')),
      ],
    );
  }
}
