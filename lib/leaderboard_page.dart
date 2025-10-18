import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'profile_page.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> topUsers = [];
  bool isLoading = true;
  StreamSubscription? _likesListener;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchTopUsers();
    _startLikesListener();
  }

  @override
  void dispose() {
    _likesListener?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Likes koleksiyonunu dinle ve değişiklik olduğunda leaderboard'ı güncelle
  void _startLikesListener() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthStartTimestamp = Timestamp.fromDate(monthStart);
    
    _likesListener = FirebaseFirestore.instance
        .collection('likes')
        .where('createdAt', isGreaterThanOrEqualTo: monthStartTimestamp)
        .snapshots()
        .listen((snapshot) {
      // Debounce ile çok sık güncellemeyi önle
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        print('🔄 Like değişikliği tespit edildi, leaderboard güncelleniyor...');
        _fetchTopUsers();
      });
    });
  }



  Future<void> _fetchTopUsers() async {
    try {
      // Aylık sıfırlama gerekli mi kontrol et
      if (await _shouldResetMonthlyLikes()) {
        print('🔄 Sezon sıfırlaması yapılıyor - Yeni yarış başlıyor!');
        await _resetMonthlyLikes();
        print('✅ Sezon sıfırlaması tamamlandı - Leaderboard güncel!');
      } else {
        print('✅ Sezon kontrolü tamamlandı - Sıfırlama gerekmiyor');
      }
      
      // Önce mevcut likes alanlarını güncelle
      await _updateAllUserLikes();
      
      // Kullanıcı verileri güncellendikten sonra tekrar çek
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Users koleksiyonundaki güncel likes verilerini kullan (SADECE BU AYIN)
      final now = DateTime.now();
      print('DEBUG: ${_getMonthName(now.month)} ${now.year} ayının likes verileri kullanılıyor...');
      
      // Tüm kullanıcıları çek ve aylık likes alanına göre sırala
      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      Map<String, Map<String, dynamic>> userLikeData = {};
      
      for (var userDoc in usersSnapshot.docs) {
        String userId = userDoc.id;
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        // Debug: Tüm kullanıcıları logla
        print('DEBUG: Kullanıcı $userId - Tüm veriler: $userData');
        
        // Real-time güncellenmiş likes verilerini kullan (ÇOK HIZLI)
        int currentLikes = userData['likes'] ?? 0;
        int lastMonthLikes = userData['lastMonthLikes'] ?? 0;
        
         // Tüm kullanıcıları ekle (0 beğenili olsa bile)
         // Beğeni sayısını XP'ye çevir (1 beğeni = 3 XP)
         int currentXP = currentLikes * 3;
         int lastMonthXP = lastMonthLikes * 3;
         
         // Artış/azalış yüzdesini hesapla
         double changePercent = 0.0;
         if (lastMonthXP > 0) {
           changePercent = ((currentXP - lastMonthXP) / lastMonthXP) * 100;
         } else if (currentXP > 0) {
           changePercent = 100.0; // Geçen ay 0, bu ay var
         }
         
         userLikeData[userId] = {
           'likes': currentLikes,
           'xp': currentXP,
           'lastMonthLikes': lastMonthLikes,
           'lastMonthXP': lastMonthXP,
           'changePercent': changePercent,
         };
         
         print('🏆 Kullanıcı $userId: $currentLikes beğeni ($currentXP XP) (Geçen ay: $lastMonthLikes beğeni, $lastMonthXP XP, Değişim: ${changePercent.toStringAsFixed(1)}%)');
      }

      // Tüm kullanıcıları XP'ye göre sırala
      var sortedUsers = userLikeData.entries.toList()
        ..sort((a, b) => b.value['xp'].compareTo(a.value['xp']));

      List<Map<String, dynamic>> usersWithData = [];

      // Sadece ilk 10 kullanıcıyı al
      int maxUsers = sortedUsers.length > 10 ? 10 : sortedUsers.length;
      for (int i = 0; i < maxUsers; i++) {
        String userId = sortedUsers[i].key;
        Map<String, dynamic> likeData = sortedUsers[i].value;
        int likeCount = likeData['likes'];
        int xpCount = likeData['xp'];
        int lastMonthLikes = likeData['lastMonthLikes'];
        int lastMonthXP = likeData['lastMonthXP'];
        double changePercent = likeData['changePercent'];
        
        print('Kullanıcı $userId: $likeCount beğeni ($xpCount XP) (Geçen ay: $lastMonthLikes beğeni, $lastMonthXP XP, Değişim: ${changePercent.toStringAsFixed(1)}%) - Sıra: ${i + 1}');

        // Kullanıcı bilgilerini çek
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          usersWithData.add({
            'userId': userId,
            'name': userData['displayName'] ?? userData['name'] ?? 'Bilinmeyen Kullanıcı',
            'username': userData['username'] ?? '',
            'profilePhoto': userData['profileImageUrl'] ?? userData['profilePhoto'] ?? '',
            'likeCount': likeCount,
            'xpCount': xpCount,
            'lastMonthLikes': lastMonthLikes,
            'lastMonthXP': lastMonthXP,
            'changePercent': changePercent,
            'rank': i + 1,
          });
        }
      }

      // Real-time sistem kullanıldığı için manuel güncelleme gerekmiyor

      setState(() {
        topUsers = usersWithData;
        isLoading = false;
      });
    } catch (e) {
      print('Leaderboard veri çekme hatası: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Tüm kullanıcıların likes alanlarını güncelle (Sadece bu ayın like'ları)
  Future<void> _updateAllUserLikes() async {
    try {
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;
      
      // Bu ayın başlangıç tarihi
      final monthStart = DateTime(currentYear, currentMonth, 1);
      final monthStartTimestamp = Timestamp.fromDate(monthStart);
      
      // Like koleksiyonundan sadece bu ayın like'larını çek (createdAt alanı ile)
      QuerySnapshot likesSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('createdAt', isGreaterThanOrEqualTo: monthStartTimestamp)
          .get();
      
      print('Bu ayın like sayısı (createdAt ile): ${likesSnapshot.docs.length} (${_getMonthName(currentMonth)} ${currentYear})');
      
      // Activity ID'lerine göre like sayılarını say (sadece bu ayın like'ları)
      Map<String, int> activityLikeCounts = {};
      int thisMonthLikes = 0;
      
      for (var doc in likesSnapshot.docs) {
        Map<String, dynamic> likeData = doc.data() as Map<String, dynamic>;
        String activityId = likeData['activityId'];
        
        // createdAt kontrolü
        if (likeData.containsKey('createdAt')) {
          Timestamp likeTimestamp = likeData['createdAt'];
          DateTime likeDate = likeTimestamp.toDate();
          
          // Bu ayın like'ı mı kontrol et
          if (likeDate.year == currentYear && likeDate.month == currentMonth) {
            activityLikeCounts[activityId] = (activityLikeCounts[activityId] ?? 0) + 1;
            thisMonthLikes++;
          }
        } else {
          // createdAt yoksa bu like'ı bu aya ait sayma (güvenlik için)
          print('WARNING: Like ${doc.id} createdAt alanı yok, atlanıyor');
        }
      }
      
      print('🔢 Bu ayın toplam like sayısı: $thisMonthLikes (${_getMonthName(currentMonth)} ${currentYear})');
      print('📋 Aktivite like dağılımı:');
      activityLikeCounts.forEach((activityId, count) {
        if (count > 0) {
          print('   📌 Aktivite $activityId: $count like');
        }
      });
      
      // Tüm kullanıcıları çek
      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      for (var userDoc in usersSnapshot.docs) {
        String userId = userDoc.id;
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        // myJoinedActivities field'ı yoksa bu kullanıcıyı atla
        if (!userData.containsKey('myJoinedActivities')) {
          continue;
        }
        
        List<dynamic> myJoinedActivities = userData['myJoinedActivities'] ?? [];
        
        // Aktivitesi yoksa bu kullanıcıyı atla
        if (myJoinedActivities.isEmpty) {
          continue;
        }
        
        int totalLikes = 0;
        List<String> userActivityMatches = [];
        
        for (String activityId in myJoinedActivities) {
          int activityLikes = activityLikeCounts[activityId] ?? 0;
          totalLikes += activityLikes;
          if (activityLikes > 0) {
            userActivityMatches.add('$activityId:$activityLikes');
          }
        }
        
        if (totalLikes > 0) {
          print('👤 Kullanıcı $userId: ${userActivityMatches.join(", ")} = $totalLikes toplam like');
        }
        
        // Kullanıcının likes alanını güncelle
        await _updateUserLikes(userId, totalLikes);
      }
      
      // Eşleşmeyen like'ları kontrol et
      int assignedLikes = 0;
      activityLikeCounts.forEach((activityId, count) {
        assignedLikes += count;
      });
      
      print('📊 Özet: $thisMonthLikes toplam like, $assignedLikes kullanıcılara atandı');
      if (thisMonthLikes != assignedLikes) {
        print('⚠️  ${thisMonthLikes - assignedLikes} like eşleşmedi!');
      }
      
    } catch (e) {
      print('Tüm kullanıcıların likes güncelleme hatası: $e');
    }
  }

  // Kullanıcının likes alanını güncelle (Sadece bu ayın like'ları)
  Future<void> _updateUserLikes(String userId, int likesCount) async {
    try {
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;
      final monthKey = '${currentYear}_${currentMonth.toString().padLeft(2, '0')}';
      
      // Mevcut kullanıcı verilerini al
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final monthlyLikes = userData['monthlyLikes'] as Map<String, dynamic>? ?? {};
        
        // Bu ayın like sayısını güncelle
        monthlyLikes[monthKey] = likesCount;
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'likes': likesCount, // Sadece bu ayın like'ları
          'likesUpdatedAt': FieldValue.serverTimestamp(),
          'monthlyLikes': monthlyLikes,
          'currentMonthKey': monthKey,
        });
        
        // Kullanıcı likes güncellendi
      }
    } catch (e) {
      print('Kullanıcı $userId likes güncelleme hatası: $e');
    }
  }

  // Aylık like sayılarını sıfırla (her ayın 1inde çalışacak)
  Future<void> _resetMonthlyLikes() async {
    try {
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;
      final currentMonthKey = '${currentYear}_${currentMonth.toString().padLeft(2, '0')}';
      
      print('DEBUG: Sezon sıfırlaması başlıyor - $currentMonthKey');
      
      // Tüm kullanıcıları al
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      int processedUsers = 0;
      
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        final monthlyLikes = userData['monthlyLikes'] as Map<String, dynamic>? ?? {};
        final currentLikes = userData['likes'] ?? 0;
        
        // Geçen ayın like sayısını al
        final lastMonth = currentMonth == 1 ? 12 : currentMonth - 1;
        final lastMonthYear = currentMonth == 1 ? currentYear - 1 : currentYear;
        final lastMonthKey = '${lastMonthYear}_${lastMonth.toString().padLeft(2, '0')}';
        final lastMonthLikes = monthlyLikes[lastMonthKey] ?? 0;
        
        // Mevcut likes'ı lastMonthLikes'a aktar ve likes'ı sıfırla
        monthlyLikes[currentMonthKey] = 0;
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'likes': 0,
          'monthlyLikes': monthlyLikes,
          'lastMonthLikes': currentLikes, // Mevcut likes'ı geçen aya aktar
          'currentMonthKey': currentMonthKey,
          'monthlyResetAt': FieldValue.serverTimestamp(),
        });
        
        processedUsers++;
        print('Kullanıcı $userId sezon sıfırlandı (Mevcut: $currentLikes -> lastMonth: $currentLikes, Yeni likes: 0)');
      }
      
      // Sistem ayarlarını güncelle - sıfırlama tamamlandı
      await FirebaseFirestore.instance
          .collection('system')
          .doc('leaderboard')
          .update({
        'lastResetMonthKey': currentMonthKey,
        'lastResetAt': FieldValue.serverTimestamp(),
        'processedUsers': processedUsers,
      });
      
      print('DEBUG: Sezon sıfırlaması tamamlandı - $processedUsers kullanıcı işlendi');
    } catch (e) {
      print('Aylık likes sıfırlama hatası: $e');
    }
  }

  // Aylık sıfırlama gerekli mi kontrol et (Global sistem kontrolü)
  Future<bool> _shouldResetMonthlyLikes() async {
    try {
      final now = DateTime.now();
      final currentMonthKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';
      
      // Global sistem kontrolü - system/leaderboard koleksiyonunu kontrol et
      final systemDoc = await FirebaseFirestore.instance
          .collection('system')
          .doc('leaderboard')
          .get();
      
      if (systemDoc.exists) {
        final systemData = systemDoc.data() as Map<String, dynamic>;
        final lastResetMonthKey = systemData['lastResetMonthKey'] as String?;
        
        print('DEBUG: Sistem kontrol - Mevcut ay: $currentMonthKey, Son sıfırlama: $lastResetMonthKey');
        
        // Eğer sistem ayarlarındaki son sıfırlama ayı mevcut aydan farklıysa sıfırlama gerekli
        bool needsReset = lastResetMonthKey != currentMonthKey;
        
        if (needsReset) {
          print('DEBUG: Sezon sıfırlaması gerekli - Yeni sezon başlıyor: $currentMonthKey');
        }
        
        return needsReset;
      } else {
        // İlk kez çalışıyorsa sistem ayarlarını oluştur
        print('DEBUG: İlk sefer sistem ayarları oluşturuluyor');
        await FirebaseFirestore.instance
            .collection('system')
            .doc('leaderboard')
            .set({
          'lastResetMonthKey': currentMonthKey,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return false;
      }
    } catch (e) {
      print('Aylık sıfırlama kontrol hatası: $e');
      return false;
    }
  }

  // Ay adını döndüren yardımcı fonksiyon
  String _getMonthName(int month) {
    const months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return months[month];
  }

  // Sıralama ikonunu döndüren yardımcı fonksiyon
  Widget _getRankIcon(int rank, bool isFirst) {
    if (isFirst) {
      return const Icon(
        Icons.emoji_events,
        color: Color(0xFFFFFFFF),
        size: 20,
      ); // 1. sıra - Altın kupa
    } else if (rank == 2) {
      return const Icon(
        Icons.emoji_events,
        color: Color(0xFFFFFFFF),
        size: 18,
      ); // 2. sıra - Gümüş kupa
    } else if (rank == 3) {
      return const Icon(
        Icons.emoji_events,
        color: Color(0xFFFFFFFF),
        size: 16,
      ); // 3. sıra - Bronz kupa
    } else {
      return Text(
        rank.toString(),
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ); // Diğer sıralar için sayı
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1C1B29),
                        Color(0xFF0E1E3A),
                        Color(0xFF0A0A0A)
                      ],
                      stops: [0, 0.5, 1],
                      begin: AlignmentDirectional(1, 1),
                      end: AlignmentDirectional(-1, -1),
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                        Center(
                          child: Text(
                            '🏆 Leaderboard',
                            style: GoogleFonts.interTight(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFFFFFF),
                              fontSize: 24,
                              letterSpacing: 0.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bu ayın en iyi performans gösteren 10 kullanıcısı',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFFFFFF).withOpacity(0.9),
                            fontSize: 16,
                            letterSpacing: 0.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Sezon bilgisi bölümü kaldırıldı
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1B29),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        color: const Color(0xFF007AFF).withOpacity(0.2),
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        blurRadius: 10,
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(0, 4),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                        isLoading 
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // 2nd Place
                                Expanded(
                                  child: _buildPodiumUser(
                                    user: topUsers.length > 1 ? topUsers[1] : null,
                                    rank: 2,
                                    colors: [Color(0xFFFF3B30), Color(0xFFDC2626)],
                                  ),
                                ),
                                // 1st Place
                                Expanded(
                                  child: _buildPodiumUser(
                                    user: topUsers.isNotEmpty ? topUsers[0] : null,
                                    rank: 1,
                                    colors: [Color(0xFFFFD93D), Color(0xFFFFA500)],
                                    isFirst: true,
                                  ),
                                ),
                                // 3rd Place
                                Expanded(
                                  child: _buildPodiumUser(
                                    user: topUsers.length > 2 ? topUsers[2] : null,
                                    rank: 3,
                                    colors: [Color(0xFFFF6B35), Color(0xFFE55A2B)],
                                  ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          primary: false,
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          itemCount: topUsers.length > 3 ? (topUsers.length - 3).clamp(0, 7) : 0,
                          itemBuilder: (context, index) {
                            int actualIndex = index + 3; // 4. sıradan başla
                            if (actualIndex >= topUsers.length) return const SizedBox.shrink();
                            
                            var user = topUsers[actualIndex];
                            List<Color> rankColors = [
                              const Color(0xFF007AFF),
                              const Color(0xFFFF6B35),
                              const Color(0xFFFF3B30),
                              const Color(0xFFFFD93D),
                              const Color(0xFF8B5CF6),
                              const Color(0xFF10B981),
                              const Color(0xFF06B6D4),
                            ];
                            
                            return Column(
                              children: [
                                _buildDynamicLeaderboardItem(
                                  user: user,
                                  rankColor: rankColors[index % rankColors.length],
                                ),
                                if (index < topUsers.length - 4) const SizedBox(height: 12),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ]..insert(0, const SizedBox(height: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumUser({
    required Map<String, dynamic>? user,
    required int rank,
    required List<Color> colors,
    bool isFirst = false,
  }) {
    if (user == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: rank == 1 ? 85 : 75,
            height: rank == 1 ? 115 : (rank == 2 ? 95 : 85),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                stops: const [0, 1],
                begin: const AlignmentDirectional(1, -1),
                end: const AlignmentDirectional(-1, 1),
              ),
              borderRadius: BorderRadius.circular(rank == 1 ? 24 : 20),
            ),
            child: const Center(
              child: Text(
                '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Veri Yok',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(targetUserId: user['userId']),
              ),
            );
          },
          child: Container(
            width: rank == 1 ? 85 : 75,
            height: rank == 1 ? 115 : (rank == 2 ? 95 : 85),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                stops: const [0, 1],
                begin: const AlignmentDirectional(1, -1),
                end: const AlignmentDirectional(-1, 1),
              ),
              borderRadius: BorderRadius.circular(rank == 1 ? 24 : 20),
              boxShadow: rank == 1 ? [
                BoxShadow(
                  color: colors[0].withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 8),
                ),
              ] : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: rank == 1 ? 50 : 40,
                    height: rank == 1 ? 50 : 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(rank == 1 ? 23 : 18),
                        child: user['profilePhoto'] != null && user['profilePhoto'].isNotEmpty
                            ? CachedNetworkImage(
                                fadeInDuration: const Duration(milliseconds: 0),
                                fadeOutDuration: const Duration(milliseconds: 0),
                                imageUrl: user['profilePhoto'],
                                width: rank == 1 ? 46 : 36,
                                height: rank == 1 ? 46 : 36,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, color: Colors.grey),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, color: Colors.grey),
                                ),
                              )
                            : Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.person, color: Colors.grey),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _getRankIcon(rank, isFirst),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(targetUserId: user['userId']),
              ),
            );
          },
          child: Text(
            user['name'] ?? 'Bilinmeyen',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.0,
              color: const Color(0xFFFFFFFF),
            ),
          ),
        ),
        const SizedBox(height: 4),
         Text(
           '${user['xpCount']} XP',
           textAlign: TextAlign.center,
           style: GoogleFonts.inter(
             fontWeight: FontWeight.w500,
             color: colors[0],
             fontSize: 12,
             letterSpacing: 0.0,
           ),
         ),
        if (user['lastMonthLikes'] != null && user['lastMonthLikes'] > 0) ...[
          const SizedBox(height: 2),
          _buildChangeIndicator(user['changePercent']),
        ],
        // 1. sıra için özel başarı göstergesi
        if (rank == 1) ...[
          const SizedBox(height: 4),
          _buildAchievementBadge(),
        ],
      ],
    );
  }

  // Değişim göstergesi widget'ı
  Widget _buildChangeIndicator(double changePercent) {
    bool isPositive = changePercent > 0;
    bool isNeutral = changePercent == 0;
    
    Color indicatorColor;
    String changeText;
    IconData changeIcon;
    
    if (isNeutral) {
      indicatorColor = const Color(0xFF007AFF);
      changeText = '0%';
      changeIcon = Icons.remove;
    } else if (isPositive) {
      indicatorColor = const Color(0xFFFF6B35);
      changeText = '+${changePercent.toStringAsFixed(0)}%';
      changeIcon = Icons.trending_up;
    } else {
      indicatorColor = const Color(0xFFFF3B30);
      changeText = '${changePercent.toStringAsFixed(0)}%';
      changeIcon = Icons.trending_down;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: indicatorColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            changeIcon,
            size: 10,
            color: indicatorColor,
          ),
          const SizedBox(width: 2),
          Text(
            changeText,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: indicatorColor,
            ),
          ),
        ],
      ),
    );
  }

  // Başarı rozeti widget'ı (1. sıra için)
  Widget _buildAchievementBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD93D), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star,
            size: 12,
            color: Color(0xFFFFFFFF),
          ),
          const SizedBox(width: 4),
          Text(
            'CHAMPION',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFFFFF),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Sıralama rozeti widget'ı (1-3. sıra için)
  Widget _buildRankBadge(int rank) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;
    
    switch (rank) {
      case 1:
        badgeColor = const Color(0xFFFFD93D); // Altın
        badgeText = 'GOLD';
        badgeIcon = Icons.emoji_events;
        break;
      case 2:
        badgeColor = const Color(0xFFFF3B30); // Kırmızı
        badgeText = 'SILVER';
        badgeIcon = Icons.emoji_events;
        break;
      case 3:
        badgeColor = const Color(0xFFFF6B35); // Turuncu
        badgeText = 'BRONZE';
        badgeIcon = Icons.emoji_events;
        break;
      default:
        badgeColor = const Color(0xFF007AFF);
        badgeText = 'RANK $rank';
        badgeIcon = Icons.star;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 10,
            color: const Color(0xFFFFFFFF),
          ),
          const SizedBox(width: 3),
          Text(
            badgeText,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFFFFF),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicLeaderboardItem({
    required Map<String, dynamic> user,
    required Color rankColor,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF007AFF).withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      rankColor,
                      rankColor.withValues(alpha: 0.8),
                    ],
                    stops: const [0, 1],
                    begin: const AlignmentDirectional(1, -1),
                    end: const AlignmentDirectional(-1, 1),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Align(
                  alignment: const AlignmentDirectional(0, 0),
                  child: _getRankIcon(user['rank'], false),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(targetUserId: user['userId']),
                    ),
                  );
                },
                child: Container(
                  width: 50,
                  height: 50,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: user['profilePhoto'] != null && user['profilePhoto'].isNotEmpty
                      ? CachedNetworkImage(
                          fadeInDuration: const Duration(milliseconds: 0),
                          fadeOutDuration: const Duration(milliseconds: 0),
                          imageUrl: user['profilePhoto'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.person, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(targetUserId: user['userId']),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'Bilinmeyen',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: 0.0,
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['username'] ?? '',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFFFFF).withOpacity(0.7),
                          fontSize: 14,
                          letterSpacing: 0.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(
                     '${user['xpCount']} XP',
                     style: GoogleFonts.inter(
                       fontWeight: FontWeight.w600,
                       color: rankColor,
                       fontSize: 16,
                       letterSpacing: 0.0,
                     ),
                   ),
                  if (user['lastMonthLikes'] != null && user['lastMonthLikes'] > 0) ...[
                    const SizedBox(height: 4),
                    _buildChangeIndicator(user['changePercent']),
                  ],
                  // Sıralama rozetleri
                  if (user['rank'] <= 3) ...[
                    const SizedBox(height: 4),
                    _buildRankBadge(user['rank']),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
