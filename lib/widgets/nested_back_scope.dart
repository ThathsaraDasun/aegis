import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Android's back button only reaches the app's outermost [Navigator].
/// Wrap a nested [Navigator] with this so back presses go to it first, and
/// the app only closes when it has nothing left to go back to.
class NestedBackScope extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const NestedBackScope({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// Goes back inside [navigator] (closing a page, or letting that page's own
  /// back handling run). Leaves the app if there is nothing to go back to.
  static Future<void> backOrExit(NavigatorState? navigator) async {
    final handled = await navigator?.maybePop() ?? false;
    if (!handled) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      await backOrExit(navigatorKey.currentState);
    },
    child: child,
  );
}
