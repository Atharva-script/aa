import 'package:flutter/material.dart';


class Skeleton extends StatefulWidget {
  final double? height;
  final double? width;
  final bool isCircle;
  final double borderRadius;

  const Skeleton({
    super.key,
    this.height,
    this.width,
    this.isCircle = false,
    this.borderRadius = 8,
  });

  const Skeleton.rect({
    super.key,
    this.height,
    this.width = double.infinity,
    this.borderRadius = 8,
  })  : isCircle = false;

  const Skeleton.circle({
    super.key,
    required double size,
  })  : height = size,
        width = size,
        isCircle = true,
        borderRadius = 0;

  const Skeleton.text({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 4, 
  }) : isCircle = false;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Detect Brightness to choose colors, consistent with AppColors
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Base colors using the AppColors palette concepts
    // Dark mode: Dark grey surface
    // Light mode: Light grey
    final Color baseColor = isDark 
        ? const Color(0xFF2A2A2A) 
        : const Color(0xFFE0E0E0);
    
    final Color highlightColor = isDark 
        ? const Color(0xFF404040) 
        : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Create a moving gradient
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
             // Calculate the gradient position based on controller value
             // 2.0 range (-1 to 1) allows the gradient to pass completely through
             final double start = _controller.value * 2 - 1; 
             
             return LinearGradient(
              begin: Alignment(start, 0),
              end: Alignment(start + 1, 0), // Gradient spans 1.0 width relative to container
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [
                0.0,
                0.5,
                1.0,
              ],
            ).createShader(bounds);
          },
          child: Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              color: baseColor, // The color here acts as the mask "canvas"
              shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.isCircle ? null : BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
