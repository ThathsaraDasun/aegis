import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'fall_detector.dart';

abstract class MotionFeed {
  Stream<MotionSample> samples();
}

class DeviceMotionFeed implements MotionFeed {
  @override
  Stream<MotionSample> samples() {
    late StreamController<MotionSample> controller;
    StreamSubscription<AccelerometerEvent>? acceleration;
    StreamSubscription<GyroscopeEvent>? rotation;
    controller = StreamController<MotionSample>(
      onListen: () {
        const period = Duration(milliseconds: 50);
        acceleration = accelerometerEventStream(samplingPeriod: period)
            .timeout(const Duration(seconds: 3))
            .listen(
              (e) => controller.add(
                MotionSample(
                  MotionKind.acceleration,
                  e.x,
                  e.y,
                  e.z,
                  DateTime.now(),
                ),
              ),
              onError: controller.addError,
            );
        rotation = gyroscopeEventStream(samplingPeriod: period)
            .timeout(const Duration(seconds: 3))
            .listen(
              (e) => controller.add(
                MotionSample(
                  MotionKind.rotation,
                  e.x,
                  e.y,
                  e.z,
                  DateTime.now(),
                ),
              ),
              onError: controller.addError,
            );
      },
      onCancel: () async {
        await acceleration?.cancel();
        await rotation?.cancel();
      },
    );
    return controller.stream;
  }
}
