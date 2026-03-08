import 'package:flutter/material.dart';
import '../config/theme.dart';

/// CareSoul logo widget – heart + medical cross icon with app name.
/// Modern, minimal, clean rounded design.
class CareSoulLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showSubtitle;

  const CareSoulLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo image container
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: [
              BoxShadow(
                color: CareSoulTheme.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.25),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.15),
          Text(
            'CareSoul',
            style: TextStyle(
              fontSize: size * 0.32,
              fontWeight: FontWeight.w800,
              color: CareSoulTheme.primary,
              letterSpacing: 1.0,
            ),
          ),
          if (showSubtitle) ...[
            const SizedBox(height: 2),
            Text(
              'Smart Medication Assistant',
              style: TextStyle(
                fontSize: size * 0.13,
                color: CareSoulTheme.textSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
