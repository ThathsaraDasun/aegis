import 'dart:math';

enum MotionKind { acceleration, rotation }

class MotionSample {
  final MotionKind kind;
  final double x, y, z;
  final DateTime time;
  const MotionSample(this.kind, this.x, this.y, this.z, this.time);
  double get magnitude => sqrt(x * x + y * y + z * z);
}

/// Phone-only MVP heuristic, not a validated medical detector.
/// Normal mode: impact + recent rotation, followed by one second of stillness.
/// Demo mode: a lower impact/rotation threshold for a gentle controlled shake.
class FallDetector {
  DateTime? _rotationAt, _impactAt, _stillSince, _lastTrigger;
  double _rotation = 0;
  bool demo = false;

  void reset() {
    _rotationAt = _impactAt = _stillSince = null;
    _rotation = 0;
  }

  bool add(MotionSample sample) {
    final magnitude = sample.magnitude;
    if (!magnitude.isFinite) return false;
    if (sample.kind == MotionKind.rotation) {
      _rotation = magnitude;
      _rotationAt = sample.time;
      return false;
    }
    if (_lastTrigger != null &&
        sample.time.difference(_lastTrigger!) < const Duration(seconds: 20)) {
      return false;
    }
    final gyroAge = _rotationAt == null
        ? null
        : sample.time.difference(_rotationAt!);
    if (gyroAge == null ||
        gyroAge.isNegative ||
        gyroAge > const Duration(milliseconds: 500)) {
      _impactAt = _stillSince = null;
      return false;
    }
    if (magnitude >= (demo ? 12.5 : 25) && _rotation >= (demo ? 0.6 : 2.5)) {
      if (demo) return _trigger(sample.time);
      _impactAt = sample.time;
      _stillSince = null;
    }
    if (_impactAt == null) return false;
    if (sample.time.difference(_impactAt!) > const Duration(seconds: 4)) {
      _impactAt = _stillSince = null;
      return false;
    }
    if (magnitude >= 7.5 && magnitude <= 12.5 && _rotation < 0.7) {
      _stillSince ??= sample.time;
      if (sample.time.difference(_stillSince!) >= const Duration(seconds: 1)) {
        return _trigger(sample.time);
      }
    } else {
      _stillSince = null;
    }
    return false;
  }

  bool _trigger(DateTime time) {
    _lastTrigger = time;
    reset();
    return true;
  }
}
