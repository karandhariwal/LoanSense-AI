import 'package:flutter/material.dart';

abstract final class AppRoutes {
  static const home = '/home';
  static const compare = '/compare';
  static const profile = '/profile';
  static const scan = '/scan';
}

abstract final class AppNavigator {
  static NavigatorState _navigator(BuildContext context) =>
      Navigator.of(context);

  static Future<Object?> goHome(BuildContext context) {
    return _navigator(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  static Future<Object?> goToCompare(BuildContext context) {
    return _navigator(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.compare, (route) => false);
  }

  static Future<Object?> goToProfile(BuildContext context) {
    return _navigator(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.profile, (route) => false);
  }

  static Future<Object?> goToScan(BuildContext context) {
    return _navigator(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.scan, (route) => false);
  }
}
