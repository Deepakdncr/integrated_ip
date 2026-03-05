import 'package:flutter/material.dart';
import '../config/theme.dart';

/// CareSoul logo widget – heart + medical cross, with app name.
class CareSoulLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const CareSoulLogo({super.key, this.size = 80, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [CareSoulTheme.primaryLight, CareSoulTheme.primaryDark],
            ),
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: [
              BoxShadow(
                color: CareSoulTheme.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.favorite,
                  size: size * 0.55,
                  color: Colors.white.withValues(alpha: 0.3)),
              Icon(Icons.add, size: size * 0.4, color: Colors.white),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            'CareSoul',
            style: TextStyle(
              fontSize: size * 0.3,
              fontWeight: FontWeight.w700,
              color: CareSoulTheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            'Smart Medication Assistant',
            style: TextStyle(
              fontSize: size * 0.14,
              color: CareSoulTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
