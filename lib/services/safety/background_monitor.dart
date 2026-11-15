import 'package:flutter/services.dart';

class BackgroundMonitor {
  Future<bool> claim() async =>
      await _channel.invokeMethod<bool>('claim') == true;
  static const _channel = MethodChannel('aegis/fall_monitor');
  Future<void> start(bool demo) async {
    if (await _channel.invokeMethod<bool>('permission') != true) {
      throw PlatformException(
        code: 'notifications',
        message:
            'Allow notifications in Android Settings to enable fall protection.',
      );
    }
    await _channel.invokeMethod('start', {'demo': demo});
  }

  Future<Map<dynamic, dynamic>> state() async =>
      await _channel.invokeMapMethod('state') ?? {};
  Future<void> stop() => _channel.invokeMethod('stop');
  Future<void> cancel() => _channel.invokeMethod('cancel');
  Future<void> setDemo(bool demo) =>
      _channel.invokeMethod('demo', {'demo': demo});
}
