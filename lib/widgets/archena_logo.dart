import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ArchenaLogo extends StatelessWidget {
  final double size;
  
  const ArchenaLogo({
    super.key,
    this.size = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SvgPicture.asset(
        'assets/images/logo.svg',
        fit: BoxFit.contain,
        placeholderBuilder: (context) => Icon(
          Icons.account_balance, // Icono institucional como fallback
          size: size * 0.8,
          color: Colors.white,
        ),
      ),
    );
  }
}
