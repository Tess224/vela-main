import 'dart:math';

class HrvCalculator {
  static double? hrDerivedProxy(List<double> restingHrSamples) {
    if (restingHrSamples.length < 3) return null;
    final mean = restingHrSamples.reduce((a, b) => a + b) / restingHrSamples.length;
    if (mean <= 0) return null;
    final variance = restingHrSamples
            .map((h) => pow(h - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        restingHrSamples.length;
    final proxy = (1000 / mean) * sqrt(variance) * 10;
    return proxy.clamp(10.0, 120.0);
  }
}
