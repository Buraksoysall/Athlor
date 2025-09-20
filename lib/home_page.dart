import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'add_activity_page.dart';
import 'message_page.dart';
import 'chat_page.dart';
import 'profile_page.dart';
import 'comments_page.dart';
import 'my_activities_page.dart';
import 'leaderboard_page.dart';
import 'unread_message_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _selectedCategory;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Bottom navigation için
  int _currentIndex = 0;
  
  // Çoklu seçim için
  List<String> _selectedCategories = [];
  
  // Cache için
  List<QueryDocumentSnapshot>? _cachedActivities;
  bool _isLoading = true;
  
  // Lazy loading için
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  DocumentSnapshot? _lastDocument;
  static const int _initialLoadCount = 20;
  static const int _loadMoreCount = 10;
  
  // Yorum ve beğeni için
  Map<String, int> _likeCounts = {};
  Map<String, bool> _userLikes = {};
  Map<String, List<Map<String, dynamic>>> _comments = {};
  
  // Real-time like counter için
  StreamSubscription? _likesListener;
  
  // Batch processing için
  List<String> _pendingLikeUpdates = [];
  Timer? _batchTimer;
  
  // Okunmamış mesajlar için
  bool _hasUnreadMessages = false;
  StreamSubscription? _unreadMessagesListener;
  Set<String> _readChats = {}; // Okunmuş chat'lerin listesi
  
  // Aktivite like sayılarını al
  Future<int> _getActivityLikeCount(String activityId) async {
    try {
      QuerySnapshot likesSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('activityId', isEqualTo: activityId)
          .get();
      return likesSnapshot.docs.length;
    } catch (e) {
      print('Like sayısı alınırken hata: $e');
      return 0;
    }
  }
  
  
  // Kategori listesi - Enerjik ve uyumlu renk paleti
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Tümü', 'icon': Icons.all_inclusive, 'color': const Color(0xFF8A2BE2), 'emoji': '🏃'},
    {'name': 'Tenis', 'icon': Icons.sports_tennis, 'color': const Color(0xFF22C55E), 'emoji': '🎾'},
    {'name': 'Futbol', 'icon': Icons.sports_soccer, 'color': const Color(0xFF007AFF), 'emoji': '⚽'},
    {'name': 'Basketbol', 'icon': Icons.sports_basketball, 'color': const Color(0xFFFF6B35), 'emoji': '🏀'},
    {'name': 'Voleybol', 'icon': Icons.sports_volleyball, 'color': const Color(0xFF8A2BE2), 'emoji': '🏐'},
    {'name': 'Boks', 'icon': Icons.sports_martial_arts, 'color': const Color(0xFFFF3B30), 'emoji': '🥊'},
    {'name': 'Fitness', 'icon': Icons.fitness_center, 'color': const Color(0xFF06B6D4), 'emoji': '💪'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _selectedCategory = 'Tümü'; // Varsayılan olarak "Tümü" seçili
    _loadInitialData();
    
    // Real-time like counter'ı başlat
    _startRealTimeLikeCounter();
    
    // Okunmamış mesajları kontrol et
    _loadReadChats();
    _startUnreadMessagesListener();
    
    // Background'da leaderboard hesaplamasını gecikmeli başlat
    Future.delayed(const Duration(seconds: 5), () {
      _preloadLeaderboardData();
    });
  }

  // Background'da leaderboard verilerini önceden hesapla (GÜVENLİ)
  Future<void> _preloadLeaderboardData() async {
    try {
      print('BACKGROUND: Leaderboard verileri önceden hesaplanıyor...');
      
      // Küçük batch'ler halinde işle
      const int batchSize = 10;
      
      // Tüm beğeni verilerini küçük parçalar halinde çek
      QuerySnapshot likesSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .limit(100) // İlk 100 beğeni
          .get();
      
      if (likesSnapshot.docs.isEmpty) {
        print('BACKGROUND: Beğeni verisi bulunamadı');
        return;
      }
      
      // Activity ID'ye göre beğeni sayılarını grupla
      Map<String, int> activityLikeCounts = {};
      for (var likeDoc in likesSnapshot.docs) {
        try {
          Map<String, dynamic> likeData = likeDoc.data() as Map<String, dynamic>;
          String activityId = likeData['activityId'] ?? '';
          if (activityId.isNotEmpty) {
            activityLikeCounts[activityId] = (activityLikeCounts[activityId] ?? 0) + 1;
          }
        } catch (e) {
          print('BACKGROUND: Beğeni verisi işlenirken hata: $e');
          continue;
        }
      }
      
      // Tüm aktiviteleri küçük parçalar halinde çek
      QuerySnapshot activitiesSnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .limit(50) // İlk 50 aktivite
          .get();
      
      if (activitiesSnapshot.docs.isEmpty) {
        print('BACKGROUND: Aktivite verisi bulunamadı');
        return;
      }
      
      // Kullanıcı başına toplam beğeni sayısını hesapla
      Map<String, int> userLikeCounts = {};
      for (var activityDoc in activitiesSnapshot.docs) {
        try {
          String activityId = activityDoc.id;
          Map<String, dynamic> activityData = activityDoc.data() as Map<String, dynamic>;
          String createdBy = activityData['createdBy'] ?? '';
          
          if (createdBy.isNotEmpty) {
            int likeCount = activityLikeCounts[activityId] ?? 0;
            userLikeCounts[createdBy] = (userLikeCounts[createdBy] ?? 0) + likeCount;
          }
        } catch (e) {
          print('BACKGROUND: Aktivite verisi işlenirken hata: $e');
          continue;
        }
      }
      
      // Hesaplanan verileri kullanıcıların likes alanına kaydet (küçük batch'ler)
      List<String> userIds = userLikeCounts.keys.toList();
      for (int i = 0; i < userIds.length; i += batchSize) {
        List<String> batch = userIds.skip(i).take(batchSize).toList();
        
        for (String userId in batch) {
          try {
            int totalLikes = userLikeCounts[userId] ?? 0;
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .update({
              'likes': totalLikes,
              'likesUpdatedAt': FieldValue.serverTimestamp(),
            });
            
            // Kısa bir bekleme ekle
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (e) {
            print('BACKGROUND: Kullanıcı $userId güncellenirken hata: $e');
            continue;
          }
        }
      }
      
      print('BACKGROUND: ${userLikeCounts.length} kullanıcının beğeni sayısı güncellendi');
    } catch (e) {
      print('BACKGROUND: Leaderboard verileri hesaplanırken hata: $e');
    }
  }

  // Real-time like counter başlat (OPTIMIZED)
  void _startRealTimeLikeCounter() {
    print('REAL-TIME: Optimized like counter başlatılıyor...');
    
    // Sadece son 24 saatteki like'ları dinle
    DateTime yesterday = DateTime.now().subtract(const Duration(hours: 24));
    
    _likesListener = FirebaseFirestore.instance
        .collection('likes')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
        .snapshots()
        .listen((snapshot) {
      _handleLikeChangesOptimized(snapshot);
    });
  }

  // Optimized like değişikliklerini işle (BATCH PROCESSING)
  Future<void> _handleLikeChangesOptimized(QuerySnapshot snapshot) async {
    try {
      // Sadece yeni eklenen like'ları batch'e ekle
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          try {
            Map<String, dynamic> likeData = change.doc.data() as Map<String, dynamic>;
            String activityId = likeData['activityId'] ?? '';
            
            if (activityId.isNotEmpty) {
              _pendingLikeUpdates.add(activityId);
            }
          } catch (e) {
            print('REAL-TIME: Yeni like işlenirken hata: $e');
          }
        }
      }
      
      // Batch timer'ı başlat (5 saniye sonra işle)
      _batchTimer?.cancel();
      _batchTimer = Timer(const Duration(seconds: 5), () {
        _processBatchLikeUpdates();
      });
      
    } catch (e) {
      print('REAL-TIME: Like değişiklikleri işlenirken hata: $e');
    }
  }

  // Batch like güncellemelerini işle (ÇOK VERİMLİ)
  Future<void> _processBatchLikeUpdates() async {
    if (_pendingLikeUpdates.isEmpty) return;
    
    try {
      // Aktivite ID'lerini grupla
      Map<String, int> activityLikeCounts = {};
      for (String activityId in _pendingLikeUpdates) {
        activityLikeCounts[activityId] = (activityLikeCounts[activityId] ?? 0) + 1;
      }
      
      // Batch olarak tüm aktiviteleri çek
      List<Future> futures = [];
      for (String activityId in activityLikeCounts.keys) {
        futures.add(_updateActivityOwnerLikes(activityId, activityLikeCounts[activityId]!));
      }
      
      await Future.wait(futures);
      
      // Batch'i temizle
      _pendingLikeUpdates.clear();
      
    } catch (e) {
      print('REAL-TIME: Batch like güncellemeleri işlenirken hata: $e');
    }
  }

  // Aktivite sahibinin like sayısını güncelle (BATCH)
  Future<void> _updateActivityOwnerLikes(String activityId, int likeCount) async {
    try {
      // Aktiviteyi çek
      DocumentSnapshot activityDoc = await FirebaseFirestore.instance
          .collection('activities')
          .doc(activityId)
          .get();
      
      if (activityDoc.exists) {
        Map<String, dynamic> activityData = activityDoc.data() as Map<String, dynamic>;
        String createdBy = activityData['createdBy'] ?? '';
        
        if (createdBy.isNotEmpty) {
          // Kullanıcının mevcut like sayısını al ve artır
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(createdBy)
              .get();
          
          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            int currentLikes = userData['likes'] ?? 0;
            int newLikes = currentLikes + likeCount;
            
            // Güncelle
            await FirebaseFirestore.instance
                .collection('users')
                .doc(createdBy)
                .update({
              'likes': newLikes,
              'likesUpdatedAt': FieldValue.serverTimestamp(),
            });
            
            print('REAL-TIME: Kullanıcı $createdBy - $newLikes beğeni (+$likeCount)');
          }
        }
      }
    } catch (e) {
      print('REAL-TIME: Kullanıcı like sayısı güncellenirken hata: $e');
    }
  }

  // Okunmamış mesajları kontrol et (optimized)
  void _startUnreadMessagesListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    print('DEBUG: Unread messages listener başlatılıyor...');
    _unreadMessagesListener = UnreadMessageService
        .getAnyUnreadStream(currentUser.uid)
        .listen((hasUnread) {
      print('DEBUG: Unread messages durumu: $hasUnread');
      if (mounted) {
        setState(() {
          _hasUnreadMessages = hasUnread;
        });
      }
    });
  }



  // Okunmuş chat'leri SharedPreferences'dan yükle
  Future<void> _loadReadChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readChatsJson = prefs.getString('read_chats');
      if (readChatsJson != null) {
        final List<dynamic> readChatsList = json.decode(readChatsJson);
        setState(() {
          _readChats = readChatsList.cast<String>().toSet();
        });
        print('DEBUG: Okunmuş chat\'ler yüklendi: $_readChats');
      }
    } catch (e) {
      print('DEBUG: Okunmuş chat\'ler yüklenirken hata: $e');
    }
  }

  // Okunmuş chat'leri SharedPreferences'a kaydet
  Future<void> _saveReadChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readChatsJson = json.encode(_readChats.toList());
      await prefs.setString('read_chats', readChatsJson);
      print('DEBUG: Okunmuş chat\'ler kaydedildi: $_readChats');
    } catch (e) {
      print('DEBUG: Okunmuş chat\'ler kaydedilirken hata: $e');
    }
  }

  // Belirli bir chat'i okunmuş olarak işaretle
  void _markChatAsRead(String chatId) {
    setState(() {
      _readChats.add(chatId);
      _hasUnreadMessages = false; // Chat açıldığında bildirimi kapat
    });
    _saveReadChats();
    
    print('DEBUG: Chat okunmuş olarak işaretlendi: $chatId');
    print('DEBUG: Okunmuş chat listesi: $_readChats');
  }

  // Uygulama foreground'a geldiğinde okunmamış mesajları kontrol et
  void _refreshUnreadMessages() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Unread message service kullanarak kontrol et
    UnreadMessageService.hasAnyUnreadMessages(currentUser.uid).then((hasUnread) {
      if (mounted) {
        setState(() {
          _hasUnreadMessages = hasUnread;
        });
      }
    });
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _likesListener?.cancel(); // Real-time listener'ı durdur
    _batchTimer?.cancel(); // Batch timer'ı durdur
    _unreadMessagesListener?.cancel(); // Okunmamış mesaj listener'ını durdur
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Uygulama foreground'a geldiğinde verileri yenile
      print('APP: Uygulama foreground\'a geldi, veriler yenileniyor...');
      _refreshData();
      _refreshUnreadMessages();
    }
  }

  // Verileri yenile - hem aktiviteleri hem de katılım durumlarını güncelle
  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  void _selectCategory(String? category) {
    setState(() {
      if (category == 'Tümü' || category == null) {
        _selectedCategory = 'Tümü';
        _selectedCategories.clear();
      } else {
        _selectedCategory = null;
        if (_selectedCategories.contains(category)) {
          _selectedCategories.remove(category);
        } else {
          _selectedCategories.add(category);
        }
      }
      
      // Kategori değiştiğinde lazy loading state'ini sıfırla
      _isLoadingMore = false;
      _hasMoreData = true;
      _lastDocument = null;
    });
  }

  // İlk veri yükleme - Lazy loading ile
  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final snapshot = await FirebaseFirestore.instance
          .collection('activities')
          .orderBy('createdAt', descending: true)
          .limit(_initialLoadCount)
          .get();
      
      setState(() {
        _cachedActivities = snapshot.docs;
        _isLoading = false;
        _hasMoreData = snapshot.docs.length == _initialLoadCount;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      });
      
      // Her aktivite için beğeni ve yorum verilerini yükle
      await _loadLikesAndComments();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('İlk veri yükleme hatası: $e');
    }
  }

  // Daha fazla aktivite yükle - Lazy loading
  Future<void> _loadMoreActivities() async {
    if (_isLoadingMore || !_hasMoreData || _lastDocument == null) return;
    
    print('LAZY LOADING: Daha fazla aktivite yükleniyor... (${_cachedActivities?.length ?? 0} mevcut)');
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('activities')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_loadMoreCount)
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('LAZY LOADING: Daha fazla veri yok, yükleme durduruluyor');
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
        return;
      }
      
      print('LAZY LOADING: ${snapshot.docs.length} yeni aktivite yüklendi');
      
      setState(() {
        _cachedActivities!.addAll(snapshot.docs);
        _hasMoreData = snapshot.docs.length == _loadMoreCount;
        _lastDocument = snapshot.docs.last;
        _isLoadingMore = false;
      });
      
      // Yeni yüklenen aktiviteler için beğeni ve yorum verilerini yükle
      await _loadLikesAndCommentsForNewActivities(snapshot.docs);
      
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      print('Daha fazla aktivite yükleme hatası: $e');
    }
  }

  // Yeni yüklenen aktiviteler için beğeni ve yorum verilerini yükle
  Future<void> _loadLikesAndCommentsForNewActivities(List<QueryDocumentSnapshot> newActivities) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Tüm yeni aktiviteler için beğeni sayılarını paralel olarak yükle
    List<Future<void>> futures = [];
    
    for (final doc in newActivities) {
      final activityId = doc.id;
      futures.add(_loadActivityLikesAndComments(activityId, user.uid));
    }
    
    // Tüm beğeni ve yorum verilerini paralel olarak yükle
    await Future.wait(futures);
    
    if (mounted) setState(() {});
  }
  
  // Kullanıcının bir aktiviteye katılıp katılmadığını kontrol et
  Future<bool> _isUserParticipant(String activityId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    try {
      // Önce kullanıcının myJoinedActivities array'ini kontrol et
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final myJoinedActivities = userData['myJoinedActivities'] as List<dynamic>? ?? [];
        
        if (myJoinedActivities.contains(activityId)) {
          return true;
        }
      }
      
      // Eğer myJoinedActivities'de yoksa, aktivitenin participants array'ini kontrol et
      final activityDoc = await FirebaseFirestore.instance
          .collection('activities')
          .doc(activityId)
          .get();
      
      if (activityDoc.exists) {
        final activityData = activityDoc.data() as Map<String, dynamic>;
        final participants = activityData['participants'] as List<dynamic>? ?? [];
        return participants.contains(user.uid);
      }
      
      return false;
    } catch (e) {
      print('Katılım durumu kontrol hatası: $e');
      return false;
    }
  }

  // Aktivite silme fonksiyonu
  Future<void> _deleteActivity(String activityId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Aktivite referansı
      DocumentReference activityRef = FirebaseFirestore.instance
          .collection('activities')
          .doc(activityId);

      DocumentSnapshot activityDoc = await activityRef.get();

      if (!activityDoc.exists) {
        print("Aktivite bulunamadı");
        return;
      }

      Map<String, dynamic> data = activityDoc.data() as Map<String, dynamic>;

      // Sadece aktivite sahibi silebilir
      if (data['createdBy'] != user.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bu aktiviteyi silme yetkiniz yok."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Batch başlat
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Aktiviteyi sil
      batch.delete(activityRef);

      // 2. Kullanıcının "myJoinedActivities" listesinden kaldır
      DocumentReference userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      batch.update(userRef, {
        'myJoinedActivities': FieldValue.arrayRemove([activityId]),
        'myJoinedActivitiesUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Batch commit
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aktivite başarıyla silindi"),
          backgroundColor: Colors.green,
        ),
      );

      // Listeyi yenile
      _loadInitialData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aktivite silinirken hata: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Aktiviteye katıl
  Future<void> _joinActivity(String activityId, Map<String, dynamic> activity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giriş yapmanız gerekiyor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final participants = activity['participants'] as List<dynamic>? ?? [];
    final maxParticipants = activity['maxParticipants'] as int? ?? 20;

    // Zaten katılımcı mı kontrol et - güvenilir kontrol
    final isAlreadyParticipant = await _isUserParticipant(activityId);
    if (isAlreadyParticipant) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu aktiviteye zaten katıldınız'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Katılımcı limiti kontrol et
    if (participants.length >= maxParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu aktivite dolu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Batch işlem başlat
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      // Aktiviteye katıl
      DocumentReference activityRef = FirebaseFirestore.instance
          .collection('activities')
          .doc(activityId);
      
      batch.update(activityRef, {
        'participants': FieldValue.arrayUnion([user.uid]),
      });
      
      // Kullanıcının katıldığı aktiviteler listesine ekle
      DocumentReference userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      
      batch.update(userRef, {
        'myJoinedActivities': FieldValue.arrayUnion([activityId]),
        'myJoinedActivitiesUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      // Batch işlemi çalıştır
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktiviteye başarıyla katıldınız!'),
          backgroundColor: Colors.green,
        ),
      );

      // Verileri yenile - hem aktiviteleri hem de katılım durumlarını güncelle
      await _loadInitialData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Katılım sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Aktivitelerden çık
  Future<void> _leaveActivity(String activityId, Map<String, dynamic> activity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giriş yapmanız gerekiyor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Katılımcı mı kontrol et - güvenilir kontrol
    final isParticipant = await _isUserParticipant(activityId);
    if (!isParticipant) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu aktiviteye katılmamışsınız'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Batch işlem başlat
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      // Aktivitelerden çık
      DocumentReference activityRef = FirebaseFirestore.instance
          .collection('activities')
          .doc(activityId);
      
      batch.update(activityRef, {
        'participants': FieldValue.arrayRemove([user.uid]),
      });
      
      // Kullanıcının katıldığı aktiviteler listesinden çıkar
      DocumentReference userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      
      batch.update(userRef, {
        'myJoinedActivities': FieldValue.arrayRemove([activityId]),
        'myJoinedActivitiesUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      // Batch işlemi çalıştır
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktivitelerden başarıyla çıktınız!'),
          backgroundColor: Colors.green,
        ),
      );

      // Verileri yenile - hem aktiviteleri hem de katılım durumlarını güncelle
      await _loadInitialData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Çıkış sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Beğeni ve yorum verilerini yükle
  Future<void> _loadLikesAndComments() async {
    if (_cachedActivities == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Tüm aktiviteler için beğeni sayılarını paralel olarak yükle
    List<Future<void>> futures = [];
    
    for (final doc in _cachedActivities!) {
      final activityId = doc.id;
      futures.add(_loadActivityLikesAndComments(activityId, user.uid));
    }
    
    // Tüm beğeni ve yorum verilerini paralel olarak yükle
    await Future.wait(futures);
    
    if (mounted) setState(() {});
  }
  
  // Tek bir aktivite için beğeni ve yorum verilerini yükle
  Future<void> _loadActivityLikesAndComments(String activityId, String userId) async {
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
          .where('userId', isEqualTo: userId)
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

  // Filtrelenmiş aktiviteleri al
  List<QueryDocumentSnapshot> _getFilteredActivities() {
    if (_cachedActivities == null) return [];
    
    // Eğer hiç kategori seçilmemişse veya "Tümü" seçilmişse tüm aktiviteleri döndür
    if (_selectedCategory == null && _selectedCategories.isEmpty) {
      return _cachedActivities!;
    }
    
    // Seçili kategorilere göre filtrele
    return _cachedActivities!.where((doc) {
      final activity = doc.data() as Map<String, dynamic>;
      final activityCategory = activity['category'] as String?;
      
      if (activityCategory == null) return false;
      
      // "Tümü" seçilmişse tüm aktiviteleri göster
      if (_selectedCategory == 'Tümü') {
        return true;
      }
      
      // Çoklu kategori seçimi varsa
      if (_selectedCategories.isNotEmpty) {
        return _selectedCategories.contains(activityCategory);
      }
      
      // Tek kategori seçimi varsa
      if (_selectedCategory != null) {
        return activityCategory == _selectedCategory;
      }
      
      return false;
    }).toList();
  }

  // Lazy loading için daha fazla veri yükleme kontrolü
  bool _shouldLoadMore(int currentIndex) {
    final filteredActivities = _getFilteredActivities();
    return currentIndex >= filteredActivities.length - 3 && 
           _hasMoreData && 
           !_isLoadingMore &&
           _lastDocument != null;
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

  // Kullanıcı profil fotoğrafını al (basitleştirilmiş)
  Future<String?> _getUserProfileImage(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 3));
      
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
        });
      }
      
      // Beğeni sayısını güncelle
      await _loadActivityLikesAndComments(activityId, user.uid);
      if (mounted) setState(() {});
      
    } catch (e) {
      print('Beğeni hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beğeni işlemi başarısız: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  
  // Belirli bir aktivite için yorumları yükle
  Future<void> _loadCommentsForActivity(String activityId) async {
    try {
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
      
      if (mounted) setState(() {});
    } catch (e) {
      print('Yorum yükleme hatası: $e');
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
      _loadCommentsForActivity(activityId);
    });
  }
  



  // Modern tam ekran resim görüntüleyici
  void _showImageDialog(BuildContext context, String imageUrl, List<dynamic> allImages, int currentIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.95),
            child: Stack(
              children: [
                // Arka plan - tıklanabilir
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                  ),
                ),
                // Ana resim
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.95,
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 300,
                              height: 300,
                              color: const Color(0xFF1C1B29),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(
                                      color: Color(0xFF8A2BE2),
                                      strokeWidth: 3,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Yükleniyor...',
                                      style: TextStyle(
                                        color: Color(0xFFFFFFFF),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 300,
                              height: 300,
                              color: const Color(0xFF1C1B29),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    size: 64,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Fotoğraf yüklenemedi',
                                    style: TextStyle(
                                      color: Color(0xFFFFFFFF),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Lütfen tekrar deneyin',
                                    style: TextStyle(
                                      color: const Color(0xFFFFFFFF).withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                // Modern kapatma butonu
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                // Resim sayısı göstergesi (birden fazla resim varsa)
                if (allImages.length > 1)
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${currentIndex + 1} / ${allImages.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Modern header widget - Enerjik spor teması
  Widget _buildModernHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1B29), Color(0xFF0E1E3A), Color(0xFF0A0A0A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A2BE2).withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          children: [
            // Üst kısım - Logo ve butonlar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo ve başlık
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8A2BE2).withOpacity(0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sports,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'AthlorKeşfet',
                      style: TextStyle(
                        fontFamily: 'InterTight',
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        color: Color(0xFFFFFFFF),
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
                // Sağ butonlar
                Row(
                  children: [
                    _buildHeaderButtonWithBadge(
                      icon: Icons.chat_bubble_outline_rounded,
                      hasUnreadMessages: _hasUnreadMessages,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MessagePage(
                              onChatOpened: _markChatAsRead,
                              readChats: _readChats,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildHeaderButton(
                      icon: Icons.person_outline_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfilePage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Kategori seçimi - Kompakt tasarım
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category['name'] || 
                                   _selectedCategories.contains(category['name']);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _selectCategory(category['name']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: isSelected 
                              ? const LinearGradient(
                                  colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF1C1B29), Color(0xFF0E1E3A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(21),
                          border: isSelected
                              ? null
                              : Border.all(color: const Color(0xFF8A2BE2).withOpacity(0.3), width: 1.5),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: const Color(0xFF8A2BE2).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ] : [
                            BoxShadow(
                              color: const Color(0xFF8A2BE2).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Center(
                            child: Text(
                              category['name'],
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                color: isSelected 
                                    ? Colors.white 
                                    : const Color(0xFFFFFFFF),
                                fontSize: 14,
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A2BE2).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildHeaderButtonWithBadge({
    required IconData icon, 
    required bool hasUnreadMessages,
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8A2BE2).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          // Kırmızı nokta badge
          if (hasUnreadMessages)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B30).withOpacity(0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.circle,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Tam ekran aktivite kartı - Instagram benzeri
  Widget _buildFullScreenActivityCard(Map<String, dynamic> activity, DateTime dateTime, String timeAgo) {
    final activityId = activity['id'] ?? '';
    final mediaUrls = activity['media'] as List<dynamic>? ?? [];
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(0),
        ),
        child: Stack(
          children: [
            // Ana medya içeriği
            if (mediaUrls.isNotEmpty)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, mediaUrls[0], mediaUrls, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(0),
                      child: Image.network(
                        mediaUrls[0],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: const Color(0xFFF3F4F6),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF6366F1).withOpacity(0.1),
                                  const Color(0xFF8B5CF6).withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 64,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              )
            else
              // Medya yoksa gradient arka plan
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF8A2BE2).withOpacity(0.1),
                        const Color(0xFF6C63FF).withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Üst overlay - Kullanıcı bilgisi ve menü
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 20,
                  20,
                  20,
                ),
                child: Row(
                  children: [
                    // Kullanıcı avatarı
                    FutureBuilder<String?>(
                      future: _getUserProfileImage(activity['createdBy']),
                      builder: (context, snapshot) {
                        final profileImageUrl = snapshot.data;
                        
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
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
                                        color: Colors.white.withOpacity(0.2),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.3),
                                              Colors.white.withOpacity(0.1),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _getCategoryEmoji(activity['category']),
                                            style: const TextStyle(fontSize: 20),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.3),
                                          Colors.white.withOpacity(0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getCategoryEmoji(activity['category']),
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    // Kullanıcı bilgileri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfilePage(
                                    targetUserId: activity['createdBy'],
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              activity['createdByName'] ?? 'Kullanıcı',
                              style: const TextStyle(
                                fontFamily: 'InterTight',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  activity['category'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Mesajlaşma ikonu veya silme butonu
                    if (activity['createdBy'] != FirebaseAuth.instance.currentUser?.uid)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                otherUserId: activity['createdBy'] ?? '',
                                otherUserName: activity['createdByName'] ?? 'Kullanıcı',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    else
                      // Aktivite sahibi için silme butonu
                      GestureDetector(
                        onTap: () => _deleteActivity(activityId),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Alt overlay - İçerik ve etkileşim butonları
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Aktivite başlığı
                    if (activity['title'] != null && activity['title'].isNotEmpty)
                      Text(
                        activity['title'],
                        style: const TextStyle(
                          fontFamily: 'InterTight',
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Aktivite açıklaması
                    if (activity['description'] != null && activity['description'].isNotEmpty)
                      Text(
                        activity['description'],
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Tarih bilgisi
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.event,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${dateTime.day}/${dateTime.month}/${dateTime.year}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Like sayısı
                    FutureBuilder<int>(
                      future: _getActivityLikeCount(activityId),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.favorite,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${(snapshot.data ?? 0) * 3} XP',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // Katılım/Çıkış butonu (sadece davet edilebilir aktiviteler için)
                    if (activity['isInviteEnabled'] == true)
                      FutureBuilder<bool>(
                        future: _isUserParticipant(activityId),
                        builder: (context, snapshot) {
                          final isParticipant = snapshot.data ?? false;
                          final participants = activity['participants'] as List<dynamic>? ?? [];
                          
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (isParticipant) {
                                  // Kullanıcı zaten katılmış, çıkış yap
                                  _leaveActivity(activityId, activity);
                                } else {
                                  // Kullanıcı katılmamış, katılım yap
                                  _joinActivity(activityId, activity);
                                }
                              },
                              icon: Icon(
                                isParticipant ? Icons.person_remove : Icons.person_add,
                                size: 20,
                              ),
                              label: Text(
                                isParticipant
                                    ? 'Çık (${participants.length}/${activity['maxParticipants'] ?? 20})'
                                    : 'Katıl (${participants.length}/${activity['maxParticipants'] ?? 20})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isParticipant ? const Color(0xFFFF3B30) : const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                shadowColor: isParticipant 
                                    ? const Color(0xFFFF3B30).withOpacity(0.5) 
                                    : const Color(0xFF6C63FF).withOpacity(0.3),
                              ),
                            ),
                          );
                        },
                      ),
                    
                    // Etkileşim butonları
                    Row(
                      children: [
                        FutureBuilder<int>(
                          future: _getActivityLikeCount(activityId),
                          builder: (context, snapshot) {
                            final likeCount = snapshot.data ?? 0;
                            return _buildFullScreenInteractionButton(
                              icon: _userLikes[activityId] == true 
                                  ? Icons.favorite 
                                  : Icons.favorite_border,
                              label: '$likeCount',
                              color: _userLikes[activityId] == true 
                                  ? const Color(0xFFFF3B30)
                                  : Colors.white,
                              onTap: () => _toggleLike(activityId),
                            );
                          },
                        ),
                        const SizedBox(width: 20),
                        _buildFullScreenInteractionButton(
                          icon: Icons.chat_bubble_outline,
                          label: '${_comments[activityId]?.length ?? 0}',
                          color: Colors.white,
                          onTap: () => _openCommentsPage(activity, activityId),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenInteractionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Loading card widget'ı
  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A2BE2).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Daha fazla aktivite yükleniyor...',
              style: TextStyle(
                fontFamily: 'InterTight',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lütfen bekleyin',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: const Color(0xFFFFFFFF).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Sayfa içeriklerini oluştur
  Widget _buildPageContent() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const MyActivitiesPage();
      case 2:
        return const LeaderboardPage();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        // Modern header
        _buildModernHeader(),
        // Aktivite listesi - Instagram benzeri tam ekran kartlar
        Expanded(
          child: _isLoading
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
                            'Henüz aktivite yok',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'İlk aktiviteyi sen oluştur!',
                            style: TextStyle(
                              fontSize: 16,
                              color: const Color(0xFFFFFFFF).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _getFilteredActivities().isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(60),
                                  border: Border.all(
                                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.filter_list,
                                  size: 64,
                                  color: Color(0xFFFF6B35),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Bu kategoride aktivite yok',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFFFFF),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Farklı bir kategori seçin',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: const Color(0xFFFFFFFF).withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        )
                      : PageView.builder(
                          itemCount: _getFilteredActivities().length + (_isLoadingMore ? 1 : 0),
                          onPageChanged: (index) {
                            // Son 3 aktiviteye yaklaştığında daha fazla yükle
                            if (_shouldLoadMore(index)) {
                              _loadMoreActivities();
                            }
                          },
                          itemBuilder: (context, index) {
                            // Loading indicator göster
                            if (index == _getFilteredActivities().length && _isLoadingMore) {
                              return _buildLoadingCard();
                            }
                            
                            final doc = _getFilteredActivities()[index];
                            final activity = doc.data() as Map<String, dynamic>;
                            activity['id'] = doc.id;
                            final createdAt = (activity['createdAt'] as Timestamp).toDate();
                            final now = DateTime.now();
                            final timeAgo = _getTimeAgo(createdAt, now);
                            
                            return _buildFullScreenActivityCard(activity, createdAt, timeAgo);
                          },
                        ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: _buildPageContent(),
        ),
        // Floating Action Button (sadece ana sayfa için)
        floatingActionButton: _currentIndex == 0
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8A2BE2).withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddActivityPage(),
                      ),
                    );
                    // AddActivityPage'den döndüğünde verileri yenile
                    setState(() {
                      _isLoading = true;
                      _cachedActivities = null;
                      _lastDocument = null;
                      _hasMoreData = true;
                    });
                    _loadInitialData();
                  },
                  backgroundColor: const Color(0xFF8A2BE2),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        // Bottom Navigation Bar
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Ana Sayfa
                  _buildNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Ana Sayfa',
                    index: 0,
                  ),
                  // Aktivitelerim
                  _buildNavItem(
                    icon: Icons.sports_outlined,
                    activeIcon: Icons.sports,
                    label: 'Aktivitelerim',
                    index: 1,
                  ),
                  // Leaderboard
                  _buildNavItem(
                    icon: Icons.leaderboard_outlined,
                    activeIcon: Icons.leaderboard,
                    label: 'Liderlik',
                    index: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        
        // Ana sayfaya döndüğünde verileri yenile
        if (index == 0) {
          _refreshData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF007AFF).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive 
                  ? const Color(0xFF007AFF)
                  : const Color(0xFFB0B0B0),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive 
                    ? const Color(0xFF007AFF)
                    : const Color(0xFFB0B0B0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

