// lib/screens/vela_shell.dart — Main shell with bottom nav.

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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 1,
            color: const Color(0x0FFFFFFF),
          ),
          Container(
            color: const Color(0xFF000000),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            child: VelaBottomNav(
              currentIndex: _currentIndex,
              onTap: _onTabTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    debugPrint('VelaShell._buildBody called, index=$_currentIndex');
    switch (_currentIndex) {
      case 1:
        debugPrint('VelaShell: showing SignalsScreen');
        return const SignalsScreen();
      case 4:
        debugPrint('VelaShell: showing ProfileScreenV2');
        return const ProfileScreenV2();
      default:
        debugPrint('VelaShell: showing DashboardScreen');
        return DashboardScreen(
          highlightEventId: widget.highlightEventId,
          recoveryEventId: widget.recoveryEventId,
        );
    }
  }
}