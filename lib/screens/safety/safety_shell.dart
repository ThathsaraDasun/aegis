import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/alert_service.dart';
import '../trip/start_trip_screen.dart';
import '../../services/safety/motion_feed.dart';
import '../../services/safety/safety_controller.dart';
import '../../services/safety/sos_gateway.dart';

class SafetyScope extends InheritedNotifier<SafetyController> {
  const SafetyScope({
    super.key,
    required SafetyController controller,
    required super.child,
  }) : super(notifier: controller);
  static SafetyController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SafetyScope>()!.notifier!;
}

/// Remains above every signed-in route; logout disposes sensors and countdown.
class SafetyShell extends StatefulWidget {
  final WidgetBuilder homeBuilder;
  final SafetyController? controller;
  const SafetyShell({super.key, required this.homeBuilder, this.controller});
  @override
  State<SafetyShell> createState() => _SafetyShellState();
}

class _SafetyShellState extends State<SafetyShell> with WidgetsBindingObserver {
  late final SafetyController controller =
      widget.controller ??
      SafetyController(
        motion: DeviceMotionFeed(),
        gateway: BackendSosGateway(),
      );
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    controller.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafetyScope(
    controller: controller,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (controller.phase == SafetyPhase.countdown) {
            controller.cancelCountdown();
          } else if (controller.phase == SafetyPhase.finished ||
              controller.phase == SafetyPhase.failed) {
            controller.dismiss();
          } else if (controller.phase == SafetyPhase.idle) {
            await _navigatorKey.currentState?.maybePop();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Navigator(
              key: _navigatorKey,
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: widget.homeBuilder),
            ),
            if (controller.phase == SafetyPhase.idle)
              Positioned(
                right: 16,
                bottom: 88 + MediaQuery.paddingOf(context).bottom,
                child: FloatingActionButton.extended(
                  heroTag: 'global-sos',
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                  onPressed: controller.manualSos,
                  icon: const Icon(Icons.sos),
                  label: const Text('Real SOS'),
                ),
              ),
            if (controller.phase != SafetyPhase.idle)
              SafetyEventScreen(controller: controller),
          ],
        ),
      ),
    ),
  );
}

