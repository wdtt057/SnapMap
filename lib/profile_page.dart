import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _userName = '';
  String _profilePictureUrl = "https://via.placeholder.com/150";
  int _followers = 0;
  int _following = 0;
  int _postCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Use UID as the username
        setState(() {
          _userName = user.uid;
        });

        // Fetch profile picture, followers, and following (optional)
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();

        if (userData != null) {
          setState(() {
            _profilePictureUrl = userData['profilePictureUrl'] ??
                "https://via.placeholder.com/150";
            _followers = userData['followers'] ?? 0;
            _following = userData['following'] ?? 0;
          });
        }

        final postsSnapshot = await _firestore
            .collection('photos')
            .where('userId', isEqualTo: user.uid)
            .get();
        setState(() {
          _postCount = postsSnapshot.size;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(_profilePictureUrl),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName, // Display UID as username
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("Followers: $_followers"),
                    Text("Following: $_following"),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      "$_postCount",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text("Posts"),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    // Implement edit profile functionality
                  },
                  child: const Text("Edit Profile"),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: const Text(
                  "Posts and other details will go here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
