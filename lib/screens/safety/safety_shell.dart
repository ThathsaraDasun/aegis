import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/safety/background_monitor.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/alert_service.dart';
import '../../services/automatic_sms_service.dart';
import '../../services/live_sharing_service.dart';
import '../../services/auth_service.dart';
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
  final bool showFloatingSos;
  const SafetyShell({
    super.key,
    required this.homeBuilder,
    this.controller,
    this.showFloatingSos = false,
  });
  @override
  State<SafetyShell> createState() => _SafetyShellState();
}

class _SafetyShellState extends State<SafetyShell> with WidgetsBindingObserver {
  late final SafetyController controller =
      widget.controller ??
      SafetyController(
        motion: DeviceMotionFeed(),
        gateway: BackendSosGateway(),
        backgroundMonitor:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? BackgroundMonitor()
            : null,
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
            if (widget.showFloatingSos && controller.phase == SafetyPhase.idle)
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
                          : c.automaticSms
                          ? 'If you do not cancel, Aegis will attempt to send SMS to your guardians using your SIM. SMS charges may apply.'
                          : 'When time runs out, open Aegis to prepare the alert. Someone must tap Send; automatic SMS is off.',
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
                      c.eventIsDemo
                          ? 'Demo completed'
                          : c.result!.recorded
                          ? 'Alert recorded'
                          : 'Guardian SMS result',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    if (c.eventIsDemo)
                      const Text(
                        'The countdown reached escalation. No contacts were notified and no alert was saved.',
                      )
                    else ...[
                      Text(
                        c.result!.automaticSmsMessage ??
                            (c.result!.smsOpened
                                ? 'SMS option opened. Choose Messages or Messaging, not WhatsApp, in the chooser. Tap Send yourself. Delivery has not been confirmed.'
                                : c.result!.dialerOpened
                                ? 'Phone dialer opened. You must start the call yourself.'
                                : c.result!.contactCount == 0
                                ? 'No usable contacts were found. Nobody was contacted. Add a guardian before your next walk.'
                                : 'SMS and phone apps could not be opened. Contact your guardian directly.'),
                      ),
                      const SizedBox(height: 12),
                      SelectableText('Alert ID: ${c.result!.alertId}'),
                      if (c.result!.automaticSmsMessage != null &&
                          c.result!.manualSmsUri != null)
                        TextButton(
                          onPressed: () async {
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Open SMS manually?'),
                                content: const Text(
                                  'Check Messages first: an automatic SMS may already have been sent. Sending again can duplicate the alert. In the chooser, select Messages or Messaging, not WhatsApp.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Open Messages'),
                                  ),
                                ],
                              ),
                            );
                            if (proceed != true) return;
                            try {
                              final opened = await launchUrl(
                                c.result!.manualSmsUri!,
                                mode: LaunchMode.externalApplication,
                              );
                              if (!opened) {
                                throw StateError('SMS app unavailable');
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not open Messages. Contact your guardian directly.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Open SMS manually'),
                        ),
                      if (!c.result!.recorded)
                        const Text(
                          'This background event could not be saved to Activity. The SMS result above is separate from the database record.',
                        ),
                      if (c.result!.whatsAppLinks.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Prefer WhatsApp? Close the SMS chooser and use a button below. Send separately to each guardian. Opening a chat does not send the message.',
                        ),
                        for (final link in c.result!.whatsAppLinks)
                          _WhatsAppButton(link: link),
                      ],
                      const SizedBox(height: 12),
                      if (c.result!.liveLocationUrl != null && !c.resolved)
                        const Text(
                          'A private live-location link was included in the message. Anyone with it can view for up to one hour. '
                          'Done leaves sharing running. Mark safe below or use Stop sharing in the phone notification to end it. '
                          'GPS and internet are needed for updates; force-stopping Aegis stops updates.',
                        ),
                      if (c.result!.liveLocationUrl == null)
                        const Text(
                          'No live-location link was included. The message uses the location available when SOS started.',
                        ),
                      if (c.resolved)
                        Text(
                          c.result!.recorded
                              ? 'Marked resolved. Location link stopped.'
                              : 'Location link stopped.',
                        )
                      else if (c.result!.recorded ||
                          c.result!.liveLocationUrl != null)
                        OutlinedButton(
                          onPressed: c.resolving ? null : c.resolve,
                          child: Text(
                            c.resolving
                                ? 'Saving...'
                                : 'I am safe - stop sharing',
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
    setState(() {
      _opening = true;
      _notice = null;
    });
    bool opened = false;
    try {
      opened = await launchUrl(
        widget.link.uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      /* Keep SMS available if WhatsApp cannot open. */
    }
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
        label: Text(
          'WhatsApp: ${widget.link.name.isEmpty ? 'Guardian' : widget.link.name}',
        ),
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
          'On Android, enabled fall monitoring continues when you lock the phone or switch apps. Keep the protection notification enabled. Force-stopping or removing Aegis from recent apps stops protection.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Fall monitoring'),
                subtitle: Text(
                  c.changingMonitoring
                      ? 'Updating protection…'
                      : c.monitoring
                      ? 'Monitoring active — check the protection notification'
                      : 'Off',
                ),
                value: c.monitoring,
                onChanged: c.changingMonitoring || c.changingSms
                    ? null
                    : c.setMonitoring,
              ),
              SwitchListTile(
                title: const Text('Demo mode'),
                subtitle: const Text(
                  'Lower shake threshold; automatic alerts are simulated. Real SOS stays real.',
                ),
                value: c.demo,
                onChanged: c.changingMonitoring || c.changingSms
                    ? null
                    : c.setDemo,
              ),
              if (AutomaticSmsService.supported)
                SwitchListTile(
                  title: const Text('Automatic guardian SMS'),
                  subtitle: Text(
                    c.changingSms
                        ? 'Checking SMS setup…'
                        : c.monitoring
                        ? 'Stop monitoring before changing SMS settings.'
                        : 'Uses your default SMS SIM. Charges may apply. Enable again after changing guardians or signing in again.',
                  ),
                  value: c.automaticSms,
                  onChanged:
                      c.monitoring || c.changingSms || c.changingMonitoring
                      ? null
                      : (value) async {
                          if (value) {
                            final agreed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Enable automatic SMS?'),
                                content: const Text(
                                  'Real SOS and uncancelled real fall countdowns will send SMS to your saved guardians without another Send button, including while locked. Your name and available location are included. Your SIM must have service and SMS credit; long messages may cost more than one SMS. Select a default SMS SIM in Android Settings first. Demo countdowns never send. Only enable this with guardians who expect your alerts.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Enable automatic SMS'),
                                  ),
                                ],
                              ),
                            );
                            if (agreed != true) return;
                          }
                          await c.setAutomaticSms(value);
                        },
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
          onPressed: c.changingMonitoring
              ? null
              : () async {
                  if (c.monitoring) await c.setMonitoring(false);
                  c.startCountdown(simulation: true);
                },
          icon: const Icon(Icons.science_outlined),
          label: const Text('Practice countdown (no alerts)'),
        ),
        const SizedBox(height: 12),
        const Text(
          'For the sensor demo, enable Demo mode and Fall monitoring, then gently shake and rotate the phone. Do not drop it. Practice countdown stops monitoring; enable it again afterwards.',
        ),
        const SizedBox(height: 12),
        const Text(
          'With Automatic guardian SMS enabled, an uncancelled real fall countdown attempts SMS even while locked. Otherwise, open Aegis to send manually. Background monitoring uses extra battery and may be stopped by Android battery controls.',
        ),
        const SizedBox(height: 20),
        const Text(
          'Real SOS saves an alert. With Automatic guardian SMS enabled it attempts SIM SMS directly; otherwise it opens manual contact options. WhatsApp always needs you to tap Send. When available, SOS includes a private live-location link for up to one hour. Anyone with that link can view. Stop it below, from the SOS result, or from the phone notification.',
        ),
        if (LiveSharingService.supported)
          OutlinedButton.icon(
            icon: const Icon(Icons.location_disabled_outlined),
            label: const Text('Stop SOS location sharing'),
            onPressed: () async {
              String message;
              try {
                await LiveSharingService.stop();
                message =
                    'SOS location sharing stopped. This does not send an all-clear message.';
              } catch (e) {
                message = authErrorMessage(e);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              }
            },
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: c.manualSos,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.sos, size: 24),
          label: const Text(
            'Trigger Real SOS Now',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
