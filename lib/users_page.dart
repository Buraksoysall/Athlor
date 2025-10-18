import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';
import 'block_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Engellenen kullanıcıları filtrele
  Future<List<QueryDocumentSnapshot>> _getFilteredUsers(List<QueryDocumentSnapshot> userDocs) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    
    List<QueryDocumentSnapshot> filteredUsers = [];
    
    for (final doc in userDocs) {
      final userData = doc.data() as Map<String, dynamic>;
      final userName = userData['displayName']?.toString().toLowerCase() ?? '';
      final username = userData['username']?.toString().toLowerCase() ?? '';
      final userId = userData['uid']?.toString() ?? '';
      
      // Mevcut kullanıcıyı listeden çıkar
      if (userId == currentUser.uid) continue;
      
      // Arama filtresi
      if (!userName.contains(_searchQuery) && !username.contains(_searchQuery)) {
        continue;
      }
      
      // Engel kontrolü yap
      final isBlocked = await BlockService.isBlocked(currentUser.uid, userId);
      if (!isBlocked) {
        filteredUsers.add(doc);
      }
    }
    
    return filteredUsers;
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
        title: Text(
          'Kullanıcılar',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1B29).withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF8A2BE2).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A2BE2).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Kullanıcı adı veya kullanıcı adı yazın...',
                  hintStyle: TextStyle(
                    color: const Color(0xFFFFFFFF).withOpacity(0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: const Color(0xFFFFFFFF).withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ),
          // Kullanıcı listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Bir hata oluştu',
                      style: TextStyle(
                        color: const Color(0xFFFFFFFF).withOpacity(0.7),
                        fontSize: 16,
                      ),
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

                // Bu kontrol artık gerekli değil çünkü arama yapılmadığında zaten boş liste gösteriyoruz

                // Eğer arama çubuğu boşsa hiçbir kullanıcı gösterme
                if (_searchQuery.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 64,
                          color: const Color(0xFF8A2BE2).withOpacity(0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kullanıcı aramak için yazmaya başlayın',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFFFFF).withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Arama çubuğuna bir şey yazın',
                          style: TextStyle(
                            color: const Color(0xFFFFFFFF).withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return FutureBuilder<List<QueryDocumentSnapshot>>(
                  future: _getFilteredUsers(snapshot.data!.docs),
                  builder: (context, filteredSnapshot) {
                    if (filteredSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8A2BE2)),
                        ),
                      );
                    }
                    
                    final filteredUsers = filteredSnapshot.data ?? [];

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: const Color(0xFF8A2BE2).withOpacity(0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kullanıcı bulunamadı',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFFFFF).withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Farklı bir arama terimi deneyin',
                          style: TextStyle(
                            color: const Color(0xFFFFFFFF).withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final userData = filteredUsers[index].data() as Map<String, dynamic>;
                    final userName = userData['displayName'] ?? 'Kullanıcı';
                    final username = userData['username'] ?? 'kullanici';
                    final userId = userData['uid'] ?? '';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1B29).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
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
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: FutureBuilder<String?>(
                          future: _getUserProfileImage(userId),
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
                                                color: Color(0xFF8A2BE2),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              userName.isNotEmpty 
                                                  ? userName[0].toUpperCase()
                                                  : 'K',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 18,
                                                color: Color(0xFF8A2BE2),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Center(
                                        child: Text(
                                          userName.isNotEmpty 
                                              ? userName[0].toUpperCase()
                                              : 'K',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 18,
                                            color: Color(0xFF8A2BE2),
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        title: Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        subtitle: Text(
                          '@$username',
                          style: TextStyle(
                            color: const Color(0xFFFFFFFF).withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        trailing: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8A2BE2).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    otherUserId: userId,
                                    otherUserName: userName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
