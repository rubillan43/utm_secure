import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _maroon = Color(0xFF800000);

class ChatPage extends StatefulWidget {
  final String chatId;
  final String matchId;
  final String myRole; // 'owner' or 'finder'

  const ChatPage({
    super.key,
    required this.chatId,
    required this.matchId,
    required this.myRole,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Sender display label ──────────────────────────────────────────────────
  String _label(String senderId) {
    if (senderId == 'system') return 'Admin';
    final isMe = senderId == _uid;
    if (isMe) {
      return widget.myRole == 'owner' ? 'You (Owner)' : 'You (Finder)';
    }
    return widget.myRole == 'owner' ? 'Anonymous Finder' : 'Anonymous Owner';
  }

  bool _isMe(String senderId) => senderId == _uid;

  // ── Verify Owner button handler (finder only) ────────────────────────────
  Future<void> _handleVerifyOwner() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verify Owner',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Step 1: Send QR to chat. Step 2: During handover, scan the QR on the owner\'s phone.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              _BottomSheetOption(
                icon: Icons.qr_code_rounded,
                title: 'Send QR to Chat',
                subtitle: 'Owner will show this QR to you during handover',
                onTap: () => Navigator.pop(ctx, 'generate'),
              ),
              const SizedBox(height: 12),
              _BottomSheetOption(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scan Owner\'s QR',
                subtitle: 'Open camera to scan the QR on the owner\'s phone',
                onTap: () => Navigator.pop(ctx, 'scan'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'generate') {
      await _sendQrToChat();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _QrScanPage(
            matchId: widget.matchId,
            chatId: widget.chatId,
          ),
        ),
      );
    }
  }

  Future<void> _sendQrToChat() async {
    final token =
        'UTM_SECURE_${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}';
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(token)}';

    final db = FirebaseFirestore.instance;
    try {
      // Store qrToken in Chat (finder is a participant — has write access)
      await Future.wait([
        db.collection('Chats').doc(widget.chatId).update({
          'qrToken': token,
          'lastMessage': 'QR code for owner verification',
        }),
        db
            .collection('Chats')
            .doc(widget.chatId)
            .collection('Messages')
            .add({
          'senderId': 'system',
          'type': 'qr_verify',
          'qrUrl': qrUrl,
          'timestamp': FieldValue.serverTimestamp(),
        }),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send QR: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR sent. Ask the owner to open the chat and show it to you.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  // ── Send a text message ───────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    final db = FirebaseFirestore.instance;
    await db
        .collection('Chats')
        .doc(widget.chatId)
        .collection('Messages')
        .add({
      'senderId': _uid,
      'content': text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await db.collection('Chats').doc(widget.chatId).update({
      'lastMessage': text,
    });

    // Scroll to bottom after send
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Secure Chat',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.myRole == 'owner'
                  ? 'You are the Owner'
                  : 'You are the Finder',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: _maroon,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.shield_outlined,
                color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Chats')
            .doc(widget.chatId)
            .snapshots(),
        builder: (context, chatSnap) {
          final chatData =
              chatSnap.data?.data() as Map<String, dynamic>? ?? {};
          final isClosed = chatData['closed'] == true;

          return Column(
            children: [
              // ── Closed banner ───────────────────────────────────────────
              if (isClosed)
                Container(
                  width: double.infinity,
                  color: Colors.green.shade50,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Item successfully returned. This chat is closed.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Match details panel ─────────────────────────────────────
              _MatchDetailsPanel(matchId: widget.matchId),

              // ── Message list ────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Chats')
                      .doc(widget.chatId)
                      .collection('Messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child:
                              CircularProgressIndicator(color: _maroon));
                    }

                    final docs = snap.data?.docs ?? [];

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollCtrl.hasClients) {
                        _scrollCtrl.jumpTo(
                            _scrollCtrl.position.maxScrollExtent);
                      }
                    });

                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final msg =
                            docs[i].data() as Map<String, dynamic>;
                        final type =
                            msg['type'] as String? ?? 'text';
                        final senderId =
                            msg['senderId'] as String? ?? '';
                        final content =
                            msg['content'] as String? ?? '';

                            if (type == 'match_details') {
                          return _MatchDetailsCard(msg: msg);
                        }
                        if (type == 'qr_verify') {
                          return _QrVerifyCard(
                              qrUrl: msg['qrUrl'] as String? ?? '');
                        }
                        if (type == 'system') {
                          return _AdminMessage(content: content);
                        }

                        final isMe = _isMe(senderId);
                        return _ChatBubble(
                          content: content,
                          label: _label(senderId),
                          isMe: isMe,
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Input area ──────────────────────────────────────────────
              if (!isClosed)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                  child: Row(
                    children: [
                      if (widget.myRole == 'finder')
                        GestureDetector(
                          onTap: _handleVerifyOwner,
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: _maroon.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.qr_code_rounded,
                                    color: _maroon, size: 20),
                                SizedBox(height: 2),
                                Text(
                                  'Verify\nOwner',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _maroon,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _maroon,
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                          onPressed: _send,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// Persistent collapsible match details panel
// ─────────────────────────────────────────
class _MatchDetailsPanel extends StatefulWidget {
  final String matchId;
  const _MatchDetailsPanel({required this.matchId});

  @override
  State<_MatchDetailsPanel> createState() => _MatchDetailsPanelState();
}

class _MatchDetailsPanelState extends State<_MatchDetailsPanel> {
  bool _expanded = false;

  Future<Map<String, dynamic>?> _loadDetails() async {
    final db = FirebaseFirestore.instance;
    final matchDoc =
        await db.collection('Matches').doc(widget.matchId).get();
    if (!matchDoc.exists) return null;
    final match = matchDoc.data()!;

    final r1Future =
        db.collection('Reports').doc(match['reportId1'] as String).get();
    final r2Future =
        db.collection('Reports').doc(match['reportId2'] as String).get();
    final results = await Future.wait([r1Future, r2Future]);

    final r1 = results[0].data() ?? {};
    final r2 = results[1].data() ?? {};

    // Identify which is Lost and which is Found
    final lostReport =
        (r1['type'] == 'Lost') ? r1 : r2;
    final foundReport =
        (r1['type'] == 'Found') ? r1 : r2;

    return {
      'score': match['score'],
      'lost': lostReport,
      'found': foundReport,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadDetails(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final details = snap.data!;
        final score = (details['score'] as num? ?? 0).toDouble();
        final pct = (score * 100).toStringAsFixed(0);
        final isHigh = score >= 0.80;
        final lost = details['lost'] as Map<String, dynamic>;
        final found = details['found'] as Map<String, dynamic>;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _maroon.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              // ── Header row ──────────────────────────────────────
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 15, color: _maroon),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          'Match Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _maroon,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isHigh
                              ? Colors.green.shade600
                              : Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$pct% match',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: _maroon,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Expanded details ────────────────────────────────
              if (_expanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    children: [
                      _PanelSection(
                        label: 'Lost Report',
                        color: _maroon,
                        details: lost,
                      ),
                      const SizedBox(height: 10),
                      _PanelSection(
                        label: 'Found Report',
                        color: Colors.green.shade700,
                        details: found,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PanelSection extends StatelessWidget {
  final String label;
  final Color color;
  final Map<String, dynamic> details;
  const _PanelSection(
      {required this.label, required this.color, required this.details});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Category', details['category']),
      ('Colour', details['colour']),
      ('Brand', details['brand']),
      ('Location', details['location']),
      ('Description', details['description']),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 3,
                height: 13,
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(r.$1,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500)),
                  ),
                  const Text(': ',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  Expanded(
                    child: Text(
                      r.$2?.toString() ?? '—',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Match details card (type: 'match_details')
// ─────────────────────────────────────────
class _MatchDetailsCard extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _MatchDetailsCard({required this.msg});

  @override
  Widget build(BuildContext context) {
    final lost = msg['lostReport'] as Map<String, dynamic>? ?? {};
    final found = msg['foundReport'] as Map<String, dynamic>? ?? {};
    final score = (msg['matchScore'] as num? ?? 0).toDouble();
    final pct = (score * 100).toStringAsFixed(0);
    final isHigh = score >= 0.80;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _maroon.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _maroon,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Admin — Match Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isHigh
                            ? Colors.green.shade600
                            : Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pct% match',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Intro text ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Text(
                  'Please verify that these details match before arranging to return the item.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4),
                ),
              ),

              const Divider(height: 20, indent: 14, endIndent: 14),

              // ── Lost Report section ──────────────────────────────
              _ReportSection(
                label: 'Lost Report',
                labelColor: _maroon,
                details: lost,
              ),

              const Divider(height: 16, indent: 14, endIndent: 14),

              // ── Found Report section ─────────────────────────────
              _ReportSection(
                label: 'Found Report',
                labelColor: Colors.green.shade700,
                details: found,
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// One report section inside the card
// ─────────────────────────────────────────
class _ReportSection extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Map<String, dynamic> details;

  const _ReportSection({
    required this.label,
    required this.labelColor,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final fields = [
      ('Category', details['category']),
      ('Colour', details['colour']),
      ('Brand', details['brand']),
      ('Location', details['location']),
      ('Description', details['description']),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: labelColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...fields.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 86,
                    child: Text(
                      f.$1,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Text(
                    ': ',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  Expanded(
                    child: Text(
                      f.$2?.toString() ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// System / Admin message (centred card)
// ─────────────────────────────────────────
class _AdminMessage extends StatelessWidget {
  final String content;
  const _AdminMessage({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _maroon.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _maroon,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings_outlined,
                        size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  content,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Bottom sheet option row
// ─────────────────────────────────────────
class _BottomSheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BottomSheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _maroon.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _maroon.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _maroon, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// QR verification card (type: 'qr_verify')
// ─────────────────────────────────────────
class _QrVerifyCard extends StatelessWidget {
  final String qrUrl;
  const _QrVerifyCard({required this.qrUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _maroon.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: _maroon,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_rounded,
                        size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Owner Verification QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        qrUrl,
                        width: 210,
                        height: 210,
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : const SizedBox(
                                    width: 210,
                                    height: 210,
                                    child: Center(
                                        child: CircularProgressIndicator(
                                            color: _maroon)),
                                  ),
                        errorBuilder: (context, e, stack) => SizedBox(
                          width: 210,
                          height: 210,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_rounded,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'QR unavailable.\nCheck internet connection.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Owner: show this QR to the finder during handover.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// QR scanner page (finder scans owner's QR)
// ─────────────────────────────────────────
class _QrScanPage extends StatefulWidget {
  final String matchId;
  final String chatId;
  const _QrScanPage({required this.matchId, required this.chatId});

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() => _processing = true);

    try {
      // Read qrToken from Chat (stored there by _sendQrToChat)
      final chatDoc = await FirebaseFirestore.instance
          .collection('Chats')
          .doc(widget.chatId)
          .get();

      final storedToken = chatDoc.data()?['qrToken'] as String?;

      if (storedToken == null || storedToken != raw) {
        if (!mounted) return;
        _showResult(
          success: false,
          message: 'QR code is invalid or does not match this handover.',
        );
        return;
      }

      final db = FirebaseFirestore.instance;
      await Future.wait([
        db.collection('Matches').doc(widget.matchId).update({
          'status': 'resolved',
        }),
        db.collection('Chats').doc(widget.chatId).update({
          'closed': true,
          'qrToken': FieldValue.delete(),
        }),
        db
            .collection('Chats')
            .doc(widget.chatId)
            .collection('Messages')
            .add({
          'senderId': 'system',
          'content': '✓ Owner Verified. Item handover confirmed. This chat is now closed.',
          'type': 'system',
          'timestamp': FieldValue.serverTimestamp(),
        }),
      ]);

      if (!mounted) return;
      _showResult(
        success: true,
        message: 'Owner verified! The item handover is confirmed and marked as resolved.',
      );
    } catch (_) {
      if (!mounted) return;
      _showResult(success: false, message: 'Something went wrong. Try again.');
    }
  }

  void _showResult({required bool success, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(success ? 'Success' : 'Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // back to chat
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _maroon, foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Owner\'s QR'),
        backgroundColor: _maroon,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          // Overlay guide frame
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Point at the QR on the owner\'s phone',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black45,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Regular chat bubble
// ─────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final String content;
  final String label;
  final bool isMe;

  const _ChatBubble({
    required this.content,
    required this.label,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? _maroon : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Text(
                content,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
