import 'dart:math';

class ClassifiedReading {
  final double value;
  final String outlierFlag;
  final double weight;
  final double confidence;
  const ClassifiedReading({required this.value, required this.outlierFlag, required this.weight, required this.confidence});
}

class OutlierClassifier {
  static ClassifiedReading classify({
    required double value,
    double? rollingMean,
    double? rollingVariance,
    required double sourceConfidence,
  }) {
    if (rollingMean == null || rollingVariance == null || rollingVariance <= 0) {
      return ClassifiedReading(value: value, outlierFlag: 'none', weight: 1.0, confidence: sourceConfidence);
    }
    final sd = sqrt(rollingVariance);
    final deviations = (value - rollingMean).abs() / sd;
    if (deviations < 2.0) return ClassifiedReading(value: value, outlierFlag: 'none', weight: 1.0, confidence: sourceConfidence);
    if (deviations < 3.0) return ClassifiedReading(value: value, outlierFlag: 'potential_outlier', weight: 0.3, confidence: sourceConfidence * 0.3);
    return ClassifiedReading(value: value, outlierFlag: 'extreme_outlier', weight: 0.1, confidence: sourceConfidence * 0.1);
  }
}
