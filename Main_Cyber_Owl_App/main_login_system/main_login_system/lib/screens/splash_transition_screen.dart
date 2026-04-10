import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/theme_manager.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

class SplashTransitionScreen extends StatefulWidget {
  const SplashTransitionScreen({super.key});

  @override
  State<SplashTransitionScreen> createState() => _SplashTransitionScreenState();
}

class _SplashTransitionScreenState extends State<SplashTransitionScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;

  // Animation Variables
  late Animation<double> _logoScaleIn;
  late Animation<double> _textSequenceOpacity;
  late Animation<Offset> _textSequenceSlide;
  late Animation<Offset> _logoPositionShift;

  // Phase 2: Bloom & Warp
  late Animation<double> _petalExpansion;

  late Animation<double> _finalWarpScale;
  late Animation<double> _shimmerWave;

  // Particles
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Initialize Background Particles
    for (int i = 0; i < 40; i++) {
      _particles.add(Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2 + 1,
        speed: _random.nextDouble() * 0.15 + 0.05,
        theta: _random.nextDouble() * 2 * math.pi,
        opacity: _random.nextDouble() * 0.5 + 0.1,
      ));
    }

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Total Duration: ~5 Seconds for the full cinematic effect
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    // 1. Logo fades in/scales up (0.0 - 0.2)
    _logoScaleIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOutBack),
      ),
    );

    // 2. Logo Shift Logic
    _logoPositionShift = TweenSequence<Offset>([
      TweenSequenceItem(tween: ConstantTween(const Offset(-40, 0)), weight: 65),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(-40, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 35),
    ]).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.7, curve: Curves.linear),
    ));

    // 3. Text Sequence (Appear -> Hold -> Disappear)
    _textSequenceSlide = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: const Offset(-100, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 30),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(-100, 0))
              .chain(CurveTween(curve: Curves.easeInBack)),
          weight: 30),
    ]).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.5, curve: Curves.linear),
    ));

    _textSequenceOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.5, curve: Curves.linear),
    ));

    // 4. "Wings" Flap Disabled
    _petalExpansion = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 1.0),
      ),
    );

    // 5. Final Warp Expansion (Disabled - logic kept for structure but effect removed)
    _finalWarpScale = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.9, 1.0, curve: Curves.easeInExpo),
      ),
    );

    // ... (keep previous animations)
    // ... (keep previous animations)

    // 6. Shimmer Wave (During Hold Phase)
    _shimmerWave = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.32, 0.45, curve: Curves.easeInOut),
      ),
    );

    _mainController.forward();
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });
  }

  Widget _buildTextContent(Color textColor, Color guardTextColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. One Line: CYBER OWL
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              "CYBER",
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w300,
                height: 0.9,
                color: textColor,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "OWL",
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                height: 0.9,
                letterSpacing: 4.0,
                color: guardTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 2. Slogan
        Text(
          "The silent eyes that capture & listens everything",
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 1.2,
            color: textColor.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _navigateToHome() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = themeManager.themeValue;

    // Theme-aware colors
    final backgroundColor =
        AppColors.interpolate(Colors.white, Colors.black, t);
    final particleColor = AppColors.interpolate(Colors.black, Colors.white, t);
    final textColor = AppColors.interpolate(Colors.black, Colors.white, t);
    final guardTextColor =
        AppColors.interpolate(AppColors.accentBlue, Colors.blueAccent[100]!, t);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 0. Background Particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlePainter(
                    _particles, _particleController.value, particleColor),
                size: Size.infinite,
              );
            },
          ),

          // Main Animation Stack
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // TEXT (Arises from logo and goes back)
                  Positioned(
                    left: MediaQuery.of(context).size.width / 2 +
                        10, // Reduced gap further (was 30)
                    child: Transform.translate(
                      offset: _textSequenceSlide.value,
                      child: Opacity(
                        opacity: _textSequenceOpacity.value,
                        child: Stack(
                          children: [
                            // Base Layer (Visible Text)
                            _buildTextContent(textColor, guardTextColor),

                            // Overlay Layer (Purple Gradient Wave)
                            AnimatedBuilder(
                              animation: _shimmerWave,
                              builder: (context, child) {
                                return ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) {
                                    double t = _shimmerWave.value;
                                    return LinearGradient(
                                      begin: const Alignment(-1.0, 0.0),
                                      end: const Alignment(1.0, 0.0),
                                      colors: [
                                        Colors.transparent,
                                        Colors.purpleAccent.withValues(
                                            alpha: 0.8), // Purple Wave
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        t - 0.2, // Tighter wave
                                        t,
                                        t + 0.2,
                                      ],
                                      transform: const GradientRotation(0.2),
                                    ).createShader(bounds);
                                  },
                                  child: _buildTextContent(
                                      textColor, guardTextColor),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // LOGO (Cyber Owl)
                  Transform.translate(
                    offset: _logoPositionShift.value,
                    child: Transform.scale(
                      scale: _finalWarpScale.value * _logoScaleIn.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Breathing/Wing Spread Simulation
                          Transform.scale(
                            scale: 1.0 +
                                (_petalExpansion.value *
                                    0.2), // Subtle expand/contract
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors
                                    .transparent, // Remove background container
                              ),
                              child: SvgPicture.asset(
                                'assets/logo/cyber_owl.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// Particle Class
class Particle {
  double x;
  double y;
  double size;
  double speed;
  double theta;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.theta,
    required this.opacity,
  });
}

// Particle Painter - Theme-aware
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;
  final Color particleColor;

  ParticlePainter(this.particles, this.animationValue, this.particleColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = particleColor;

    for (var particle in particles) {
      double dy = (particle.y - (animationValue * particle.speed)) % 1.0;
      if (dy < 0) dy += 1.0;

      final dx = particle.x +
          (math.sin(animationValue * 2 * math.pi + particle.theta) * 0.01);

      paint.color = particleColor.withValues(alpha: particle.opacity);
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
