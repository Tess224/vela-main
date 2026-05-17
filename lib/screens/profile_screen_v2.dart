// lib/screens/profile_screen_v2.dart — Profile tab.
// Follows prototype layout, backed by real UserModel + profile_completeness.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreenV2 extends StatelessWidget {
  const ProfileScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
          future: _fetchProfile(),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final name = data?['username'] as String? ?? 'User';
            final occupation = data?['occupation_type'] as String? ?? '';
            final completeness = (data?['profile_completeness'] as int? ?? 0) / 100;
            final hrvSource = data?['primary_hrv_source'] as String? ?? '';
            final tier = data?['subscription_tier'] as String? ?? 'free';
            final initials = _initials(name);

            return ListView(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x0FFFFFFF)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Profile',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF0F2F8),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/settings'),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0x0AFFFFFF),
                            border: Border.all(color: const Color(0x0FFFFFFF)),
                          ),
                          child: const Icon(Icons.settings_outlined, color: Color(0xFF8A92A8), size: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                // Hero — avatar + knowledge ring
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
                  child: Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 108,
                          height: 108,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _KnowledgeRing(pct: completeness, size: 108),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFC9A6FF), Color(0xFF7C5FCF)],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A0010),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF0F2F8),
                          ),
                        ),
                        if (occupation.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            occupation,
                            style: const TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 10,
                              letterSpacing: 0.6,
                              color: Color(0xFF8A92A8),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: const Color(0x14C9A6FF),
                            border: Border.all(color: const Color(0x40C9A6FF)),
                          ),
                          child: Text(
                            'PROFILE ${(completeness * 100).round()}% COMPLETE',
                            style: const TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 9.5,
                              letterSpacing: 1.0,
                              color: Color(0xFFC9A6FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Wearable section
                if (hrvSource.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
                    child: Text(
                      'CONNECTED WEARABLE',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: Color(0xFF8A92A8),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _WearableRow(name: hrvSource, active: true),
                  ),
                ],

                // Quick actions
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Text(
                    'ACCOUNT',
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      letterSpacing: 1.6,
                      color: Color(0xFF8A92A8),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0C10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x0FFFFFFF)),
                    ),
                    child: Column(
                      children: [
                        _SettingsRow(
                          icon: Icons.person_outline,
                          label: 'Edit profile',
                          onTap: () => context.push('/edit-profile'),
                        ),
                        Container(height: 1, color: const Color(0x0FFFFFFF)),
                        _SettingsRow(
                          icon: Icons.favorite_outline,
                          label: 'Health profile',
                          onTap: () => context.push('/health-profile'),
                        ),
                        Container(height: 1, color: const Color(0x0FFFFFFF)),
                        _SettingsRow(
                          icon: Icons.auto_awesome_outlined,
                          label: 'Subscription',
                          value: tier,
                          accent: true,
                          onTap: () => context.push('/subscription'),
                        ),
                        Container(height: 1, color: const Color(0x0FFFFFFF)),
                        _SettingsRow(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            );
          },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Future<Map<String, dynamic>?> _fetchProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      return await Supabase.instance.client
          .from('users')
          .select('username, occupation_type, profile_completeness, primary_hrv_source, subscription_tier')
          .eq('user_id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }
}

class _KnowledgeRing extends StatelessWidget {
  final double pct;
  final double size;

  const _KnowledgeRing({required this.pct, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RingPainter(pct: pct),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  _RingPainter({required this.pct});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;

    // Background ring
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x0FFFFFFF),
    );

    // Progress arc
    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: 3 * pi / 2,
      colors: const [Color(0xFFC9A6FF), Color(0xFF7C5FCF)],
    );

    final rect = Rect.fromCircle(center: center, radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * pct,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct;
}

class _WearableRow extends StatelessWidget {
  final String name;
  final bool active;

  const _WearableRow({required this.name, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? const Color(0x33C9A6FF) : const Color(0x0FFFFFFF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: active ? const Color(0x1AC9A6FF) : const Color(0x0AFFFFFF),
              border: Border.all(
                color: active ? const Color(0x4DC9A6FF) : const Color(0x0FFFFFFF),
              ),
            ),
            child: Icon(
              Icons.watch_outlined,
              color: active ? const Color(0xFFC9A6FF) : const Color(0xFF8A92A8),
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFF0F2F8),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Primary HRV source',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 9.5,
                    letterSpacing: 0.4,
                    color: Color(0xFF8A92A8),
                  ),
                ),
              ],
            ),
          ),
          if (active)
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFC9A6FF),
                boxShadow: [BoxShadow(color: Color(0xFFC9A6FF), blurRadius: 8)],
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool accent;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.accent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF8A92A8), size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFF0F2F8),
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  letterSpacing: 0.4,
                  color: accent ? const Color(0xFFC9A6FF) : const Color(0xFF8A92A8),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF4A5168), size: 14),
          ],
        ),
      ),
    );
  }
}