import 'dart:async';
import '../live_sharing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/alert_model.dart';
import '../alert_service.dart';
import '../auth_service.dart';
import 'fall_detector.dart';
import 'motion_feed.dart';
import 'sos_gateway.dart';
import 'background_monitor.dart';
import '../automatic_sms_service.dart';
import 'package:flutter/services.dart';

enum SafetyPhase { idle, countdown, dispatching, finished, failed }

class SafetyController extends ChangeNotifier {
  final MotionFeed motion;
  final SosGateway gateway;
  final int countdownSeconds;
  final FallDetector detector = FallDetector();
  final BackgroundMonitor? backgroundMonitor;
  Timer? _nativePoll;
  bool _syncing = false;
  bool changingMonitoring = false;
  bool _nativeEvent = false;
  bool get automaticSms => AutomaticSmsService.enabled;
  bool changingSms = false;
  Future<void> setAutomaticSms(bool enabled) async {
    if (busy || monitoring || changingSms || changingMonitoring) return;
    changingSms = true;
    _notify();
    try {
      if (enabled) {
        final count = await AutomaticSmsService.enable();
        if (_disposed) {
          await AutomaticSmsService.disable();
          return;
        }
        notice =
            'Automatic SMS enabled for $count guardian(s). SMS charges may apply. Re-enable after changing guardians.';
      } else {
        await AutomaticSmsService.disable();
        notice = 'Automatic SMS off. Messages require you to tap Send.';
      }
    } catch (e) {
      await AutomaticSmsService.disable();
      notice = e is PlatformException ? e.message : '$e';
    } finally {
      changingSms = false;
      _notify();
    }
  }

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
    this.backgroundMonitor,
  });
  bool get busy =>
      phase == SafetyPhase.countdown ||
      phase == SafetyPhase.dispatching ||
      resolving;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDemo(bool enabled) {
    if (phase != SafetyPhase.idle || changingMonitoring || changingSms) return;
    demo = enabled;
    detector.demo = enabled;
    detector.reset();
    if (monitoring && backgroundMonitor != null) {
      unawaited(backgroundMonitor!.setDemo(enabled).catchError((Object _) {}));
    }
    _notify();
  }

  Future<void> setMonitoring(bool enabled) async {
    if (phase != SafetyPhase.idle || !foreground) return;
    if (changingMonitoring || changingSms) return;
    if (backgroundMonitor != null) {
      changingMonitoring = true;
      notice = null;
      _notify();
      try {
        if (enabled) {
          await backgroundMonitor!.start(demo);
          if (_disposed) {
            await backgroundMonitor!.stop();
            return;
          }
          monitoring = true;
          _nativePoll?.cancel();
          _nativePoll = Timer.periodic(
            const Duration(milliseconds: 500),
            (_) => _syncNative(),
          );
          await _syncNative();
        } else {
          await backgroundMonitor!.stop();
          _nativePoll?.cancel();
          monitoring = false;
        }
      } catch (_) {
        monitoring = false;
        notice =
            'Could not enable background monitoring. Allow Aegis notifications in Android Settings and retry.';
      } finally {
        changingMonitoring = false;
        _notify();
      }
      return;
    }
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

  Future<void> _syncNative() async {
    if (_syncing || _disposed || backgroundMonitor == null) return;
    _syncing = true;
    try {
      final state = await backgroundMonitor!.state();
      if (_disposed) return;
      final nativePhase = state['phase'];
      if (nativePhase == 'sms_sending') {
        _nativeEvent = true;
        _requestId = state['eventId'] as String;
        eventIsDemo = false;
        phase = SafetyPhase.dispatching;
        _notify();
      } else if (nativePhase == 'sms_complete' && foreground) {
        phase = SafetyPhase.dispatching;
        _nativeEvent = false;
        monitoring = false;
        _nativePoll?.cancel();
        _notify();
        result = await backgroundMonitor!.recordSmsResult(state);
        await backgroundMonitor!.stop();
        eventIsDemo = false;
        resolved = false;
        phase = SafetyPhase.finished;
      } else if (nativePhase == 'stopped' || nativePhase == 'error') {
        monitoring = false;
        _nativePoll?.cancel();
        if (_nativeEvent && phase == SafetyPhase.dispatching) {
          result = AlertTriggerResult(
            alertId: _requestId,
            contactCount: 0,
            smsOpened: false,
            dialerOpened: false,
            recorded: false,
            automaticSmsMessage:
                'Background sending was interrupted. An SMS may already have been sent. Check Messages and contact your guardian directly.',
          );
          phase = SafetyPhase.finished;
        }
        if (_nativeEvent && phase == SafetyPhase.countdown) {
          phase = SafetyPhase.idle;
        }
        _nativeEvent = false;
        notice = nativePhase == 'error'
            ? '${state['error']}'
            : 'Fall monitoring stopped. Enable it again to resume.';
      } else if (nativePhase == 'idle' &&
          _nativeEvent &&
          phase == SafetyPhase.countdown) {
        phase = SafetyPhase.idle;
        _nativeEvent = false;
        notice = 'Countdown cancelled. No alert was created.';
      } else if ((nativePhase == 'countdown' || nativePhase == 'expired') &&
          (phase == SafetyPhase.idle ||
              (_nativeEvent && phase == SafetyPhase.countdown))) {
        _nativeEvent = true;
        eventIsDemo = state['demo'] == true;
        _type = AlertType.fallDetected;
        _requestId = state['eventId'] as String;
        remaining = (state['remaining'] as num).toInt();
        phase = SafetyPhase.countdown;
        result = null;
        error = null;
        resolved = false;
        if (nativePhase == 'expired' && foreground) await escalate();
      }
      _notify();
    } catch (_) {
      monitoring = false;
      _nativePoll?.cancel();
      if (_nativeEvent && phase == SafetyPhase.dispatching) {
        result = AlertTriggerResult(
          alertId: _requestId,
          contactCount: 0,
          smsOpened: false,
          dialerOpened: false,
          recorded: false,
          automaticSmsMessage:
              'Could not check the background SMS result. Check Messages before sending again.',
        );
        phase = SafetyPhase.finished;
        _nativeEvent = false;
      }
      unawaited(backgroundMonitor!.stop().catchError((Object _) {}));
      notice =
          'Could not check background monitoring. Reopen Aegis and enable it again.';
      _notify();
    } finally {
      _syncing = false;
    }
  }

  void _stopSensors() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void setForeground(bool value) {
    foreground = value;
    if (backgroundMonitor != null) {
      if (!value && phase == SafetyPhase.countdown && !_nativeEvent) {
        cancelCountdown();
      }
      if (value && (monitoring || _nativeEvent)) unawaited(_syncNative());
      _notify();
      return;
    }
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
    if (_nativeEvent) {
      unawaited(
        backgroundMonitor!.cancel().then((_) => _syncNative()).catchError((
          Object _,
        ) {
          notice =
              'Could not cancel from this screen. Use the notification cancel button.';
          _notify();
        }),
      );
      return;
    }
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
    if (_nativeEvent) {
      try {
        if (!await backgroundMonitor!.claim()) {
          await _syncNative();
          return;
        }
      } catch (_) {
        error = 'Could not prepare the fall alert. Open Aegis and retry.';
        _notify();
        return;
      }
      if (_disposed) return;
    }
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
    _nativeEvent = false;
    _nativePoll?.cancel();
    if (backgroundMonitor != null) {
      try {
        await backgroundMonitor!.stop();
      } catch (_) {}
    }
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
      error = e is SafetyException
          ? e.message
          : e is AlertOperationException
          ? e.message
          : authErrorMessage(e);
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
      if (result!.recorded) {
        await gateway.resolve(result!.alertId);
      } else {
        await LiveSharingService.stop();
      }
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
    _nativePoll?.cancel();
    if (backgroundMonitor != null) {
      unawaited(backgroundMonitor!.stop().catchError((Object _) {}));
      unawaited(AutomaticSmsService.disable().catchError((Object _) {}));
    }
    _stopSensors();
    super.dispose();
  }
}
