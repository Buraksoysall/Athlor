import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'profile_page.dart';
import 'content_moderation_service.dart';
import 'report_service.dart';
import 'block_service.dart';

class CommentsPage extends StatefulWidget {
  final String activityId;
  final String activityTitle;
  final String activityImageUrl;
  final String activityUserName;
  final String activityUserImageUrl;
  
  const CommentsPage({
    super.key,
    required this.activityId,
    required this.activityTitle,
    required this.activityImageUrl,
    required this.activityUserName,
    required this.activityUserImageUrl,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  // Yorumları yükle
  Future<void> _loadComments() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('comments')
          .where('activityId', isEqualTo: widget.activityId)
          .orderBy('createdAt', descending: false)
          .get();

      // Engellenen kullanıcıları filtrele
      List<Map<String, dynamic>> filteredComments = [];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final commentUserId = data['userId'] as String?;
        
        if (commentUserId == null || commentUserId == currentUser.uid) {
          // Kendi yorumları her zaman göster
          filteredComments.add({
            'id': doc.id,
            'text': data['text'],
            'userId': data['userId'],
            'userName': data['userName'],
            'createdAt': data['createdAt'],
          });
        } else {
          // Diğer kullanıcıların yorumları için engel kontrolü yap
          final isBlocked = await BlockService.isBlocked(currentUser.uid, commentUserId);
          if (!isBlocked) {
            filteredComments.add({
              'id': doc.id,
              'text': data['text'],
              'userId': data['userId'],
              'userName': data['userName'],
              'createdAt': data['createdAt'],
            });
          }
        }
      }

      setState(() {
        _comments = filteredComments;
        _isLoading = false;
      });

      // En alta kaydır
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Yorum yükleme hatası: $e');
    }
  }

  // Yorum ekle
  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _commentController.text.trim().isEmpty) return;

    setState(() {
      _isPosting = true;
    });

    try {
      // Content filtering
      final text = _commentController.text.trim();
      if (ContentModerationService.isObjectionable(text)) {
        await ContentModerationService.logBlockedSubmission(
          userId: user.uid,
          contentType: 'comment',
          content: text,
        );
        final kw = ContentModerationService.findFirstMatch(text);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uygunsuz içerik tespit edildi${kw != null ? ' ("$kw")' : ''}. Gönderilemedi.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final userName = user.displayName ?? user.email?.split('@')[0] ?? 'Kullanıcı';
      
      await FirebaseFirestore.instance.collection('comments').add({
        'activityId': widget.activityId,
        'userId': user.uid,
        'userName': userName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      await _loadComments();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yorum eklendi!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Yorum ekleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yorum eklenemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  // Zaman hesaplama
  String _getTimeAgo(DateTime dateTime, DateTime now) {
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1C1B29), // Deep purple
                Color(0xFF0E1E3A), // Navy blue
              ],
            ),
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Yorumlar',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
          // Aktivite başlığı ve resmi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B29).withOpacity(0.9),
              border: Border(
                bottom: BorderSide(color: const Color(0xFF007AFF).withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                // Aktivite resmi
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.activityImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: const Color(0xFF0E1E3A),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF007AFF),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF0E1E3A),
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Aktivite bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.activityTitle,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_comments.length} yorum',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFFFFF).withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Yorumlar listesi
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                    ),
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: const Color(0xFF007AFF).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                size: 40,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz yorum yok',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'İlk yorumu sen yap!',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFFFFFFFF).withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
          ),
          
          // Yorum ekleme alanı
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16, // Extra padding for navigation bar
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B29).withOpacity(0.9),
              border: Border(
                top: BorderSide(color: const Color(0xFF007AFF).withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                // Kullanıcı avatarı
                FutureBuilder<String?>(
                  future: FirebaseAuth.instance.currentUser != null 
                    ? _getUserProfileImage(FirebaseAuth.instance.currentUser!.uid)
                    : Future.value(null),
                  builder: (context, snapshot) {
                    final profileImageUrl = snapshot.data;
                    
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF007AFF).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: profileImageUrl != null && profileImageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: profileImageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF007AFF), Color(0xFF4DD0E1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF007AFF), Color(0xFF4DD0E1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    (FirebaseAuth.instance.currentUser?.displayName ?? 
                                     FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 
                                     'K')[0].toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF007AFF), Color(0xFF4DD0E1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  (FirebaseAuth.instance.currentUser?.displayName ?? 
                                   FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 
                                   'K')[0].toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                // Yorum input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1E3A).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF007AFF).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _commentController,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Yorum yazın...',
                        hintStyle: GoogleFonts.poppins(
                          color: const Color(0xFFFFFFFF).withOpacity(0.6),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Gönder butonu
                GestureDetector(
                  onTap: _isPosting ? null : _addComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: _isPosting 
                          ? const LinearGradient(
                              colors: [Color(0xFF1C1B29), Color(0xFF0E1E3A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF007AFF), Color(0xFF4DD0E1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _isPosting ? null : [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isPosting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFFFFF)),
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
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

  // Tek yorum öğesi
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final createdAt = comment['createdAt'] as Timestamp?;
    final timeAgo = createdAt != null 
        ? _getTimeAgo(createdAt.toDate(), DateTime.now())
        : 'Az önce';
    final userId = comment['userId'] as String?;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B29).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kullanıcı avatarı - tıklanabilir
          GestureDetector(
            onTap: userId != null ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(targetUserId: userId),
                ),
              );
            } : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF007AFF).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: userId != null 
                  ? FutureBuilder<String?>(
                      future: _getUserProfileImage(userId),
                      builder: (context, snapshot) {
                        final profileImageUrl = snapshot.data;
                        
                        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
                          return CachedNetworkImage(
                            imageUrl: profileImageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF0E1E3A),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF007AFF),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF007AFF), Color(0xFF4DD0E1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  (comment['userName'] as String? ?? 'K')[0].toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        } else {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF007AFF), Color(0xFF4DD0E1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                (comment['userName'] as String? ?? 'K')[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF4DD0E1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (comment['userName'] as String? ?? 'K')[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Yorum içeriği
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kullanıcı adı ve zaman - kullanıcı adına da tıklanabilir
                Row(
                  children: [
                    GestureDetector(
                      onTap: userId != null ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfilePage(targetUserId: userId),
                          ),
                        );
                      } : null,
                      child: Text(
                        comment['userName'] ?? 'Kullanıcı',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                          decoration: userId != null ? TextDecoration.underline : null,
                          decorationColor: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1E3A).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        timeAgo,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFFFFFFFF).withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'report') {
                          final reason = await _promptReason();
                          final current = FirebaseAuth.instance.currentUser;
                          if (reason != null && current != null) {
                            await ReportService.reportContent(
                              reporterId: current.uid,
                              contentId: comment['id'] ?? '',
                              contentType: 'comment',
                              reason: reason,
                              metadata: {
                                'activityId': widget.activityId,
                                'commentUserId': userId ?? '',
                              },
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Rapor gönderildi'), backgroundColor: Colors.orange),
                              );
                            }
                          }
                        } else if (value == 'block' && userId != null) {
                          await BlockService.blockUser(userId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kullanıcı engellendi'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'report', child: Text('İçeriği Rapor Et')),
                        if (userId != null) const PopupMenuItem(value: 'block', child: Text('Kullanıcıyı Engelle')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Yorum metni
                Text(
                  comment['text'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFFFFFFFF).withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rapor Sebebi'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Kısa açıklama'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Gönder')),
        ],
      ),
    );
  }
}
