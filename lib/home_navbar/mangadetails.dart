import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:otakulink/home_navbar/viewcomments.dart';
import 'package:otakulink/main.dart';

class MangaDetailsPage extends StatefulWidget {
  final int mangaId;
  final String userId;

  const MangaDetailsPage(
      {Key? key, required this.mangaId, required this.userId})
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
  String _originalController = '';

  Map<String, dynamic>? mangaDetails;
  TextEditingController _commentaryController =
      TextEditingController(); // Controller for commentary

  @override
  void initState() {
    super.initState();
    _fetchMangaDetails();
    _fetchUserDetails();
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
        _commentaryController.text = doc['commentary'] ?? '';
        _originalRating = _rating;
        _originalIsFavorite = _isFavorite;
        _originalReadingStatus = _readingStatus;
        _originalController = doc['commentary'] ?? '';
      });
    }
  }

  Future<void> _saveMangaDetails() async {
    if (_rating == _originalRating &&
        _isFavorite == _originalIsFavorite &&
        _readingStatus == _originalReadingStatus &&
        _commentaryController == _originalController) {
      _showErrorDialog('No changes have been made.');
      return;
    }

    setState(() => _isLoading = true);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('manga_ratings')
        .doc(widget.mangaId.toString())
        .set({
      'rating': _rating,
      'isFavorite': _isFavorite,
      'readingStatus': _readingStatus,
      'commentary': _commentaryController.text.isNotEmpty
          ? _commentaryController.text
          : '',
      'timestamp': FieldValue.serverTimestamp(),
      'type': mangaDetails?['type'],
    });

    setState(() => _isLoading = false);

    _showSuccessDialog('Changes Updated');
  }

  void _showErrorDialog(String message) {
    setState(() => _isLoading = false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Opps'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

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
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteManga() async {
    // Check if the record exists
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('manga_ratings')
        .doc(widget.mangaId.toString())
        .get();

    if (!doc.exists) {
      _showErrorDialog("You don't have an existing rating for this.");
      return;
    }

    // Show a confirmation dialog
    bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
              'Are you sure you want to delete this manga from your list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    // If the user confirms deletion, proceed
    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('manga_ratings')
            .doc(widget.mangaId.toString())
            .delete();

        setState(() => _isLoading = false);

        // Show success dialog and navigate back
        _showSuccessDialog('Rating deleted successfully.');
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorDialog('Failed to delete rating. Please try again.');
      }
    }
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
                      userId: widget.userId,
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
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              _deleteManga();
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

              Text('Your Rating: $_rating',
                  style: TextStyle(fontSize: 16, color: primaryColor)),
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
              Text('Your Reading Status: $_readingStatus',
                  style: TextStyle(fontSize: 16, color: primaryColor)),
              DropdownButton<String>(
                alignment: Alignment.center,
                dropdownColor: backgroundColor,
                value: _readingStatus,
                onChanged: (String? newValue) {
                  setState(() {
                    _readingStatus = newValue!;
                  });
                },
                items: <String>[
                  'Not Yet',
                  'Reading',
                  'Completed',
                  'On Hold',
                  'Dropped'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              Row(
                children: [
                  Text(
                    'Favorite',
                    style: TextStyle(fontSize: 16, color: primaryColor),
                  ),
                  Checkbox(
                    value: _isFavorite,
                    activeColor: Colors.blue,
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      setState(() {
                        _isFavorite = value!;
                      });
                    },
                  ),
                ],
              ),

              TextSelectionTheme(
                data: TextSelectionThemeData(
                  selectionColor: Colors.grey,
                  selectionHandleColor: primaryColor,
                ),
                child: TextField(
                  controller: _commentaryController,
                  cursorColor: accentColor,
                  decoration: InputDecoration(
                    labelText: 'Add Commentary',
                    labelStyle: TextStyle(color: primaryColor),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: accentColor),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                    ),
                  ),
                  maxLines: null,
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _saveMangaDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: backgroundColor,
                  ),
                  child: const Text(
                    'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
