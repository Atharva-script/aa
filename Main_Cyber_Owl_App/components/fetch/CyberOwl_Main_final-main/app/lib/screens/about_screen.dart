import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../services/feedback_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_manager.dart';
import '../widgets/toxi_guard_logo.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _feedbackController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await FeedbackService.submitFeedback(_feedbackController.text, _rating);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );
        _feedbackController.clear();
        setState(() => _rating = 5.0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final t = themeManager.themeValue;
        final isDark = themeManager.isDark;
        final backgroundColor = AppColors.getBackground(t);
        final textColor = AppColors.getTextPrimary(t);
        final cardColor = AppColors.getSurface(t);
        const accentColor = AppColors.primary;

        return Scaffold(
          backgroundColor: backgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                floating: false,
                pinned: true,
                backgroundColor: backgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(const Color(0xFFF8FAFC),
                              const Color(0xFF1E293B), t)!,
                          Color.lerp(const Color(0xFFE2E8F0),
                              const Color(0xFF0F172A), t)!,
                          backgroundColor,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const ToxiGuardLogo(size: 200, animate: false),
                          const SizedBox(height: 5),
                          Text(
                            "CYBER OWL",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Silent Eyes, Safe Future",
                            style: TextStyle(
                              fontSize: 16,
                              color: accentColor.withValues(alpha: 0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("Our Mission", accentColor),
                          _buildInfoCard(
                            "To protect the digital lives of the younger generation by providing real-time abuse detection and proactive safety measures.",
                            FluentIcons.shield_24_regular,
                            textColor,
                            cardColor,
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle("Key Features", accentColor),
                          _buildFeatureRow(
                              FluentIcons.flash_24_regular,
                              "Real-time Monitoring",
                              "Instant detection of harmful content.",
                              textColor),
                          _buildFeatureRow(
                              FluentIcons.brain_circuit_24_regular,
                              "AI-Powered",
                              "Advanced machine learning algorithms.",
                              textColor),
                          _buildFeatureRow(
                              FluentIcons.alert_24_regular,
                              "Smart Alerts",
                              "Immediate notifications for parents.",
                              textColor),
                          const SizedBox(height: 20),
                          _buildSectionTitle("Privacy & Security", accentColor),
                          _buildInfoCard(
                            "Your data is encrypted and stored securely. We prioritize user privacy and transparency in all our operations.",
                            FluentIcons.lock_closed_24_regular,
                            textColor,
                            cardColor,
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle("The Team", accentColor),
                          _buildTeamGrid(textColor, cardColor, accentColor),
                          const SizedBox(height: 20),
                          _buildSectionTitle("How It Works", accentColor),
                          _buildHowItWorks(textColor, cardColor, accentColor),
                          const SizedBox(height: 30),
                          _buildSectionTitle("Our Impact", accentColor),
                          _buildImpactStats(textColor, cardColor, accentColor),
                          const SizedBox(height: 20),
                          _buildSectionTitle("Connect With Us", accentColor),
                          _buildSocialRow(accentColor, textColor),
                          const SizedBox(height: 30),
                          Divider(color: textColor.withValues(alpha: 0.1)),
                          const SizedBox(height: 20),
                          _buildSectionTitle(
                              "We Value Your Feedback", accentColor),
                          const SizedBox(height: 10),
                          _buildFeedbackForm(
                              textColor, cardColor, accentColor, t, isDark),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      String text, IconData icon, Color textColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]),
      child: Row(
        children: [
          Icon(icon, color: textColor.withValues(alpha: 0.7), size: 30),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, String title, String subtitle, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(icon, color: textColor.withValues(alpha: 0.8), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamGrid(Color textColor, Color cardColor, Color accentColor) {
    final members = [
      {
        "name": "Atharva Wagh",
        "role": "Frontend Flutter, DB & ML Integration Developer"
      },
      {"name": "Saqlain Naik", "role": "Backend Developer & ML Model Manager"},
      {"name": "Mohd Rafe", "role": "Website Manager & Frontend Developer"},
      {
        "name": "Mussayab Mulla",
        "role": "Email Config Manager & Backend Developer"
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: members.map((member) {
          final memberName = member['name']!;
          final imagePath =
              "assets/team/${memberName.split(' ')[0].toLowerCase()}.jpeg";

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // shrink to fit content
                children: [
                  Container(
                    width: 70, // Slightly smaller to ensure fit
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardColor,
                      border:
                          Border.all(color: accentColor.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                      image: DecorationImage(
                        image: AssetImage(imagePath),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {
                          // Fallback
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36, // Fixed height for 2 lines of name
                    child: Center(
                      child: Text(
                        memberName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 45, // Fixed height for 4 lines of role
                    child: Center(
                      child: Text(
                        member['role']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 10,
                          height: 1.1,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImpactStats(
      Color textColor, Color cardColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("10k+", "Active Users", accentColor, textColor),
          _buildStatItem("500+", "Schools", accentColor, textColor),
          _buildStatItem("24/7", "Monitoring", accentColor, textColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, Color accentColor, Color textColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialRow(Color accentColor, Color textColor) {
    final socialItems = [
      {'icon': FontAwesomeIcons.instagram, 'color': Colors.pink},
      {'icon': FontAwesomeIcons.linkedin, 'color': Colors.blue[700]},
      {'icon': FontAwesomeIcons.whatsapp, 'color': Colors.green},
      {'icon': FontAwesomeIcons.twitter, 'color': Colors.lightBlue},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: socialItems.map((item) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (item['color'] as Color).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: FaIcon(
            item['icon'] as IconData,
            color: item['color'] as Color,
            size: 24,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHowItWorks(Color textColor, Color cardColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildStepRow(
            "1",
            FluentIcons.eye_24_regular,
            "Monitor",
            "Continuous scanning of digital interactions.",
            textColor,
            accentColor,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child:
                Divider(height: 32, color: textColor.withValues(alpha: 0.05)),
          ),
          _buildStepRow(
            "2",
            FluentIcons.data_bar_horizontal_24_regular,
            "Analyze",
            "AI detects toxic patterns and keywords.",
            textColor,
            accentColor,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child:
                Divider(height: 32, color: textColor.withValues(alpha: 0.05)),
          ),
          _buildStepRow(
            "3",
            FluentIcons.shield_24_regular,
            "Protect",
            "Instant alerts prevent potential harm.",
            textColor,
            accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String number, IconData icon, String title,
      String description, Color textColor, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Icon(icon, color: textColor.withValues(alpha: 0.3), size: 28),
      ],
    );
  }

  Widget _buildFeedbackForm(Color textColor, Color cardColor, Color accentColor,
      double t, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.interpolate(Colors.grey.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.2), t),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating
                      ? FluentIcons.star_24_filled
                      : FluentIcons.star_24_regular,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () {
                  setState(() => _rating = index + 1.0);
                },
              );
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _feedbackController,
            maxLines: 4,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "Tell us what you think...",
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
              filled: true,
              fillColor: AppColors.interpolate(
                  Colors.white.withValues(alpha: 0.8),
                  Colors.black.withValues(alpha: 0.3),
                  t),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitFeedback,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor:
                  AppColors.interpolate(Colors.white, Colors.black, t),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: _isSubmitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          AppColors.interpolate(Colors.white, Colors.black, t),
                    ),
                  )
                : const Text(
                    "SEND FEEDBACK",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