class SafetyEventScreen extends StatelessWidget {
  final SafetyController controller;
  const SafetyEventScreen({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    c.eventIsDemo
                        ? Icons.science_outlined
                        : Icons.health_and_safety_outlined,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  if (c.phase == SafetyPhase.countdown) ...[
                    Text(
                      c.eventIsDemo
                          ? 'Demo: Are you OK?'
                          : 'Possible fall. Are you OK?',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${c.remaining}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      c.eventIsDemo
                          ? 'Practice only. No messages or database alerts will be created.'
                          : 'When time runs out, an alert will be recorded and the SMS composer opened. Someone must tap Send; delivery is not automatic.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: c.cancelCountdown,
                      child: const Text('I am OK - cancel'),
                    ),
                    OutlinedButton(
                      onPressed: c.escalate,
                      child: Text(
                        c.eventIsDemo
                            ? 'Simulate escalation now'
                            : 'Escalate now',
                      ),
                    ),
                  ] else if (c.phase == SafetyPhase.dispatching) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 20),
                    const Text(
                      'Preparing your alert...',
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      'Checking GPS, saving the alert and opening contact options. Keep the app open.',
                    ),
                  ] else if (c.phase == SafetyPhase.failed) ...[
                    Text(
                      'Alert could not be completed',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(c.error ?? 'Please try again.'),
                    const Text(
                      'No delivery has been confirmed. If urgent, contact your guardian directly.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: c.retry,
                      child: const Text('Retry alert'),
                    ),
                    TextButton(
                      onPressed: c.dismiss,
                      child: const Text('Close'),
                    ),
                  ] else ...[
                    Text(
                      c.eventIsDemo ? 'Demo completed' : 'Alert recorded',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    if (c.eventIsDemo)
                      const Text(
                        'The countdown reached escalation. No contacts were notified and no alert was saved.',
                      )
                    else ...[
                      Text(
                        c.result!.smsOpened
                            ? 'SMS option opened. Choose Messages or Messaging, not WhatsApp, in the chooser. Tap Send yourself. Delivery has not been confirmed.'
                            : c.result!.dialerOpened
                            ? 'Phone dialer opened. You must start the call yourself.'
                            : c.result!.contactCount == 0
                            ? 'No usable contacts were found. Nobody was contacted. Add a guardian before your next walk.'
                            : 'SMS and phone apps could not be opened. Contact your guardian directly.',
                      ),
                      const SizedBox(height: 12),
                      SelectableText('Alert ID: ${c.result!.alertId}'),
                      if (c.result!.whatsAppLinks.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Prefer WhatsApp? Close the SMS chooser and use a button below. Send separately to each guardian. Opening a chat does not send the message.'),
                        for (final link in c.result!.whatsAppLinks)
                          _WhatsAppButton(link: link),
                      ],
                      const SizedBox(height: 12),
                      if (c.resolved)
                        const Text('Marked resolved in your activity log.')
                      else
                        OutlinedButton(
                          onPressed: c.resolving ? null : c.resolve,
                          child: Text(
                            c.resolving
                                ? 'Saving...'
                                : 'I am safe - mark resolved',
                          ),
                        ),
                      const Text(
                        'Resolving the record cannot retract an SMS or notify a guardian that you are safe.',
                      ),
                      if (c.error != null) Text(c.error!),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: c.resolving ? null : c.dismiss,
                      child: const Text('Done'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WhatsAppButton extends StatefulWidget {
  final GuardianWhatsAppLink link;
  const _WhatsAppButton({required this.link});
  @override
  State<_WhatsAppButton> createState() => _WhatsAppButtonState();
}

class _WhatsAppButtonState extends State<_WhatsAppButton> {
  bool _opening = false;
  String? _notice;
  Future<void> _open() async {
    setState(() { _opening = true; _notice = null; });
    bool opened = false;
    try {
      opened = await launchUrl(widget.link.uri, mode: LaunchMode.externalApplication);
    } catch (_) { /* Keep SMS available if WhatsApp cannot open. */ }
    if (!mounted) return;
    setState(() {
      _opening = false;
      _notice = opened
          ? 'WhatsApp link opened. Check the recipient and tap Send. Delivery is not confirmed.'
          : 'Could not open WhatsApp. Use SMS or contact your guardian directly.';
    });
  }
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _opening ? null : _open,
        icon: const Icon(Icons.chat_outlined),
        label: Text('WhatsApp: ${widget.link.name.isEmpty ? 'Guardian' : widget.link.name}'),
      ),
      if (_notice != null) Text(_notice!),
    ],
  );
}

class SafetyDashboard extends StatelessWidget {
  const SafetyDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final c = SafetyScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: [
        Text(
          'Your safety controls',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Keep this app open while monitoring. Locking the phone or switching apps stops monitoring and cancels a pending countdown.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Fall monitoring'),
                subtitle: Text(
                  c.monitoring
                      ? 'Monitoring motion while the app is open'
                      : 'Off',
                ),
                value: c.monitoring,
                onChanged: c.setMonitoring,
              ),
              SwitchListTile(
                title: const Text('Demo mode'),
                subtitle: const Text(
                  'Lower shake threshold; automatic alerts are simulated. Real SOS stays real.',
                ),
                value: c.demo,
                onChanged: c.setDemo,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (c.notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Semantics(liveRegion: true, child: Text(c.notice!)),
          ),
        FilledButton.icon(
          onPressed: () => c.startCountdown(simulation: true),
          icon: const Icon(Icons.science_outlined),
          label: const Text('Practice countdown (no alerts)'),
        ),
        const SizedBox(height: 12),
        const Text(
          'For the sensor demo, enable Demo mode and Fall monitoring, then gently shake and rotate the phone. Do not drop it.',
        ),
        const SizedBox(height: 20),
        const Text(
          'Real SOS saves an alert and opens an SMS composer or phone dialer. This version cannot send messages unattended.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const StartTripScreen())),
          icon: const Icon(Icons.directions_walk),
          label: const Text('Start live trip'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Start a trip to open live tracking. Fall monitoring and trip tracking are separate controls.',
        ),
      ],
    );
  }
}
