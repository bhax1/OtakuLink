import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:otakulink/main.dart';

class MangaDetailsPage extends StatefulWidget {
  final int mangaId;
  final String userId;

  const MangaDetailsPage({Key? key, required this.mangaId, required this.userId})
      : super(key: key);

  @override
  _MangaDetailsPageState createState() => _MangaDetailsPageState();
}

class _MangaDetailsPageState extends State<MangaDetailsPage> {
  double _rating = 0;
  bool _isFavorite = false;
  bool _isLoading = false;
  String _readingStatus = 'Not Yet'; // Default reading status

  // Original values to check if anything changed
  double _originalRating = 0;
  bool _originalIsFavorite = false;
  String _originalReadingStatus = 'Not Yet';

  Map<String, dynamic>? mangaDetails;
  TextEditingController _commentaryController = TextEditingController(); // Controller for commentary

  @override
  void initState() {
    super.initState();
    _fetchMangaDetails();
    _fetchUserDetails();
  }

  // Fetch Manga details from the API
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

  // Fetch existing user details (rating, favorite, and reading status)
  Future<void> _fetchUserDetails() async {
    final doc = await FirebaseFirestore.instance
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
        _originalRating = _rating;
        _originalIsFavorite = _isFavorite;
        _originalReadingStatus = _readingStatus;
      });
    }
  }

  // Save the changes (rating, favorite, reading status, and commentary)
  Future<void> _saveMangaDetails() async {
    // Check if any changes were made
    if (_rating == _originalRating &&
        _isFavorite == _originalIsFavorite &&
        _readingStatus == _originalReadingStatus) {
      _showErrorDialog('No changes have been made.');
      return;
    }

    setState(() => _isLoading = true);

    // Extract genres from manga details and convert them into a list of strings
    List<String> genresList = [];
    if (mangaDetails?['genres'] != null) {
      genresList = List<String>.from(
        mangaDetails!['genres'].map((genre) => genre['name']),
      );
    }

    // Save the changes, including genres
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('manga_ratings')
        .doc(widget.mangaId.toString())
        .set({
      'rating': _rating,
      'isFavorite': _isFavorite,
      'readingStatus': _readingStatus,
      'genres': genresList,  // Add genres list here
      'commentary': _commentaryController.text.isNotEmpty
          ? _commentaryController.text
          : '',  // Save commentary if provided
    });

    setState(() => _isLoading = false);

    _showSuccessDialog('Changes Updated');
  }

  // Show error dialog
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

  // Show success dialog
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
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
          child: CircularProgressIndicator(),
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
    final publisher = mangaDetails?['serializations'] != null && mangaDetails!['serializations'].isNotEmpty
    ? mangaDetails!['serializations'].first['name']
    : 'Unknown Publisher';
    final status = mangaDetails?['status'] ?? 'Unknown Status';
    final description = mangaDetails?['synopsis'] ?? 'No description available';
    final genres = mangaDetails?['genres']
            ?.map((genre) => genre['name'])
            .join(', ') ?? 'No genres available';
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
        title: Text(
          mangaDetails?['title'] ?? 'Manga Details',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
              Text('Author: $author', style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Publisher: $publisher', style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Status: $status', style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Genres: $genres', style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Chapters: $chapters', style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Type: $type', style: TextStyle(fontSize: 16, color: primaryColor)),
              Text('Published: $publishedFrom to $publishedTo', style: TextStyle(fontSize: 14, color: primaryColor)),

              const SizedBox(height: 16),
              Text(description, style: TextStyle(fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 16),

              // User's rating, reading status, and favorite options
              Text('Your Rating: $_rating', style: TextStyle(fontSize: 16, color: primaryColor)),
              Slider(
                value: _rating,
                min: 0,
                max: 10,
                divisions: 10,
                label: _rating.toString(),
                activeColor: primaryColor,
                inactiveColor: accentColor,
                onChanged: (double value) {
                  setState(() {
                    _rating = value;
                  });
                },
              ),
              Text('Your Reading Status: $_readingStatus', style: TextStyle(fontSize: 16, color: primaryColor)),
              DropdownButton<String>(
                alignment: Alignment.center,
                dropdownColor: backgroundColor,
                value: _readingStatus,
                onChanged: (String? newValue) {
                  setState(() {
                    _readingStatus = newValue!;
                  });
                },
                items: <String>['Not Yet', 'Reading', 'Completed', 'Dropped']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              Row(
                children: [
                  Text('Favorite', style: TextStyle(fontSize: 16, color: primaryColor)),
                  Checkbox(
                    value: _isFavorite,
                    onChanged: (bool? value) {
                      setState(() {
                        _isFavorite = value!;
                      });
                    },
                  ),
                ],
              ),

              // Commentary
              TextField(
                controller: _commentaryController,
                decoration: InputDecoration(labelText: 'Add Commentary'),
                maxLines: null,
              ),

              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _saveMangaDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: backgroundColor,
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
