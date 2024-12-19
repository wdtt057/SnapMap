import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:location/location.dart';
import 'package:snapmap/post_detail.dart';
import 'package:snapmap/profile_page.dart';

import 'edit_post.dart';

class CustomFabLocation extends FloatingActionButtonLocation {
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width * 0.1;
    final double fabY = scaffoldGeometry.scaffoldSize.height * 5 / 6; // Align at bottom with some margin
    return Offset(fabX, fabY);
  }
}
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  late GoogleMapController _mapController;
  LatLng _initialCameraPosition = const LatLng(39.7283, -121.8380); // Default location (Chico)
  Location _location = Location();
  Set<Marker> _markers = {};

  File? _selectedImage;
  int _selectedIndex = 0;

  String _userName = "Dengtai";
  int _followers = 120;
  int _following = 150;
  int _postCount = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadMarkers();
  }

  // Get the user's current location
  Future<void> _getUserLocation() async {
    try {
      var currentLocation = await _location.getLocation();
      setState(() {
        _initialCameraPosition =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<String> generatePostId() async {
    final newPostRef = FirebaseFirestore.instance.collection('photos').doc();
    if (kDebugMode) {
      print('Generated Post ID: ${newPostRef.id}');
    } // Debugging
    return newPostRef.id;
  }

  // Capture image and upload it
  // Provide option to capture image or pick from gallery
  Future<void> _captureImageOption() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take a Photo'),
              onTap: () async {
                Navigator.pop(context); // Close the bottom sheet
                await _captureImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context); // Close the bottom sheet
                await _captureImage(ImageSource.gallery);
              },
            ),
          ],
        );
      },
    );
  }

// Capture image from a specific source
  Future<void> _captureImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo != null) {
      // Upload image to Firebase Storage and save metadata to Firestore
      final uploadedDoc = await _uploadImage(File(photo.path));

      if (uploadedDoc != null) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditPostPage(
              documentReference: uploadedDoc,
              currentDescription: '', // Provide default description
              currentLocation: LatLng(
                _initialCameraPosition.latitude,
                _initialCameraPosition.longitude,
              ), // Default location
            ),
          ),
        );

        if (result != null) {
          // Optionally handle results if needed
        }
      }
    }
  }

  Future<DocumentReference?> _uploadImage(File image) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child('photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await imageRef.putFile(image);

      final downloadUrl = await imageRef.getDownloadURL();

      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        print("Error: No authenticated user.");
        return null;
      }

      // Save metadata to Firestore and return the document reference
      return await _firestore.collection('photos').add({
        'url': downloadUrl,
        'userId': currentUser.uid,
        'userName': _userName,
        'description': '', // Empty by default
        'location': {
          'lat': _initialCameraPosition.latitude,
          'lng': _initialCameraPosition.longitude,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  void _addMarker(LatLng position, String imageUrl, String description) {
    final marker = Marker(
      markerId: MarkerId(imageUrl),
      position: position,
      infoWindow: InfoWindow(
        title: "Photo",
        snippet: description,
        onTap: () {
          // Show a dialog with the image preview
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(
                      imageUrl,
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(height: 8),
                    Text(description, style: const TextStyle(fontSize: 14)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("Close"),
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    setState(() {
      _markers.add(marker);
    });
  }



  // Load markers from Firestore
  Future<void> _loadMarkers() async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        print("Error: No authenticated user.");
        return;
      }

      final snapshot = await _firestore
          .collection('photos')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final location = data['location'];
        final imageUrl = data['url'];
        final description = data['description'] ?? "No description provided";

        _addMarker(
          LatLng(location['lat'], location['lng']),
          imageUrl,
          description,
        );
      }
    } catch (e) {
      print("Error loading markers: $e");
    }
  }



  // Bottom Navigation Content
  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const Center(child: Text('Welcome to SnapMap!\n Friend\'s post will be here'));
      case 1:
        return _buildMapView();
      case 2:
        return _buildPhotoGallery();
      default:
        return const Center(child: Text('Welcome to SnapMap!'));
    }
  }

  // Build Map View
  Widget _buildMapView() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _initialCameraPosition, zoom: 12),
      onMapCreated: (controller) {
        _mapController = controller;
        _loadMarkers();
      },
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }

  // Build Photo Gallery
  Widget _buildPhotoGallery() {
    final currentUser = _auth.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('photos')
          .where('userId', isEqualTo: currentUser?.uid) // Filter by userId
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final photos = snapshot.data!.docs;
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailPage(
                      imageUrl: photo['url'],
                      description: photo['description'],
                      location: LatLng(photo['location']['lat'], photo['location']['lng']),
                    ),
                  ),
                );
              },
              child: Image.network(photo['url'], fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }

  // Fetch post count from Firestore
  Future<void> _fetchPostCount() async {
    try {
      final querySnapshot = await _firestore.collection('photos').get();
      setState(() {
        _postCount = querySnapshot.size;
      });
    } catch (e) {
      print("Error fetching post count: $e");
    }
  }

  // Logout
  void _logout() async {
    await _auth.signOut();
    Navigator.of(context).pushReplacementNamed('/welcome'); // Redirect to Welcome Page
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SnapMap'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(
                      "https://via.placeholder.com/150", // Placeholder image
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userName,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        'Followers: $_followers',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Following: $_following',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.post_add),
              title: Text('Posts ($_postCount)'),
              onTap: () {
                // Navigate to posts page
                Navigator.pushNamed(context, '/posts');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureImageOption,
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: CustomFabLocation(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'Gallery'),
        ],
      ),
    );
  }
}
