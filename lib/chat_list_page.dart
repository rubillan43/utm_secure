import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

const _maroon = Color(0xFF800000);

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Secure Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _maroon,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Chats')
            .where('participants', arrayContains: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _maroon));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 14),
                  Text(
                    'No chats yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chats will appear here when a\nmatch is found for your report.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          // Sort by createdAt descending client-side
          final sorted = docs.toList()
            ..sort((a, b) {
              final ta = (a.data() as Map)['createdAt'] as Timestamp?;
              final tb = (b.data() as Map)['createdAt'] as Timestamp?;
              if (ta == null || tb == null) return 0;
              return tb.compareTo(ta);
            });

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sorted.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) {
              final doc = sorted[i];
              final data = doc.data() as Map<String, dynamic>;
              final isClosed = data['closed'] == true;
              final lastMessage =
                  data['lastMessage'] as String? ?? 'New match chat';
              final matchId = data['matchId'] as String? ?? '';
              final myRole =
                  (data['roles'] as Map<String, dynamic>?)?[uid] as String? ??
                      'owner';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: isClosed
                      ? Colors.grey.shade200
                      : _maroon.withValues(alpha: 0.12),
                  child: Icon(
                    isClosed
                        ? Icons.lock_outline
                        : Icons.shield_outlined,
                    color: isClosed ? Colors.grey : _maroon,
                    size: 22,
                  ),
                ),
                title: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Secure Chat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isClosed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'CLOSED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      chatId: doc.id,
                      matchId: matchId,
                      myRole: myRole,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
