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

  void _onTabTap(int index) {
    if (index == 2) {
      // Session — push as overlay, don't switch tab
      final hour = DateTime.now().hour;
      final sessionType = hour < 14 ? 'morning' : 'evening';
      context.push('/session', extra: {'sessionType': sessionType});
      return;
    }
    if (index == 3) {
      // Goals — push the existing goals screen
      context.push('/goals');
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: _buildBody(),
      bottomNavigationBar: VelaBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return DashboardScreen(
          highlightEventId: widget.highlightEventId,
          recoveryEventId: widget.recoveryEventId,
        );
      case 1:
        return const SignalsScreen();
      case 4:
        return const ProfileScreenV2();
      default:
        return DashboardScreen(
          highlightEventId: widget.highlightEventId,
          recoveryEventId: widget.recoveryEventId,
        );
    }
  }
}