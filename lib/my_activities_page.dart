import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'comments_page.dart';

class MyActivitiesPage extends StatefulWidget {
  const MyActivitiesPage({super.key});

  @override
  State<MyActivitiesPage> createState() => _MyActivitiesPageState();
}

class _MyActivitiesPageState extends State<MyActivitiesPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Cache için
  List<QueryDocumentSnapshot>? _cachedActivities;
  bool _isLoading = true;
  
  // Yorum ve beğeni için
  Map<String, int> _likeCounts = {};
  Map<String, bool> _userLikes = {};
  Map<String, List<Map<String, dynamic>>> _comments = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadMyActivities();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Kullanıcının katıldığı aktiviteleri yükle
  Future<void> _loadMyActivities() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Önce kullanıcının myJoinedActivities array'ini al
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final myJoinedActivities = userData['myJoinedActivities'] as List<dynamic>? ?? [];
      
      if (myJoinedActivities.isEmpty) {
        setState(() {
          _cachedActivities = [];
          _isLoading = false;
        });
        return;
      }
      
      // myJoinedActivities array'indeki ID'lere göre aktiviteleri çek
      final snapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where(FieldPath.documentId, whereIn: myJoinedActivities.cast<String>())
          .orderBy('createdAt', descending: true)
          .get();
      
      setState(() {
        _cachedActivities = snapshot.docs;
        _isLoading = false;
      });
      
      // Her aktivite için beğeni ve yorum verilerini yükle
      await _loadLikesAndComments();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Aktivite yükleme hatası: $e');
    }
  }

  // Beğeni ve yorum verilerini yükle
  Future<void> _loadLikesAndComments() async {
    if (_cachedActivities == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    for (final doc in _cachedActivities!) {
      final activityId = doc.id;
      
      try {
        // Beğeni sayısını al
        final likesSnapshot = await FirebaseFirestore.instance
            .collection('likes')
            .where('activityId', isEqualTo: activityId)
            .get();
        
        _likeCounts[activityId] = likesSnapshot.docs.length;
        
        // Kullanıcının beğenip beğenmediğini kontrol et
        final userLikeSnapshot = await FirebaseFirestore.instance
            .collection('likes')
            .where('activityId', isEqualTo: activityId)
            .where('userId', isEqualTo: user.uid)
            .get();
        
        _userLikes[activityId] = userLikeSnapshot.docs.isNotEmpty;
        
        // Yorumları al
        final commentsSnapshot = await FirebaseFirestore.instance
            .collection('comments')
            .where('activityId', isEqualTo: activityId)
            .orderBy('createdAt', descending: false)
            .limit(10)
            .get();
        
        _comments[activityId] = commentsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'text': data['text'],
            'userId': data['userId'],
            'userName': data['userName'],
            'createdAt': data['createdAt'],
          };
        }).toList();
        
      } catch (e) {
        print('Beğeni/yorum yükleme hatası ($activityId): $e');
      }
    }
    
    if (mounted) setState(() {});
  }

  String _getTimeAgo(DateTime dateTime, DateTime now) {
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else {
      return 'Az önce';
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Tenis':
        return const Color(0xFF22C55E);
      case 'Futbol':
        return const Color(0xFF007AFF);
      case 'Basketbol':
        return const Color(0xFFFF6B35);
      case 'Voleybol':
        return const Color(0xFF8A2BE2);
      case 'Boks':
        return const Color(0xFFFF3B30);
      case 'Fitness':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF8A2BE2);
    }
  }

  String _getCategoryEmoji(String? category) {
    switch (category) {
      case 'Tenis':
        return '🎾';
      case 'Futbol':
        return '⚽';
      case 'Basketbol':
        return '🏀';
      case 'Voleybol':
        return '🏐';
      case 'Boks':
        return '🥊';
      case 'Fitness':
        return '💪';
      default:
        return '🏃';
    }
  }

  // Beğeni işlemi
  Future<void> _toggleLike(String activityId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final isLiked = _userLikes[activityId] ?? false;
      
      if (isLiked) {
        // Beğeniyi kaldır
        final likeQuery = await FirebaseFirestore.instance
            .collection('likes')
            .where('activityId', isEqualTo: activityId)
            .where('userId', isEqualTo: user.uid)
            .get();
        
        for (final doc in likeQuery.docs) {
          await doc.reference.delete();
        }
        
        setState(() {
          _userLikes[activityId] = false;
          _likeCounts[activityId] = (_likeCounts[activityId] ?? 1) - 1;
        });
      } else {
        // Beğeni ekle
        await FirebaseFirestore.instance.collection('likes').add({
          'activityId': activityId,
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        setState(() {
          _userLikes[activityId] = true;
          _likeCounts[activityId] = (_likeCounts[activityId] ?? 0) + 1;
        });
      }
    } catch (e) {
      print('Beğeni hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beğeni işlemi başarısız: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  // Yorum sayfasını aç
  void _openCommentsPage(Map<String, dynamic> activity, String activityId) {
    final mediaUrls = activity['media'] as List<dynamic>? ?? [];
    final imageUrl = mediaUrls.isNotEmpty ? mediaUrls[0] : '';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsPage(
          activityId: activityId,
          activityTitle: activity['title'] ?? 'Aktivite',
          activityImageUrl: imageUrl,
          activityUserName: activity['createdByName'] ?? 'Kullanıcı',
          activityUserImageUrl: '', // Profil resmi URL'si eklenebilir
        ),
      ),
    ).then((_) {
      // Yorum sayfasından döndüğünde yorumları yeniden yükle
      _loadLikesAndComments();
    });
  }

  // Aktiviteden çık
  Future<void> _leaveActivity(String activityId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Onay dialogu göster
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1C1B29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF8A2BE2), width: 1),
          ),
          title: const Text(
            'Aktiviteden Çık',
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Bu aktiviteden çıkmak istediğinizden emin misiniz?',
            style: TextStyle(color: Color(0xFFFFFFFF)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'İptal',
                style: TextStyle(color: Color(0xFF8A2BE2)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Çık'),
            ),
          ],
        ),
      );

      if (shouldLeave != true) return;

      // Kullanıcının myJoinedActivities array'inden aktiviteyi çıkar
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'myJoinedActivities': FieldValue.arrayRemove([activityId]),
      });

      // Aktivitenin participants array'inden kullanıcıyı çıkar
      await FirebaseFirestore.instance
          .collection('activities')
          .doc(activityId)
          .update({
        'participants': FieldValue.arrayRemove([user.uid]),
      });

      // Başarı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aktiviteden başarıyla çıktınız'),
          backgroundColor: const Color(0xFF22C55E),
          duration: const Duration(seconds: 2),
        ),
      );

      // Aktivite listesini yeniden yükle
      await _loadMyActivities();
    } catch (e) {
      print('Aktiviteden çıkma hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  // Küçük aktivite kartı - Mesaj benzeri
  Widget _buildSmallActivityCard(Map<String, dynamic> activity, DateTime dateTime, String timeAgo) {
    final activityId = activity['id'] ?? '';
    final mediaUrls = activity['media'] as List<dynamic>? ?? [];
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF8A2BE2).withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A2BE2).withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              InkWell(
                onTap: () => _showActivityDetails(activity, activityId),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                  // Kategori ikonu
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(activity['category']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _getCategoryEmoji(activity['category']),
                        style: const TextStyle(fontSize: 24),
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
                          activity['title'] ?? 'Aktivite',
                          style: const TextStyle(
                            fontFamily: 'InterTight',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFFFFFFFF),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: const Color(0xFFFFFFFF).withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(activity['category']).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getCategoryColor(activity['category']).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                activity['category'],
                                style: TextStyle(
                                  color: _getCategoryColor(activity['category']),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Beğeni butonu
                            GestureDetector(
                              onTap: () => _toggleLike(activityId),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0E1E3A).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF8A2BE2).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _userLikes[activityId] == true 
                                          ? Icons.favorite 
                                          : Icons.favorite_border,
                                      size: 16,
                                      color: _userLikes[activityId] == true 
                                          ? const Color(0xFFFF3B30)
                                          : const Color(0xFFFFFFFF).withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_likeCounts[activityId] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFFFFFFF).withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Yorum butonu
                            GestureDetector(
                              onTap: () => _openCommentsPage(activity, activityId),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0E1E3A).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF8A2BE2).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 16,
                                      color: const Color(0xFFFFFFFF).withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_comments[activityId]?.length ?? 0}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFFFFFFF).withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Medya önizlemesi (varsa)
                  if (mediaUrls.isNotEmpty)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(mediaUrls[0]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
              // Çarpı (X) butonu - sağ üst köşe
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _leaveActivity(activityId),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Aktivite detaylarını göster
  void _showActivityDetails(Map<String, dynamic> activity, String activityId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1B29),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                color: Color(0xFF8A2BE2),
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8A2BE2).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // İçerik
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık
                      Text(
                        activity['title'] ?? 'Aktivite',
                        style: const TextStyle(
                          fontFamily: 'InterTight',
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Kategori ve tarih
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(activity['category']).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getCategoryColor(activity['category']).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              activity['category'],
                              style: TextStyle(
                                color: _getCategoryColor(activity['category']),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(activity['dateTime'] as Timestamp).toDate().day}/${(activity['dateTime'] as Timestamp).toDate().month}/${(activity['dateTime'] as Timestamp).toDate().year}',
                            style: TextStyle(
                              color: const Color(0xFFFFFFFF).withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Açıklama
                      if (activity['description'] != null && activity['description'].isNotEmpty)
                        Text(
                          activity['description'],
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: const Color(0xFFFFFFFF).withOpacity(0.8),
                            height: 1.5,
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Medya
                      if (activity['media'] != null && (activity['media'] as List).isNotEmpty)
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage((activity['media'] as List)[0]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Katılımcı sayısı
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1E3A).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF8A2BE2).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.people,
                              color: const Color(0xFF8A2BE2),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Katılımcılar: ${(activity['participants'] as List?)?.length ?? 0}/${activity['maxParticipants'] ?? 20}',
                              style: TextStyle(
                                color: const Color(0xFFFFFFFF).withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Etkileşim butonları
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _toggleLike(activityId),
                              icon: Icon(
                                _userLikes[activityId] == true 
                                    ? Icons.favorite 
                                    : Icons.favorite_border,
                                size: 20,
                              ),
                              label: Text('${_likeCounts[activityId] ?? 0} Beğeni'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _userLikes[activityId] == true 
                                    ? const Color(0xFFFF3B30)
                                    : const Color(0xFF0E1E3A).withOpacity(0.8),
                                foregroundColor: _userLikes[activityId] == true 
                                    ? Colors.white 
                                    : const Color(0xFFFFFFFF).withOpacity(0.9),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openCommentsPage(activity, activityId),
                              icon: const Icon(Icons.chat_bubble_outline, size: 20),
                              label: Text('${_comments[activityId]?.length ?? 0} Yorum'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0E1E3A).withOpacity(0.8),
                                foregroundColor: const Color(0xFFFFFFFF).withOpacity(0.9),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Aktivitelerim',
          style: TextStyle(
            fontFamily: 'InterTight',
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: Color(0xFFFFFFFF),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8A2BE2)),
              ),
            )
          : _cachedActivities == null || _cachedActivities!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A2BE2).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(60),
                          border: Border.all(
                            color: const Color(0xFF8A2BE2).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.sports_soccer,
                          size: 64,
                          color: Color(0xFF8A2BE2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Henüz aktiviteye katılmadınız',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aktiviteleri keşfetmeye başlayın!',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFFFFFFFF).withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMyActivities,
                  color: const Color(0xFF8A2BE2),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    itemCount: _cachedActivities!.length,
                    itemBuilder: (context, index) {
                      final doc = _cachedActivities![index];
                      final activity = doc.data() as Map<String, dynamic>;
                      activity['id'] = doc.id;
                      final createdAt = (activity['createdAt'] as Timestamp).toDate();
                      final now = DateTime.now();
                      final timeAgo = _getTimeAgo(createdAt, now);
                      
                      return _buildSmallActivityCard(activity, createdAt, timeAgo);
                    },
                  ),
                ),
    );
  }
}
