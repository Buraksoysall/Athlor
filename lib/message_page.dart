import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'users_page.dart';
import 'chat_page.dart';
import 'user_status_service.dart';
import 'unread_message_service.dart';
import 'block_service.dart';

class MessagePage extends StatefulWidget {
  final Function(String)? onChatOpened;
  final Set<String>? readChats;
  
  const MessagePage({super.key, this.onChatOpened, this.readChats});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final UserStatusService _userStatusService = UserStatusService();
  


  // Kullanıcı profil fotoğrafını al
  Future<String?> _getUserProfileImage(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['profileImageUrl'];
      }
      return null;
    } catch (e) {
      print('Profil fotoğrafı alınırken hata: $e');
      return null;
    }
  }

  // Engellenen kullanıcıları filtrele
  Future<List<Map<String, dynamic>>> _getFilteredChats(List<QueryDocumentSnapshot> chatDocs) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    
    List<Map<String, dynamic>> filteredChats = [];
    
    for (final doc in chatDocs) {
      final chat = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(chat['participants'] ?? []);
      final currentUserId = currentUser.uid;
      
      // Diğer kullanıcının ID'sini bul
      final otherUserIndex = participants.indexOf(currentUserId) == 0 ? 1 : 0;
      final otherUserId = participants.length > otherUserIndex 
          ? participants[otherUserIndex] 
          : '';
      
      if (otherUserId.isNotEmpty) {
        // Engel kontrolü yap
        final isBlocked = await BlockService.isBlocked(currentUserId, otherUserId);
        if (!isBlocked) {
          filteredChats.add({
            'chat': chat,
            'chatId': doc.id,
          });
        }
      }
    }
    
    return filteredChats;
  }

  // Kullanıcı adını al
  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        String displayName = userData?['displayName'] ?? '';
        String username = userData?['username'] ?? '';
        String email = userData?['email'] ?? '';
        
        // Öncelik sırası: displayName > username > email (kullanıcı adı kısmı) > 'Kullanıcı'
        if (displayName.isNotEmpty) {
          return displayName;
        } else if (username.isNotEmpty) {
          return username;
        } else if (email.isNotEmpty) {
          // Email'den kullanıcı adı çıkar (@ işaretinden önceki kısım)
          return email.split('@')[0];
        }
      }
      return 'Kullanıcı';
    } catch (e) {
      print('Kullanıcı adı alınırken hata: $e');
      return 'Kullanıcı';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1B29),
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0E1E3A).withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
              },
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Color(0xFFFFFFFF),
                size: 20,
              ),
            ),
          ),
        ),
        actions: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0E1E3A).withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UsersPage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.person_add,
                color: Color(0xFFFFFFFF),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: false,
        elevation: 0,
        title: Text(
          'Mesajlar',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Bir hata oluştu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF3B30),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hata: ${snapshot.error}',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFFFFFFFF).withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8A2BE2)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: const Color(0xFF8A2BE2).withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz sohbet yok',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sağ üstteki + butonuna tıklayarak\nkullanıcı bulabilirsin!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFFFFFFF).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _getFilteredChats(snapshot.data!.docs),
            builder: (context, filteredSnapshot) {
              if (filteredSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8A2BE2)),
                  ),
                );
              }

              final filteredChats = filteredSnapshot.data ?? [];

              // Son etkinliğe (lastMessageTime > createdAt) göre sıralama: en yeni üste
              final sortedChats = [...filteredChats];
              sortedChats.sort((a, b) {
                final Map<String, dynamic> aChat = a['chat'] as Map<String, dynamic>;
                final Map<String, dynamic> bChat = b['chat'] as Map<String, dynamic>;

                final Timestamp? aTs = (aChat['lastMessageTime'] ?? aChat['createdAt']) as Timestamp?;
                final Timestamp? bTs = (bChat['lastMessageTime'] ?? bChat['createdAt']) as Timestamp?;

                final DateTime aTime = aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                final DateTime bTime = bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

                return bTime.compareTo(aTime); // Descending
              });

              if (filteredChats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: const Color(0xFF8A2BE2).withOpacity(0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz sohbet yok',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sağ üstteki + butonuna tıklayarak\nkullanıcı bulabilirsin!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFFFFF).withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedChats.length,
                itemBuilder: (context, index) {
                  final chatData = sortedChats[index];
                  final chat = chatData['chat'] as Map<String, dynamic>;
                  final chatId = chatData['chatId'] as String;
                  final participants = List<String>.from(chat['participants'] ?? []);
                  final participantNames = List<String>.from(chat['participantNames'] ?? []);
                  final currentUser = FirebaseAuth.instance.currentUser;

                  final currentUserId = currentUser?.uid ?? '';
                  final otherUserIndex = participants.indexOf(currentUserId) == 0 ? 1 : 0;
                  final otherUserName = participantNames.length > otherUserIndex
                      ? participantNames[otherUserIndex]
                      : 'Kullanıcı';
                  final otherUserId = participants.length > otherUserIndex
                      ? participants[otherUserIndex]
                      : '';
                  final lastMessage = chat['lastMessage'] ?? '';
                  final lastMessageTime = chat['lastMessageTime'] as Timestamp?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1B29),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8A2BE2).withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 8,
                          color: const Color(0xFF8A2BE2).withOpacity(0.1),
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Stack(
                        children: [
                          FutureBuilder<String?>(
                            future: _getUserProfileImage(otherUserId),
                            builder: (context, snapshot) {
                              final profileImageUrl = snapshot.data;

                              return Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8A2BE2).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF8A2BE2).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: ClipOval(
                                  child: profileImageUrl != null
                                      ? Image.network(
                                          profileImageUrl,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              width: 48,
                                              height: 48,
                                              color: const Color(0xFF8A2BE2).withOpacity(0.2),
                                              child: const Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: const Color(0xFF8A2BE2),
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return Center(
                                              child: Text(
                                                otherUserName.isNotEmpty
                                                    ? otherUserName[0].toUpperCase()
                                                    : 'K',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 18,
                                                  color: const Color(0xFF8A2BE2),
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : Center(
                                          child: Text(
                                            otherUserName.isNotEmpty
                                                ? otherUserName[0].toUpperCase()
                                                : 'K',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 18,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: StreamBuilder<bool>(
                              stream: _userStatusService.getUserOnlineStatus(otherUserId),
                              builder: (context, snapshot) {
                                final isOnline = snapshot.data ?? false;
                                return Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: isOnline ? const Color(0xFF8A2BE2) : const Color(0xFFFFFFFF).withOpacity(0.5),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      title: FutureBuilder<String>(
                        future: _getUserName(otherUserId),
                        builder: (context, snapshot) {
                          final displayName = snapshot.data ?? otherUserName;
                          return Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Color(0xFFFFFFFF),
                            ),
                          );
                        },
                      ),
                      subtitle: Text(
                        lastMessage.isNotEmpty ? lastMessage : 'Henüz mesaj yok',
                        style: TextStyle(
                          color: const Color(0xFFFFFFFF).withOpacity(0.7),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: StreamBuilder<int>(
                        stream: UnreadMessageService.getUnreadCountStream(chatId, currentUserId),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (unreadCount > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF3B30).withOpacity(0.5),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (lastMessageTime != null)
                                Text(
                                  _getTimeAgo(lastMessageTime.toDate()),
                                  style: TextStyle(
                                    color: const Color(0xFFFFFFFF).withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                )
                              else
                                Text(
                                  'Yeni',
                                  style: TextStyle(
                                    color: const Color(0xFF8A2BE2),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      onTap: () {
                        if (otherUserId.isNotEmpty) {
                          if (widget.onChatOpened != null) {
                            print('DEBUG: MessagePage: Chat $chatId için callback çağrılıyor');
                            widget.onChatOpened!(chatId);
                          } else {
                            print('DEBUG: MessagePage: onChatOpened callback null!');
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                otherUserId: otherUserId,
                                otherUserName: otherUserName,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}g';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}s';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}d';
    } else {
      return 'şimdi';
    }
  }
}
