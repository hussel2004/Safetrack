class KalmanFilter {
  double _processNoise; // Process noise covariance (Q)
  double _measurementNoise; // Measurement noise covariance (R)
  double _estimatedError; // Estimated error covariance (P)
  double _value; // Value (state)
  bool _isInitialized = false;

  KalmanFilter({
    double processNoise = 1.0, // Default process noise
    double measurementNoise = 1.0, // Default measurement noise
    double estimatedError = 1.0, // Default estimated error
    double initialValue = 0.0,
  }) : _processNoise = processNoise,
       _measurementNoise = measurementNoise,
       _estimatedError = estimatedError,
       _value = initialValue;

  double filter(double measurement) {
    if (!_isInitialized) {
      _value = measurement;
      _isInitialized = true;
      return _value;
    }

    // Prediction phase
    // _value = _value; // State transition (identity for constant position/velocity model)
    _estimatedError = _estimatedError + _processNoise;

    // Correction phase
    final kalmanGain = _estimatedError / (_estimatedError + _measurementNoise);
    _value = _value + kalmanGain * (measurement - _value);
    _estimatedError = (1 - kalmanGain) * _estimatedError;

    return _value;
  }

  void reset() {
    _isInitialized = false;
  }
}
