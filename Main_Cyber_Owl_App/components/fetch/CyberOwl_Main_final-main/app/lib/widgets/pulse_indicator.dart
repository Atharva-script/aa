import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated pulsing indicator for live monitoring status
class PulseIndicator extends StatefulWidget {
  final bool isActive;
  final double themeValue;
  final String? label;
  final double size;

  const PulseIndicator({
    super.key,
    required this.isActive,
    required this.themeValue,
    this.label,
    this.size = 12,
  });

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(PulseIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.accentGreen;
    final inactiveColor = AppColors.getTextSecondary(widget.themeValue);
    final color = widget.isActive ? activeColor : inactiveColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size * 3,
          height: widget.size * 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              if (widget.isActive)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(
                          width: widget.size,
                          height: widget.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: activeColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              // Core dot
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(width: 8),
          Text(
            widget.label!,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }
}

/// Live monitoring status badge with pulse
class LiveStatusBadge extends StatelessWidget {
  final bool isMonitoring;
  final double themeValue;

  const LiveStatusBadge({
    super.key,
    required this.isMonitoring,
    required this.themeValue,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.accentGreen;
    final inactiveColor = AppColors.getTextSecondary(themeValue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isMonitoring ? activeColor : inactiveColor)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isMonitoring ? activeColor : inactiveColor)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseIndicator(
            isActive: isMonitoring,
            themeValue: themeValue,
            size: 8,
          ),
          const SizedBox(width: 6),
          Text(
            isMonitoring ? 'LIVE' : 'IDLE',
            style: TextStyle(
              color: isMonitoring ? activeColor : inactiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
