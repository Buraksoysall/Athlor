import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminModerationPage extends StatelessWidget {
  const AdminModerationPage({super.key});

  Future<void> _resolveReport(DocumentSnapshot report) async {
    await report.reference.update({'status': 'resolved', 'resolvedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _blockChatAndPurgeMessages(BuildContext context, DocumentSnapshot report) async {
    try {
      final data = report.data() as Map<String, dynamic>;
      final chatId = (data['metadata']?['chatId'] ?? '') as String;
      if (chatId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ChatId bulunamadı'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // Onay diyaloğu
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sohbeti Engelle'),
          content: Text('ChatId: $chatId\n\nBu sohbet engellenecek ve TÜM mesajlar silinecek. Devam edilsin mi?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet')),
          ],
        ),
      );
      if (confirmed != true) return;

      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final chatSnap = await chatRef.get();
      List<dynamic> participants = [];
      if (chatSnap.exists) {
        final d = chatSnap.data() as Map<String, dynamic>;
        participants = (d['participants'] as List?) ?? [];
      }

      // 1) Sohbeti engelle
      await chatRef.set({
        'blocked': true,
        'blockedBy': 'admin',
        'blockedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2) Tüm mesajları partiler halinde sil
      while (true) {
        final msgs = await chatRef.collection('messages').limit(300).get();
        if (msgs.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final m in msgs.docs) {
          batch.delete(m.reference);
        }
        await batch.commit();
        if (msgs.docs.length < 300) break; // son sayfa
      }

      // 3) İki tarafı da birbirini engelle olarak işaretle (varsa)
      if (participants.length >= 2) {
        final a = participants[0] as String;
        final b = participants[1] as String;
        final users = FirebaseFirestore.instance.collection('users');
        await users.doc(a).collection('blocked').doc(b).set({
          'blockedUserId': b,
          'reason': 'admin_block_chat',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await users.doc(b).collection('blocked').doc(a).set({
          'blockedUserId': a,
          'reason': 'admin_block_chat',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await _resolveReport(report);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sohbet engellendi ve tüm mesajlar silindi (ChatId: $chatId)'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sohbet engelleme/silme hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeContent(BuildContext context, DocumentSnapshot report) async {
    try {
      final data = report.data() as Map<String, dynamic>;
      final contentType = data['contentType'] as String? ?? '';
      final contentId = data['contentId'] as String? ?? '';
      final chatId = (data['metadata']?['chatId'] ?? '') as String;

      // Onay diyaloğu
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('İşlemi Onayla'),
          content: Text('Tür: $contentType\nID: $contentId${chatId.isNotEmpty ? '\nChatId: $chatId' : ''}\n\nDevam etmek istiyor musunuz?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet')),
          ],
        ),
      );
      if (confirmed != true) return;

      String resultMsg;
      Color resultColor = Colors.red;

      if (contentType == 'comment') {
        await FirebaseFirestore.instance.collection('comments').doc(contentId).delete();
        resultMsg = 'Yorum kaldırıldı ve rapor çözüldü';
      } else if (contentType == 'activity') {
        await FirebaseFirestore.instance.collection('activities').doc(contentId).delete();
        resultMsg = 'Aktivite kaldırıldı ve rapor çözüldü';
      } else if (contentType == 'message') {
        if (chatId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .doc(contentId)
              .delete();
          resultMsg = 'Mesaj kaldırıldı ve rapor çözüldü';
        } else {
          resultMsg = 'Mesaj ChatId eksik olduğu için kaldırılamadı';
          resultColor = Colors.orange;
        }
      } else if (contentType == 'user') {
        // Kullanıcıyı kaldırmıyoruz; flagged işaretliyoruz
        final userId = contentId;
        await FirebaseFirestore.instance.collection('users').doc(userId).set({'flagged': true}, SetOptions(merge: true));
        resultMsg = 'Kullanıcı flagged olarak işaretlendi ve rapor çözüldü';
        resultColor = Colors.blue;
      } else {
        resultMsg = 'Bilinmeyen içerik türü';
        resultColor = Colors.orange;
      }

      await _resolveReport(report);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resultMsg), backgroundColor: resultColor),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaldırma hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderasyon - Raporlar'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Açık rapor bulunmuyor'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data() as Map<String, dynamic>;
              final contentType = data['contentType'] ?? '';
              final status = data['status'] ?? 'open';
              final createdAtTs = data['createdAt'];
              DateTime? createdAt;
              if (createdAtTs is Timestamp) {
                createdAt = createdAtTs.toDate();
              } else if (createdAtTs is DateTime) {
                createdAt = createdAtTs;
              }
              final isOverdue = createdAt != null && DateTime.now().difference(createdAt).inHours >= 24 && status == 'open';
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text('Tür: $contentType  •  Durum: $status')),
                      if (isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Overdue',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text('Neden: ${data['reason'] ?? ''}\nİçerikId: ${data['contentId'] ?? ''}\nRaporlayan: ${data['reporterId'] ?? ''}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'resolve') {
                        await _resolveReport(d);
                      } else if (v == 'remove') {
                        await _removeContent(context, d);
                      } else if (v == 'block_chat') {
                        await _blockChatAndPurgeMessages(context, d);
                      }
                    },
                    itemBuilder: (context) {
                      final data = d.data() as Map<String, dynamic>;
                      final hasChat = ((data['metadata']?['chatId'] ?? '') as String).isNotEmpty;
                      return [
                        const PopupMenuItem(value: 'remove', child: Text('İçeriği Kaldır')),
                        const PopupMenuItem(value: 'resolve', child: Text('Raporu Çöz')),
                        if (hasChat) const PopupMenuItem(value: 'block_chat', child: Text('Sohbeti Engelle ve Mesajları Sil')),
                      ];
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Restrict: Only allow admin by email domain or flag
          final current = FirebaseAuth.instance.currentUser;
          if (current == null) return;
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(current.uid).get();
          final isAdmin = userDoc.data()?['isAdmin'] == true;
          if (!isAdmin) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yetkiniz yok'), backgroundColor: Colors.red),
              );
            }
            return;
          }
          // Optional admin action placeholder
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Admin paneli açık'), backgroundColor: Colors.blue),
            );
          }
        },
        label: const Text('Admin'),
        icon: const Icon(Icons.admin_panel_settings),
      ),
    );
  }
}
