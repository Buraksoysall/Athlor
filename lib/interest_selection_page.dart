import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';

class InterestSelectionPage extends StatefulWidget {
  const InterestSelectionPage({super.key});

  @override
  State<InterestSelectionPage> createState() => _InterestSelectionPageState();
}

class _InterestSelectionPageState extends State<InterestSelectionPage> {
  bool _isLoading = false;
  List<String> _selectedInterests = [];

  // 6 branş kategorisi
  final List<Map<String, dynamic>> _interestCategories = [
    {'id': 'tennis', 'name': 'Tenis', 'icon': Icons.sports_tennis, 'color': Colors.green},
    {'id': 'football', 'name': 'Futbol', 'icon': Icons.sports_soccer, 'color': Colors.blue},
    {'id': 'basketball', 'name': 'Basketbol', 'icon': Icons.sports_basketball, 'color': Colors.orange},
    {'id': 'volleyball', 'name': 'Voleybol', 'icon': Icons.sports_volleyball, 'color': Colors.purple},
    {'id': 'boxing', 'name': 'Boks', 'icon': Icons.sports_mma, 'color': Colors.red},
    {'id': 'fitness', 'name': 'Fitness', 'icon': Icons.fitness_center, 'color': Colors.cyan},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Başlık
              Text(
                'İlgi Alanlarınızı Seçin',
                style: GoogleFonts.interTight(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hangi spor branşlarıyla ilgilendiğinizi seçin. Bu bilgiler profilinizde görünecek.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 40),
              
              // İlgi alanları grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _interestCategories.length,
                  itemBuilder: (context, index) {
                    final category = _interestCategories[index];
                    final isSelected = _selectedInterests.contains(category['id']);
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedInterests.remove(category['id']);
                          } else {
                            _selectedInterests.add(category['id']);
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? (category['color'] as Color).withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected 
                                ? category['color'] as Color
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? category['color'] as Color
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                category['icon'],
                                color: isSelected 
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              category['name'],
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected 
                                    ? category['color'] as Color
                                    : Colors.grey.shade700,
                              ),
                            ),
                            if (isSelected)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: category['color'] as Color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Seçildi',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Devam et butonu
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedInterests.isEmpty || _isLoading ? null : _saveInterests,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedInterests.isEmpty 
                        ? Colors.grey.shade300 
                        : Colors.green,
                    foregroundColor: _selectedInterests.isEmpty 
                        ? Colors.grey.shade600 
                        : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _selectedInterests.isEmpty 
                              ? 'En az bir branş seçin'
                              : 'Devam Et (${_selectedInterests.length} seçildi)',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Atla butonu
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _skipSelection,
                  child: Text(
                    'Şimdilik atla',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
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

  Future<void> _saveInterests() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Firestore'da ilgi alanlarını kaydet
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'interests': _selectedInterests,
        'interestsUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Ana sayfaya yönlendir
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İlgi alanlarınız kaydedildi!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İlgi alanları kaydedilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _skipSelection() async {
    // Ana sayfaya yönlendir
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İlgi alanlarınızı daha sonra ayarlayabilirsiniz'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
