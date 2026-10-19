// core/responsive.dart
import 'package:flutter/widgets.dart';

class Responsive {
  static const double mobileMax = 700;
  static const double desktopMin = 1000;

  static bool isMobile(BuildContext context) => MediaQuery.sizeOf(context).width < mobileMax;

  static bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= desktopMin;
}
