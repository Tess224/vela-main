// lib/screens/vela_shell.dart — Main shell with bottom nav.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/vela_bottom_nav.dart';
import 'dashboard_screen.dart';
import 'signals_screen.dart';
import 'profile_screen_v2.dart';

class VelaShell extends ConsumerStatefulWidget {
  final String? highlightEventId;
  final String? recoveryEventId;

  const VelaShell({
    super.key,
    this.highlightEventId,
    this.recoveryEventId,
  });

  @override
  ConsumerState<VelaShell> createState() => _VelaShellState();
}

class _VelaShellState extends ConsumerState<VelaShell> {
  int _currentIndex = 0;

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
      body: SafeArea(
        bottom: false,
        child: _buildBody(),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          border: Border(
            top: BorderSide(color: Color(0x0FFFFFFF), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: VelaBottomNav(
            currentIndex: _currentIndex,
            onTap: _onTabTap,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 1:
        return const SignalsScreen();
      case 4:
        return const ProfileScreenV2();
      default:
        return _DashboardTab(
          highlightEventId: widget.highlightEventId,
          recoveryEventId: widget.recoveryEventId,
          ref: ref,
        );
    }
  }
}

/// Dashboard as a plain widget (not a Scaffold) so it works inside VelaShell's Scaffold.
class _DashboardTab extends StatelessWidget {
  final String? highlightEventId;
  final String? recoveryEventId;
  final WidgetRef ref;

  const _DashboardTab({
    this.highlightEventId,
    this.recoveryEventId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardContent(
      highlightEventId: highlightEventId,
      recoveryEventId: recoveryEventId,
      ref: ref,
    );
  }
}