import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'report_form_page.dart';
import 'chat_list_page.dart';
import 'profile_page.dart';
import 'chat_page.dart';

const _maroon = Color(0xFF800000);
const _maroonDark = Color(0xFF5C0000);

// ─────────────────────────────────────────
// Shell: bottom-nav wrapper
// ─────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    _DashboardView(),
    ChatListPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: _maroon,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12),
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Dashboard view
// ─────────────────────────────────────────
class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // ── Gradient AppBar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: _maroon,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_maroonDark, _maroon],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.security_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'UTM SECURE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Lost something?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Report it and let us find a match.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Action buttons ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          label: 'Report Lost',
                          sublabel: 'Missing something?',
                          icon: Icons.search_off_rounded,
                          gradient: const LinearGradient(
                            colors: [_maroonDark, _maroon],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReportFormPage(
                                  reportType: 'Lost'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ActionCard(
                          label: 'Report Found',
                          sublabel: 'Found something?',
                          icon: Icons.inventory_2_outlined,
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade800,
                              Colors.green.shade600
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReportFormPage(
                                  reportType: 'Found'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Matched Reports heading ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _maroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.compare_arrows_rounded,
                            color: _maroon, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Matched Reports',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    'Tap a match to open the secure chat',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Matches list ─────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Matches')
                .where('involvedUsers', arrayContains: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                        child: CircularProgressIndicator(color: _maroon)),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(child: _EmptyMatchesPlaceholder());
              }

              final docs = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final ta = (a.data() as Map)['timestamp'] as Timestamp?;
                  final tb = (b.data() as Map)['timestamp'] as Timestamp?;
                  if (ta == null || tb == null) return 0;
                  return tb.compareTo(ta);
                });

              return SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MatchCard(
                        matchId: docs[i].id,
                        data: docs[i].data() as Map<String, dynamic>,
                      ),
                    ),
                    childCount: docs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Gradient action card
// ─────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.15),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sublabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Match card
// ─────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final String matchId;
  final Map<String, dynamic> data;
  const _MatchCard({required this.matchId, required this.data});

  @override
  Widget build(BuildContext context) {
    final score = (data['score'] as num? ?? 0).toDouble();
    final pct = (score * 100).toStringAsFixed(0);
    final category = data['category'] as String? ?? 'Item';
    final summary = data['summary'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';
    final isHighConfidence = score >= 0.80;
    final chatId = data['chatId'] as String?;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final scoreColor =
        isHighConfidence ? Colors.green.shade700 : _maroon;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (chatId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Chat not ready yet. Try again shortly.')),
            );
            return;
          }
          final chatDoc = await FirebaseFirestore.instance.collection('Chats').doc(chatId).get();
          final myRole = (chatDoc.data()?['roles'] as Map<String, dynamic>?)?[uid] as String? ?? 'finder';
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                chatId: chatId,
                matchId: matchId,
                myRole: myRole,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.compare_arrows_rounded,
                    color: scoreColor, size: 26),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    _StatusBadge(status: status),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Score + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scoreColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'matched' => ('Matched', Colors.blue.shade700, Icons.link_rounded),
      'resolved' => ('Resolved', Colors.green.shade700, Icons.check_circle_outline),
      'sensitive' => ('Sensitive', Colors.orange.shade700, Icons.warning_amber_outlined),
      _ => ('Pending', Colors.grey.shade500, Icons.hourglass_empty_rounded),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────
class _EmptyMatchesPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.find_in_page_outlined,
                size: 56, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 20),
          const Text(
            'No matches yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submit a lost or found report to\nactivate the matching algorithm.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400, height: 1.5),
          ),
        ],
      ),
    );
  }
}
