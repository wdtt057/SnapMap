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

      // Save metadata to Firestore and return the document reference
      return await _firestore.collection('photos').add({
        'url': downloadUrl,
        'userId': _auth.currentUser?.uid ?? 'anonymous',
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
        title: _userName,
        snippet: 'Photo Uploaded',
        onTap: () {
          // Show image preview dialog
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(imageUrl),
                    const SizedBox(height: 8),
                    Text(description),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
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
      final snapshot = await _firestore.collection('photos').get();
      final markers = snapshot.docs.map((doc) {
        final data = doc.data();
        final location = data['location'];
        final imageUrl = data['url'] as String;
        final description = data['description'] as String? ?? "No description";

        return Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(location['lat'], location['lng']),
          infoWindow: InfoWindow(
            title: data['userName'],
            snippet: 'Uploaded Photo',
            onTap: () {
              // Show image preview dialog
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.network(imageUrl),
                        const SizedBox(height: 8),
                        Text(description),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      }).toSet();

      setState(() {
        _markers = markers;
      });
    } catch (e) {
      print("Error loading markers: $e");
    }
  }


  // Bottom Navigation Content
  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const Center(child: Text('Welcome to SnapMap!'));
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
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('photos').snapshots(),
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

            // Extract metadata
            final imageUrl = photo['url'] as String;
            final description = photo['description'] as String? ?? "No description provided";
            final locationData = photo['location'] as Map<String, dynamic>? ?? {};
            final location = LatLng(
              locationData['lat'] as double? ?? 0.0,
              locationData['lng'] as double? ?? 0.0,
            );

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailPage(
                      imageUrl: imageUrl,
                      description: description,
                      location: location,
                    ),
                  ),
                );
              },
              child: Image.network(imageUrl, fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SnapMap'),
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
