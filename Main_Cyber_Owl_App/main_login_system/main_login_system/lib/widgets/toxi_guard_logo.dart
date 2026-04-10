import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ToxiGuardLogo extends StatelessWidget {
  final double size;
  final bool animate;
  final Animation<double>? rotationAnimation;
  final Color? color;

  const ToxiGuardLogo({
    super.key,
    this.size = 50,
    this.animate = false,
    this.rotationAnimation,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // If an explicit animation controller is provided
    if (rotationAnimation != null) {
      return RotationTransition(
        turns: rotationAnimation!,
        child: _buildLogoImage(),
      );
    }
    // If internal simple animation is requested
    else if (animate) {
      return _SpinningLogo(size: size, color: color);
    }

    return _buildLogoImage();
  }

  Widget _buildLogoImage() {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/logo/cyber_owl.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter:
            color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
      ),
    );
  }
}

class _SpinningLogo extends StatefulWidget {
  final double size;
  final Color? color;

  const _SpinningLogo({required this.size, this.color});

  @override
  State<_SpinningLogo> createState() => _SpinningLogoState();
}

class _SpinningLogoState extends State<_SpinningLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // Slow minimal spin
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: SvgPicture.asset(
          'assets/logo/cyber_owl.svg',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          // ignore: deprecated_member_use
          color: widget.color,
        ),
      ),
    );
  }
}
