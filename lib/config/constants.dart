// lib/config/constants.dart — App-wide constants.

class AppConstants {
  AppConstants._();

  // Session time windows
  static const int morningStartHour = 5;
  static const int morningEndHour = 12;
  static const int eveningStartHour = 17;
  static const int eveningEndHour = 23;

  // Voice pipeline
  static const int silenceWindowMs = 800;
  static const double vadEnergyThreshold = 0.01;

  // Timeouts
  static const Duration httpTimeout = Duration(seconds: 30);
  static const Duration sttTimeout = Duration(seconds: 10);

  // Dashboard
  static const int unresolvedEventsMaxAge = 24; // hours
}
