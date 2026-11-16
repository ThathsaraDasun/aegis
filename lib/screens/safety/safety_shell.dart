import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/safety/background_monitor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/aegis_theme.dart';
import '../../services/alert_service.dart';
import '../../services/automatic_sms_service.dart';
import '../trip/start_trip_screen.dart';
import '../../services/safety/motion_feed.dart';
import '../../services/safety/safety_controller.dart';
import '../../services/safety/sos_gateway.dart';

/// Floating SOS button in the Aegis blue palette. Tapping it calls the same
/// manual SOS action as before.
class _SosButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SosButton({required this.onPressed});

  static const Color _azure = Color(0xFF007FFF);
  static const Color _dodger = Color(0xFF1E90FF);

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Send SOS alert',
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(40),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_azure, _dodger],
        ),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _azure.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.crisis_alert_rounded,
                    color: _azure,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

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

  /// Number of open pages that hide the floating SOS button (e.g. Edit
  /// Profile). Only the button is hidden; SOS and fall detection keep working.
  static final ValueNotifier<int> sosButtonHiders = ValueNotifier<int>(0);

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
              ValueListenableBuilder<int>(
                valueListenable: SafetyShell.sosButtonHiders,
                builder: (context, hiders, _) => hiders > 0
                    ? const SizedBox.shrink()
                    : Positioned(
                        right: 16,
                        bottom: 88 + MediaQuery.paddingOf(context).bottom,
                        child: _SosButton(onPressed: controller.manualSos),
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
                      if (c.resolved)
                        const Text('Marked resolved in your activity log.')
                      else if (c.result!.recorded)
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

  Future<void> _confirmAutomaticSms(
    BuildContext context,
    SafetyController c,
    bool value,
  ) async {
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable automatic SMS'),
            ),
          ],
        ),
      );
      if (agreed != true) return;
    }
    await c.setAutomaticSms(value);
  }

  @override
  Widget build(BuildContext context) {
    final c = SafetyScope.of(context);
    final busy = c.changingMonitoring || c.changingSms;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Your safety controls', style: text.headlineSmall),
            ),
            IconButton(
              tooltip: 'How protection works',
              icon: const Icon(Icons.info_outline, color: AegisColors.primary),
              onPressed: () => showSafetyGuide(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _SafetyGuideTip(),
        _ProtectionStatusCard(active: c.monitoring, sms: c.automaticSms),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.personal_injury_outlined),
                title: const Text('Fall monitoring'),
                subtitle: Text(
                  c.changingMonitoring
                      ? 'Updating protection…'
                      : c.monitoring
                      ? 'On – works even when the phone is locked'
                      : 'Detects a hard fall and starts a countdown',
                ),
                value: c.monitoring,
                onChanged: busy ? null : c.setMonitoring,
              ),
              if (AutomaticSmsService.supported) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.sms_outlined),
                  title: const Text('Automatic guardian SMS'),
                  subtitle: Text(
                    c.changingSms
                        ? 'Checking SMS setup…'
                        : c.monitoring
                        ? 'Turn off fall monitoring to change this'
                        : 'Texts your guardians if you don\'t respond',
                  ),
                  value: c.automaticSms,
                  onChanged: c.monitoring || busy
                      ? null
                      : (value) => _confirmAutomaticSms(context, c, value),
                ),
              ],
            ],
          ),
        ),
        if (c.notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(liveRegion: true, child: Text(c.notice!)),
          ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const StartTripScreen())),
            icon: const Icon(Icons.directions_walk),
            label: const Text('Start live trip'),
          ),
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
        Card(
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Practice & testing'),
              subtitle: const Text(
                'Try the countdown safely – no alerts are sent',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Demo mode'),
                  subtitle: const Text(
                    'Easier to trigger with a gentle shake; alerts are only simulated. Real SOS stays real.',
                  ),
                  value: c.demo,
                  onChanged: busy ? null : c.setDemo,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: c.changingMonitoring
                      ? null
                      : () async {
                          if (c.monitoring) await c.setMonitoring(false);
                          c.startCountdown(simulation: true);
                        },
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Practice countdown (no alerts)'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Practice stops fall monitoring – switch it on again afterwards.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Big, glanceable "am I protected?" summary at the top of the Safety tab.
class _ProtectionStatusCard extends StatelessWidget {
  final bool active;
  final bool sms;
  const _ProtectionStatusCard({required this.active, required this.sms});

  @override
  Widget build(BuildContext context) {
    final color = active ? AegisColors.primary : AegisColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                colors: [AegisColors.azure, AegisColors.dodgerBlue],
              )
            : null,
        color: active ? null : Colors.white,
        borderRadius: BorderRadius.circular(AegisRadius.xl),
        border: active ? null : Border.all(color: AegisColors.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.2)
                  : AegisColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.verified_user : Icons.shield_outlined,
              color: active ? Colors.white : color,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'You are protected' : 'Protection is off',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : AegisColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? (sms
                            ? 'Fall monitoring on · guardians get an SMS if you don\'t respond'
                            : 'Fall monitoring on · you send the alert yourself')
                      : 'Turn on fall monitoring before you walk alone',
                  style: TextStyle(
                    fontSize: 13,
                    color: active
                        ? Colors.white.withValues(alpha: 0.9)
                        : AegisColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One-time "new here?" tip. Dismissed for good once closed or opened.
class _SafetyGuideTip extends StatefulWidget {
  const _SafetyGuideTip();
  @override
  State<_SafetyGuideTip> createState() => _SafetyGuideTipState();
}

class _SafetyGuideTipState extends State<_SafetyGuideTip> {
  static const _prefKey = 'safety_guide_seen';
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) {
          if (mounted && p.getBool(_prefKey) != true)
            setState(() => _visible = true);
        })
        .catchError((_) {});
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefKey, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(
          color: AegisColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AegisRadius.lg),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: AegisColors.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('New to Aegis? See how protection works.'),
            ),
            TextButton(
              onPressed: () {
                _dismiss();
                showSafetyGuide(context);
              },
              child: const Text('Show me'),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close, size: 18),
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// "How protection works" – the detailed guidance, shown only on request.
Future<void> showSafetyGuide(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            'How protection works',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const _GuideItem(
            icon: Icons.personal_injury_outlined,
            title: 'Fall monitoring',
            body:
                'Keeps working when you lock the phone or switch apps on Android. Keep the protection notification on. Force-stopping Aegis or swiping it away from recent apps stops protection, and Android battery saving may also stop it.',
          ),
          const _GuideItem(
            icon: Icons.timer_outlined,
            title: 'The countdown',
            body:
                'After a possible fall you get a countdown. Tap "I am OK" to cancel. If you don\'t respond, Aegis alerts your guardians.',
          ),
          const _GuideItem(
            icon: Icons.sms_outlined,
            title: 'Automatic guardian SMS',
            body:
                'When on, an uncancelled real countdown sends SMS from your default SIM, even while locked. Charges may apply. When off, open Aegis and send the alert yourself. Turn it on again after changing guardians or signing in again.',
          ),
          const _GuideItem(
            icon: Icons.sos,
            title: 'Real SOS button',
            body:
                'Always saves an alert. With automatic SMS on it texts your guardians directly; otherwise it opens contact options. WhatsApp always needs you to tap Send.',
          ),
          const _GuideItem(
            icon: Icons.directions_walk,
            title: 'Live trips',
            body:
                'Start a trip to share live tracking. Fall monitoring and trip tracking are separate – you can use either or both.',
          ),
          const _GuideItem(
            icon: Icons.science_outlined,
            title: 'Practising',
            body:
                'Turn on Demo mode and Fall monitoring, then gently shake and rotate the phone – never drop it. Demo countdowns never contact anyone.',
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    ),
  );
}

class _GuideItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _GuideItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AegisColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AegisRadius.md),
            ),
            child: Icon(icon, size: 20, color: AegisColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AegisColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
