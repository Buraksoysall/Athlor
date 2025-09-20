import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_page.dart';
import 'user_status_service.dart';
import 'unread_message_service.dart';

class ChatPage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final UserStatusService _userStatusService = UserStatusService();
  String? _chatId;
  String _otherUserName = '';

  @override
  void initState() {
    super.initState();
    _createOrGetChatId();
    _markChatAsRead();
    _loadOtherUserName();
  }

  // Chat'teki tüm mesajları okundu olarak işaretle
  Future<void> _markChatAsRead() async {
    if (_chatId == null) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await UnreadMessageService.markChatAsRead(_chatId!, currentUser.uid);
  }

  // Yeni gelen mesajları okundu olarak işaretle
  Future<void> _markNewMessagesAsRead(List<QueryDocumentSnapshot> messages) async {
    if (_chatId == null) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await UnreadMessageService.markNewMessagesAsRead(messages, currentUser.uid);
  }

  // Diğer kullanıcının adını yükle
  Future<void> _loadOtherUserName() async {
    try {
      String userName = await _getUserNameFromFirestore(widget.otherUserId);
      if (mounted) {
        setState(() {
          _otherUserName = userName;
        });
      }
    } catch (e) {
      print('Diğer kullanıcı adı yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _otherUserName = widget.otherUserName; // Fallback olarak widget'tan gelen adı kullan
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Kullanıcı adını Firestore'dan al
  Future<String> _getUserNameFromFirestore(String userId) async {
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

  // Sohbet ID'sini oluştur veya mevcut olanı al
  Future<void> _createOrGetChatId() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('DEBUG: Kullanıcı giriş yapmamış');
      return;
    }

    if (widget.otherUserId.isEmpty) {
      print('DEBUG: Diğer kullanıcı ID\'si boş');
      return;
    }

    // Sohbet ID'sini oluştur (küçük ID önce gelir)
    final userIds = [currentUser.uid, widget.otherUserId];
    userIds.sort();
    final chatId = '${userIds[0]}_${userIds[1]}';
    
    print('DEBUG: Chat ID oluşturuldu: $chatId');
    print('DEBUG: Current User: ${currentUser.uid}');
    print('DEBUG: Other User: ${widget.otherUserId}');

    setState(() {
      _chatId = chatId;
    });

    try {
      // Sohbet dokümanının var olup olmadığını kontrol et
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        print('DEBUG: Yeni sohbet oluşturuluyor...');
        // Yeni sohbet oluştur
        // Kullanıcı adlarını Firestore'dan al
        String currentUserName = await _getUserNameFromFirestore(currentUser.uid);
        String otherUserName = widget.otherUserName.isNotEmpty 
            ? widget.otherUserName 
            : await _getUserNameFromFirestore(widget.otherUserId);
        
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .set({
          'participants': [currentUser.uid, widget.otherUserId],
          'participantNames': [currentUserName, otherUserName],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('DEBUG: Sohbet başarıyla oluşturuldu');
      } else {
        print('DEBUG: Sohbet zaten mevcut');
      }
    } catch (e) {
      print('DEBUG: Sohbet oluşturma hatası: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Kullanıcı adını Firestore'dan al
      String senderName = await _getUserNameFromFirestore(user.uid);
      
      // Mesajı gönder (readBy alanı ile)
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add(UnreadMessageService.createMessageData(
            text: _messageController.text.trim(),
            senderId: user.uid,
            senderName: senderName,
          ));

      // Sohbet dokümanını güncelle
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .update({
        'lastMessage': _messageController.text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
      
      // Scroll to top to show new message (reverse: true kullanıldığı için)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj gönderilemedi: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      resizeToAvoidBottomInset: true,
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
              border: Border.all(
                color: const Color(0xFF8A2BE2).withOpacity(0.3),
                width: 1,
              ),
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
        actions: [],
        centerTitle: false,
        elevation: 0,
        title: GestureDetector(
          onTap: () {
            // Konuştuğum kişinin profil sayfasına git
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(
                  targetUserId: widget.otherUserId,
                ),
              ),
            );
          },
          child: Row(
            children: [
              FutureBuilder<String?>(
                future: _getUserProfileImage(widget.otherUserId),
                builder: (context, snapshot) {
                  final profileImageUrl = snapshot.data;
                  
                  return Container(
                    width: 36,
                    height: 36,
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
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 36,
                                  height: 36,
                                  color: const Color(0xFF8A2BE2).withOpacity(0.2),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF8A2BE2),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    (_otherUserName.isNotEmpty ? _otherUserName : widget.otherUserName).isNotEmpty 
                                        ? (_otherUserName.isNotEmpty ? _otherUserName : widget.otherUserName)[0].toUpperCase()
                                        : 'K',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8A2BE2),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                (_otherUserName.isNotEmpty ? _otherUserName : widget.otherUserName).isNotEmpty 
                                    ? (_otherUserName.isNotEmpty ? _otherUserName : widget.otherUserName)[0].toUpperCase()
                                    : 'K',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8A2BE2),
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _otherUserName.isNotEmpty ? _otherUserName : widget.otherUserName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: const Color(0xFFFFFFFF),
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: _userStatusService.getUserOnlineStatus(widget.otherUserId),
                      builder: (context, snapshot) {
                        final isOnline = snapshot.data ?? false;
                        return Text(
                          isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOnline ? const Color(0xFF8A2BE2) : const Color(0xFFFFFFFF).withOpacity(0.7),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: _chatId == null
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8A2BE2)),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(_chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      // Yeni mesajlar geldiğinde otomatik olarak okundu işaretle
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _markNewMessagesAsRead(snapshot.data!.docs);
                        });
                      }
                      
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
                              const SizedBox(height: 16),
                              Text(
                                'Chat ID: $_chatId',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFFFFFFFF).withOpacity(0.7),
                                ),
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
                                'Henüz mesaj yok',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFFFFF),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'İlk mesajı sen gönder!',
                                style: TextStyle(
                                  color: const Color(0xFFFFFFFF).withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        reverse: true,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final reversedIndex = snapshot.data!.docs.length - 1 - index;
                          final message = snapshot.data!.docs[reversedIndex].data() as Map<String, dynamic>;
                          final isCurrentUser = message['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: isCurrentUser 
                                  ? MainAxisAlignment.end 
                                  : MainAxisAlignment.start,
                              children: [
                                if (!isCurrentUser) ...[
                                  FutureBuilder<String?>(
                                    future: _getUserProfileImage(message['senderId']),
                                    builder: (context, snapshot) {
                                      final profileImageUrl = snapshot.data;
                                      
                                      return Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8A2BE2).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: ClipOval(
                                          child: profileImageUrl != null
                                              ? Image.network(
                                                  profileImageUrl,
                                                  width: 32,
                                                  height: 32,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return Container(
                                                      width: 32,
                                                      height: 32,
                                                      color: const Color(0xFF8A2BE2).withOpacity(0.2),
                                                      child: const Center(
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 1,
                                                          color: const Color(0xFF8A2BE2),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Center(
                                                      child: Text(
                                                        (message['senderName'] as String).isNotEmpty 
                                                            ? (message['senderName'] as String)[0].toUpperCase()
                                                            : 'K',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFF8A2BE2),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Center(
                                                  child: Text(
                                                    (message['senderName'] as String).isNotEmpty 
                                                        ? (message['senderName'] as String)[0].toUpperCase()
                                                        : 'K',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF8A2BE2),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser 
                                          ? const Color(0xFF8A2BE2)
                                          : const Color(0xFF1C1B29),
                                      borderRadius: BorderRadius.circular(20),
                                      border: isCurrentUser 
                                          ? null
                                          : Border.all(
                                              color: const Color(0xFF8A2BE2).withOpacity(0.2),
                                              width: 1,
                                            ),
                                    ),
                                    child: Text(
                                      message['text'] ?? '',
                                      style: TextStyle(
                                        color: isCurrentUser 
                                            ? Colors.white 
                                            : const Color(0xFFFFFFFF),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  FutureBuilder<String?>(
                                    future: _getUserProfileImage(message['senderId']),
                                    builder: (context, snapshot) {
                                      final profileImageUrl = snapshot.data;
                                      
                                      return Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8A2BE2).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: ClipOval(
                                          child: profileImageUrl != null
                                              ? Image.network(
                                                  profileImageUrl,
                                                  width: 32,
                                                  height: 32,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return Container(
                                                      width: 32,
                                                      height: 32,
                                                      color: const Color(0xFF8A2BE2).withOpacity(0.2),
                                                      child: const Center(
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 1,
                                                          color: const Color(0xFF8A2BE2),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Center(
                                                      child: Text(
                                                        (message['senderName'] as String).isNotEmpty 
                                                            ? (message['senderName'] as String)[0].toUpperCase()
                                                            : 'K',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFF8A2BE2),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Center(
                                                  child: Text(
                                                    (message['senderName'] as String).isNotEmpty 
                                                        ? (message['senderName'] as String)[0].toUpperCase()
                                                        : 'K',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF8A2BE2),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1B29),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 8,
                        color: const Color(0xFF8A2BE2).withOpacity(0.2),
                        offset: const Offset(0, -2),
                      ),
                    ],
                    border: const Border(
                      top: BorderSide(
                        color: Color(0xFF8A2BE2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E1E3A).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF8A2BE2).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Mesajınızı yazın...',
                              hintStyle: TextStyle(
                                color: const Color(0xFFFFFFFF).withOpacity(0.5),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A2BE2),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8A2BE2).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
