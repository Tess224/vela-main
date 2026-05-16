// lib/screens/vela_shell.dart — Main shell with bottom nav.
// Wraps Home, Signals, Goals, Profile tabs. Session opens as push.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/vela_bottom_nav.dart';
import 'dashboard_screen.dart';
import 'signals_screen.dart';
import 'profile_screen_v2.dart';

class VelaShell extends StatefulWidget {
  final String? highlightEventId;
  final String? recoveryEventId;

  const VelaShell({
    super.key,
    this.highlightEventId,
    this.recoveryEventId,
  });

  @override
  State<VelaShell> createState() => _VelaShellState();
}

class _VelaShellState extends State<VelaShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        highlightEventId: widget.highlightEventId,
        recoveryEventId: widget.recoveryEventId,
      ),
      const SignalsScreen(),
      const SizedBox.shrink(), // placeholder — session opens via push
      const _GoalsPlaceholder(),
      const ProfileScreenV2(),
    ];
  }

  void _onTabTap(int index) {
    if (index == 2) {
      final hour = DateTime.now().hour;
      final sessionType = hour < 14 ? 'morning' : 'evening';
      context.push('/session', extra: {'sessionType': sessionType});
      return;
    }
    if (index == 3) {
      context.push('/goals');
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: VelaBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

// Goals already has its own screen via router — this is just a fallback
class _GoalsPlaceholder extends StatelessWidget {
  const _GoalsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF000000),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFC9A6FF)),
      ),
    );
  }
}