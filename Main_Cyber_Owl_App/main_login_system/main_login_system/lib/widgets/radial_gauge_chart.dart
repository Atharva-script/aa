import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Animated radial gauge chart for threat level visualization
class RadialGaugeChart extends StatefulWidget {
  final double value; // 0-100
  final String label;
  final double themeValue;
  final double size;

  const RadialGaugeChart({
    super.key,
    required this.value,
    this.label = 'Threat Level',
    required this.themeValue,
    this.size = 200,
  });

  @override
  State<RadialGaugeChart> createState() => _RadialGaugeChartState();
}

class _RadialGaugeChartState extends State<RadialGaugeChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _currentValue = _animation.value;
        });
      });
    _controller.forward();
  }

  @override
  void didUpdateWidget(RadialGaugeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _currentValue, end: widget.value)
          .animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getGaugeColor(double value) {
    if (value < 30) return AppColors.accentGreen;
    if (value < 60) return AppColors.warningDark;
    if (value < 80) return AppColors.accentOrange;
    return AppColors.accentRed;
  }

  String _getThreatLabel(double value) {
    if (value < 20) return 'SAFE';
    if (value < 40) return 'LOW';
    if (value < 60) return 'MODERATE';
    if (value < 80) return 'HIGH';
    return 'CRITICAL';
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.getSurface(widget.themeValue);
    final textColor = AppColors.getTextPrimary(widget.themeValue);
    final secondaryTextColor = AppColors.getTextSecondary(widget.themeValue);
    final gaugeColor = _getGaugeColor(_currentValue);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.getDivider(widget.themeValue).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: gaugeColor.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: AppTextStyles.h3.copyWith(color: textColor),
          ),
          Text(
            'Real-time threat assessment',
            style: AppTextStyles.subBody
                .copyWith(fontSize: 12, color: secondaryTextColor),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background arc
                    CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _GaugeBackgroundPainter(
                        themeValue: widget.themeValue,
                      ),
                    ),
                    // Value arc
                    CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _GaugeValuePainter(
                        value: _currentValue,
                        color: gaugeColor,
                      ),
                    ),
                    // Center content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_currentValue.toInt()}%',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: gaugeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getThreatLabel(_currentValue),
                            style: TextStyle(
                              color: gaugeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(
                  'Safe', AppColors.accentGreen, secondaryTextColor),
              _buildLegendItem(
                  'Moderate', AppColors.warningDark, secondaryTextColor),
              _buildLegendItem(
                  'Critical', AppColors.accentRed, secondaryTextColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: textColor, fontSize: 10),
        ),
      ],
    );
  }
}

class _GaugeBackgroundPainter extends CustomPainter {
  final double themeValue;

  _GaugeBackgroundPainter({required this.themeValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    final paint = Paint()
      ..color = AppColors.isDark(themeValue)
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw 240 degree arc (from 150 to 390 degrees)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      (150 * math.pi) / 180,
      (240 * math.pi) / 180,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GaugeValuePainter extends CustomPainter {
  final double value;
  final Color color;

  _GaugeValuePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Create gradient
    const gradient = SweepGradient(
      startAngle: (150 * math.pi) / 180,
      endAngle: (390 * math.pi) / 180,
      colors: [
        AppColors.accentGreen,
        AppColors.warningDark,
        AppColors.accentOrange,
        AppColors.accentRed,
      ],
      stops: [0.0, 0.3, 0.6, 1.0],
    );

    final paint = Paint()
      ..shader =
          gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Calculate sweep angle based on value (0-100 -> 0-240 degrees)
    final sweepAngle = (value / 100) * 240;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      (150 * math.pi) / 180,
      (sweepAngle * math.pi) / 180,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugeValuePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
