import 'package:flutter/material.dart';

/// Clean loading widget displaying the transparent ARJUNA logo
/// with a refined circular indicator, with zero background boxes.
class ArjunaLoadingWidget extends StatelessWidget {
  const ArjunaLoadingWidget({
    super.key,
    this.size = 56,
    this.logoSize = 36,
    this.message,
  });

  final double size;
  final double logoSize;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                  ),
                ),
                Image.asset(
                  'assets/images/logo_arjuna.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F766E),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full screen loading scaffold with transparent ARJUNA branding
class ArjunaLoadingScreen extends StatelessWidget {
  const ArjunaLoadingScreen({
    super.key,
    this.message = 'Memuat...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ArjunaLoadingWidget(
        size: 68,
        logoSize: 44,
        message: message,
      ),
    );
  }
}
