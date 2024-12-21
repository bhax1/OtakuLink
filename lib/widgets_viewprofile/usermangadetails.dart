import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:otakulink/main.dart';

import '../home_navbar/viewcomments.dart';

class UserMangaPage extends StatefulWidget {
  final int mangaId;
  final String userId;

  const UserMangaPage({Key? key, required this.mangaId, required this.userId})
      : super(key: key);

  @override
  _UserMangaPageState createState() => _UserMangaPageState();
}

class _UserMangaPageState extends State<UserMangaPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String currentUserId = '';
  double _rating = 0;
  bool _isFavorite = false;
  bool _isLoading = false;
  String _readingStatus = 'Not Yet';
  Map<String, dynamic>? mangaDetails;
  String _commentaryController = '';

  @override
  void initState() {
    super.initState();
    _fetchMangaDetails();
    _fetchUserDetails();
    _getCurrentUserId();
  }

  void _getCurrentUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        currentUserId = user.uid;
      });
    }
  }

  Future<void> _fetchMangaDetails() async {
    final url = 'https://api.jikan.moe/v4/manga/${widget.mangaId}';
    setState(() => _isLoading = true);

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          mangaDetails = jsonDecode(response.body)['data'];
          _isLoading = false;
        });
      } else {
        _showErrorDialog('Failed to load manga details. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('An error occurred: $e');
    }
  }

  Future<void> _fetchUserDetails() async {
    final doc = await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('manga_ratings')
        .doc(widget.mangaId.toString())
        .get();

    if (doc.exists) {
      setState(() {
        _rating = doc['rating'] ?? 0;
        _isFavorite = doc['isFavorite'] ?? false;
        _readingStatus = doc['readingStatus'] ?? 'Not Yet';
        _commentaryController = doc['commentary'] ?? '';
      });
    }
  }

  void _showErrorDialog(String message) {
    setState(() => _isLoading = false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || mangaDetails == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    // Helper function to format date
    String formatDate(String date) {
      try {
        final parsedDate = DateTime.parse(date);
        final formatter = DateFormat('MMMM dd, yyyy');
        return formatter.format(parsedDate);
      } catch (e) {
        return 'Unknown';
      }
    }

    // Extract manga details
    final author = mangaDetails?['authors']?.first['name'] ?? 'Unknown Author';
    final publisher = mangaDetails?['serializations'] != null &&
            mangaDetails!['serializations'].isNotEmpty
        ? mangaDetails!['serializations'].first['name']
        : 'Unknown Publisher';
    final status = mangaDetails?['status'] ?? 'Unknown Status';
    final description = mangaDetails?['synopsis'] ?? 'No description available';
    final genres =
        mangaDetails?['genres']?.map((genre) => genre['name']).join(', ') ??
            'No genres available';
    final chapters = mangaDetails?['chapters'] ?? 'Ongoing';
    final type = mangaDetails?['type'] ?? 'Unknown';
    final publishedFrom = mangaDetails?['published']['from'] != null
        ? formatDate(mangaDetails?['published']['from'])
        : 'Unknown';
    final publishedTo = mangaDetails?['published']['to'] != null
        ? formatDate(mangaDetails?['published']['to'])
        : 'Present';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Tooltip(
          message: mangaDetails?['title'] ?? 'Manga Details',
          child: Text(
            mangaDetails?['title'] ?? 'Manga Details',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.comment, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return CommentsPage(
                      mangaId: widget.mangaId,
                      userId: currentUserId,
                    );
                  },
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.fastOutSlowIn;
                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // Unfocus the text field when tapping outside of it
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mangaDetails?['images'] != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: CachedNetworkImage(
                    imageUrl: mangaDetails!['images']['jpg']['large_image_url'],
                    placeholder: (context, url) => SizedBox(
                      width: 150,
                      height: 480,
                      child: Center(
                        child: Icon(
                          Icons.image,
                          size: 50,
                          color: accentColor,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.error,
                      size: 50,
                      color: Colors.red,
                    ),
                    fit: BoxFit.cover, // Adjust based on your design
                  ),
                ),
              const SizedBox(height: 16.0),

              // Manga title and basic info
              Center(
                child: Text(
                  mangaDetails?['title'] ?? 'Unknown Title',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: primaryColor,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Text('Author: $author',
                  style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Publisher: $publisher',
                  style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Status: $status',
                  style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Genres: $genres',
                  style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Chapters: $chapters',
                  style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Type: $type',
                  style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Published: $publishedFrom to $publishedTo',
                  style: TextStyle(fontSize: 14, color: primaryColor)),

              const SizedBox(height: 16),
              Text(description,
                  style: TextStyle(fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 16),

              Text('Rating: $_rating',
                  style: TextStyle(fontSize: 16, color: primaryColor)),
              const SizedBox(height: 16),
              Text('Reading Status: $_readingStatus',
                  style: TextStyle(fontSize: 16, color: primaryColor)),
              const SizedBox(height: 16),

              Text(
                'Favorite: ${_isFavorite ? "Yes" : "No"}',
                style: TextStyle(fontSize: 16, color: primaryColor),
              ),

              const SizedBox(height: 16),
              Text("Commentary: $_commentaryController",
                  style: TextStyle(fontSize: 16, color: primaryColor)),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
