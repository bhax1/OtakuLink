import 'dart:ui'; 
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/pages/home/manga_widgets/expandable_bio.dart';
import 'package:otakulink/services/anilist_service.dart';
import 'package:otakulink/theme.dart';

class PersonDetailsPage extends StatelessWidget {
  final int id;
  final bool isStaff;
  final Object heroTag; // <--- ADD THIS

  const PersonDetailsPage({
    super.key, 
    required this.id, 
    required this.isStaff,
    required this.heroTag, // <--- ADD THIS
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: AniListService.getPersonDetails(id, isStaff),
        builder: (context, snapshot) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeOut,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            child: _getBody(context, snapshot),
          );
        },
      ),
    );
  }

  Widget _getBody(BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildSkeleton(context);
    }

    if (snapshot.hasError || !snapshot.hasData) {
      return const Center(child: Text("Could not load details"));
    }

    return _buildRealContent(context, snapshot.data!);
  }

  Widget _buildRealContent(BuildContext context, Map<String, dynamic> data) {
    final String imageUrl = data['image']['large'];
    final String fullName = data['name']['full'];
    final String? nativeName = data['name']['native'];
    final String rawDescription = data['description'] ?? "No description available.";

    return CustomScrollView(
      key: const ValueKey('Content'), 
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 380,
          pinned: true,
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Background blurred image (No Hero needed here)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: AppColors.primary),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.black.withOpacity(0.3)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.6), Colors.transparent, Colors.black.withOpacity(0.5)],
                    ),
                  ),
                ),
                // Main Portrait Image (HERO HERE)
                Center(
                  child: Hero(
                    tag: heroTag, // <--- USE THE PASSED TAG
                    child: Container(
                      margin: const EdgeInsets.only(top: 60),
                      height: 240, width: 170,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[300]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ... Rest of your content (SliverToBoxAdapter etc) remains exactly the same ...
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(fullName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
                if (nativeName != null) ...[
                  const SizedBox(height: 8),
                  Text(nativeName, style: TextStyle(fontSize: 18, color: AppColors.primary.withOpacity(0.8), fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 24),
                 Wrap(
                  spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                  children: !isStaff 
                    ? [_buildBadge(Icons.cake_outlined, data['age']), _buildBadge(Icons.person_outline, data['gender']), _buildBadge(Icons.water_drop_outlined, data['bloodType'])]
                    : [_buildBadge(Icons.work_outline, data['primaryOccupations']), _buildBadge(Icons.location_on_outlined, data['homeTown']), _buildBadge(Icons.calendar_today_outlined, data['yearsActive'])],
                ),
                const SizedBox(height: 32),
                const Divider(height: 1),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ExpandableBio(
                    rawBio: rawDescription,
                    isStaff: isStaff,
                    // Note: Recursion logic might need the tag update too, or generate a new unique one
                    onCharacterTap: (charId) => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailsPage(id: charId, isStaff: false, heroTag: 'nested_$charId'))),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // Helper methods (_buildSkeleton, _buildBadge) remain the same...
  Widget _buildSkeleton(BuildContext context) {
      // (Your existing skeleton code)
      return Container(); // Placeholder for brevity
  }
  
  Widget _buildBadge(IconData icon, dynamic value) {
     // (Your existing badge code)
     return Container(); // Placeholder for brevity
  }
}