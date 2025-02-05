import 'package:to_do_app/common_imports.dart';

final class AppColors {
  // Primary Colors
  static const Color primaryTeal = Color(0xFF5BA199);
  static const Color primaryPurple = Color(0xFF9B8ACA);
  static const Color primaryRose = Color(0xFFE57373);

  // Selected/Action Colors
  static const Color selectedBlue =
      Color(0xFF4B4FC4); // Selected tab color from screenshot
  static const Color addButtonBlue =
      Color(0xFF4B4FC4); // Floating action button color

  // Tab & Button Colors
  static const Color tabSelected = selectedBlue;
  static const Color tabUnselected = Color(0xFF9E9E9E); // Unselected tab color
  static const Color upcomingTabBg = Colors.white; // White tab background

  // Text Colors
  static const Color textLight = Colors.white;
  static const Color textMuted = Colors.white70;
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);

  // Border Colors
  static const Color borderColor = Colors.white24;
  static const Color borderColorDark = Color(0xFF34495E);
  static const Color borderColorLight = Color(0xFFECF0F1);

  // Home Screen Colors
  static const Color homeTeal = Color(0xFF48C9B0); // Brighter teal
  static const Color homePurple = Color(0xFFAA99DD); // Lighter purple
  static const Color homeRose = Color(0xFFFF7F7F); // Brighter rose

  // Button Colors
  static const Color buttonText = Colors.white;
  static const Color buttonBackground = Color(0xFF9B59B6);
  static const Color buttonForeground = Colors.white;

  // Icon Colors
  static const Color iconColor = Color(0xFFF29393);
  static const Color iconColorSecondary = Color(0xFF9B59B6);
}

class AuthGradientBackground extends StatelessWidget {
  final Widget child;

  const AuthGradientBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryTeal,
            AppColors.primaryPurple,
            AppColors.primaryRose,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// Light mode gradient background for Home Page
class HomePageGradientBackground extends StatelessWidget {
  final Widget child;

  const HomePageGradientBackground({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.homeTeal, // Brighter teal for home (light mode)
            AppColors.homePurple, // Lighter purple for home (light mode)
            AppColors.homeRose, // Brighter rose for home (light mode)
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

class HomePageDarkGradientBackground extends StatelessWidget {
  final Widget child;

  const HomePageDarkGradientBackground({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Using deeper colors for a more pronounced dark mode.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black, // Pure black
            Colors.blueGrey.shade900, // Very dark blue-grey
            Colors.black87, // Almost black
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
