import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/alert_model.dart';
import '../alert_service.dart';
import '../auth_service.dart';
import 'fall_detector.dart';
import 'motion_feed.dart';
import 'sos_gateway.dart';

enum SafetyPhase { idle, countdown, dispatching, finished, failed }

class SafetyController extends ChangeNotifier {
  final MotionFeed motion;
  final SosGateway gateway;
  final int countdownSeconds;
  final FallDetector detector = FallDetector();
  StreamSubscription<MotionSample>? _subscription;
  Timer? _timer;
  bool _disposed = false;
  bool foreground = true;
  bool monitoring = false;
  bool demo = false;
  bool resolving = false;
  bool resolved = false;
  bool eventIsDemo = false;
  int remaining = 0;
  SafetyPhase phase = SafetyPhase.idle;
  AlertTriggerResult? result;
  String? notice;
  String? error;
  String _type = AlertType.manualSos;
  String _requestId = '';

  SafetyController({
    required this.motion,
    required this.gateway,
    this.countdownSeconds = 15,
  });
  bool get busy =>
      phase == SafetyPhase.countdown ||
      phase == SafetyPhase.dispatching ||
      resolving;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDemo(bool enabled) {
    if (phase != SafetyPhase.idle) return;
    demo = enabled;
    detector.demo = enabled;
    detector.reset();
    _notify();
  }

  void setMonitoring(bool enabled) {
    if (phase != SafetyPhase.idle || !foreground) return;
    monitoring = enabled;
    notice = null;
    detector.reset();
    _stopSensors();
    if (enabled) {
      try {
        _subscription = motion.samples().listen(
          (sample) {
            if (phase == SafetyPhase.idle && detector.add(sample)) {
              startCountdown();
            }
          },
          onError: (_) {
            monitoring = false;
            _stopSensors();
            notice =
                'Motion sensors are unavailable. Monitoring stopped; manual SOS is still available.';
            if (phase == SafetyPhase.countdown) cancelCountdown();
            _notify();
          },
        );
      } catch (_) {
        monitoring = false;
        notice =
            'Motion sensors could not start. Manual SOS is still available.';
      }
    }
    _notify();
  }

  void _stopSensors() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void setForeground(bool value) {
    foreground = value;
    if (!value) {
      monitoring = false;
      _stopSensors();
      detector.reset();
      if (phase == SafetyPhase.countdown) cancelCountdown();
      demo = false;
      detector.demo = false;
      notice =
          'Monitoring paused when the app left the foreground. Enable it again to resume.';
    }
    _notify();
  }

  void startCountdown({bool simulation = false}) {
    if (_disposed || !foreground || phase != SafetyPhase.idle) return;
    if (!simulation && !monitoring) return;
    eventIsDemo = simulation || demo;
    _type = AlertType.fallDetected;
    _requestId = const Uuid().v4();
    result = null;
    error = null;
    resolved = false;
    remaining = countdownSeconds;
    phase = SafetyPhase.countdown;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || phase != SafetyPhase.countdown) return;
      remaining--;
      if (remaining <= 0) {
        unawaited(escalate());
      } else {
        _notify();
      }
    });
    _notify();
  }

  void cancelCountdown() {
    if (phase != SafetyPhase.countdown) return;
    _timer?.cancel();
    phase = SafetyPhase.idle;
    detector.reset();
    notice = 'Countdown cancelled. No alert was created.';
    _notify();
  }

  Future<void> manualSos() async {
    if (_disposed || !foreground || phase != SafetyPhase.idle) return;
    eventIsDemo = false; // Manual SOS is always real and explicitly labelled.
    _type = AlertType.manualSos;
    _requestId = const Uuid().v4();
    result = null;
    error = null;
    resolved = false;
    await _dispatch();
  }

  Future<void> escalate() async {
    if (_disposed || !foreground || phase != SafetyPhase.countdown) return;
    _timer?.cancel();
    await _dispatch();
  }

  Future<void> retry() async {
    if (phase != SafetyPhase.failed || !foreground || _disposed) return;
    await _dispatch(); // Same request ID: a retry does not create another record.
  }

  Future<void> _dispatch() async {
    phase = SafetyPhase.dispatching;
    monitoring = false;
    _stopSensors();
    error = null;
    _notify();
    if (eventIsDemo) {
      phase = SafetyPhase.finished;
      _notify();
      return;
    }
    try {
      final response = await gateway.trigger(_type, _requestId);
      if (_disposed) return;
      result = response;
      phase = SafetyPhase.finished;
    } catch (e) {
      if (_disposed) return;
      error = e is SafetyException ? e.message : authErrorMessage(e);
      phase = SafetyPhase.failed;
    }
    _notify();
  }

  Future<void> resolve() async {
    if (phase != SafetyPhase.finished ||
        result == null ||
        resolving ||
        resolved) {
      return;
    }
    resolving = true;
    error = null;
    _notify();
    try {
      await gateway.resolve(result!.alertId);
      if (!_disposed) resolved = true;
    } catch (e) {
      if (!_disposed) error = authErrorMessage(e);
    } finally {
      if (!_disposed) {
        resolving = false;
        _notify();
      }
    }
  }

  void dismiss() {
    if (busy || phase == SafetyPhase.idle) return;
    phase = SafetyPhase.idle;
    error = null;
    detector.reset();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _stopSensors();
    super.dispose();
  }
}
