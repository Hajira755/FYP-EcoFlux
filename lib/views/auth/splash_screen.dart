import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _floatController;

  bool showLogo = false;
  bool showText = false;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    // Show logo with animation
    Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => showLogo = true);
        _logoController.forward();
      }
    });

    // Show welcome text
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => showText = true);
    });

    // Auto navigate to login screen after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login_screen');
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = [
      const Color(0xFF90CAF9),
      const Color(0xFFE8F5E9),
    ];

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            final logoSize = (w * 0.55).clamp(200.0, 380.0);
            final titleSize = (w * 0.085).clamp(34.0, 52.0);
            final subtitleSize = (w * 0.045).clamp(16.0, 22.0);
            final iconBaseSize = (w * 0.09).clamp(28.0, 48.0);

            return Stack(
              children: [
                // Background gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradientColors,
                    ),
                  ),
                ),

                // Floating icons
                _buildFloatingIcon(Icons.eco, left: 0.10, top: 0.12, size: iconBaseSize, w: w, h: h),
                _buildFloatingIcon(Icons.eco, right: 0.15, top: 0.30, size: iconBaseSize * 0.85, w: w, h: h),
                _buildFloatingIcon(Icons.recycling, left: 0.20, bottom: 0.35, size: iconBaseSize * 0.9, w: w, h: h),
                _buildFloatingIcon(Icons.delete_outline, right: 0.18, top: 0.48, size: iconBaseSize * 0.8, w: w, h: h),
                _buildFloatingIcon(Icons.recycling, right: 0.28, top: 0.18, size: iconBaseSize * 0.88, w: w, h: h),

                // Main Content
                Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: w * 0.07),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 40),

                          // Logo
                          if (showLogo)
                            ScaleTransition(
                              scale: CurvedAnimation(
                                parent: _logoController,
                                curve: Curves.easeOutBack,
                              ),
                              child: Image.asset(
                                'assets/images/logo1.png',
                                width: logoSize,
                                fit: BoxFit.contain,
                              ),
                            ),

                          SizedBox(height: h * 0.05),

                          // Welcome Text
                          if (showText)
                            AnimatedOpacity(
                              opacity: showText ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 800),
                              child: Column(
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [Colors.white, const Color(0xFFDCEDC8)],
                                    ).createShader(bounds),
                                    child: Text(
                                      'Welcome',
                                      style: TextStyle(
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.4,
                                        color: Colors.white,
                                        shadows: const [
                                          Shadow(blurRadius: 15, color: Colors.black38, offset: Offset(2, 4)),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(height: h * 0.02),
                                  Text(
                                    'Waste Management\n& Reporting System',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: subtitleSize,
                                      color: Colors.white.withValues(alpha: 0.92),
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingIcon(
      IconData icon, {
        double? left,
        double? right,
        double? top,
        double? bottom,
        required double size,
        required double w,
        required double h,
      }) {
    return Positioned(
      left: left != null ? w * left : null,
      right: right != null ? w * right : null,
      top: top != null ? h * top : null,
      bottom: bottom != null ? h * bottom : null,
      child: SizedBox(
        width: size + 30,
        height: size + 50,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (_, __) {
            final offsetY = sin(_floatController.value * 2 * pi) * 16;
            return Transform.translate(
              offset: Offset(0, offsetY),
              child: Opacity(
                opacity: 0.22,
                child: Icon(icon, size: size, color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}
