import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class SosButton extends StatefulWidget {
  final VoidCallback onTrigger;
  final bool isActive;

  const SosButton({Key? key, required this.onTrigger, this.isActive = false})
    : super(key: key);

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: GestureDetector(
        onTap: widget.onTrigger,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: widget.isActive
                  ? [AppColors.primaryLight, AppColors.primaryDark]
                  : [AppColors.primary, AppColors.primaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.6),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isActive
                    ? Icons.warning_amber_rounded
                    : Icons.sos_rounded,
                size: 72,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isActive ? 'SOS BROADCASTING' : 'PRESS FOR SOS',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
