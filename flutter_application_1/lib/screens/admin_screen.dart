import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart'; // Keep import for context if needed elsewhere, but not for drawer navigation
import '../services/storage_service.dart'; // Import StorageService

class AdminScreen extends StatefulWidget {
  // Keep as StatefulWidget for `mounted` check
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final StorageService _storageService =
      StorageService(); // Instantiate StorageService
  List<dynamic> _users = [];
  List<dynamic> _images = [];
  List<dynamic> _allImages = []; // Add a list to store all images
  dynamic _selectedUser; // To hold the selected user for filtering
  bool _isLoadingData = true;
  String? _errorLoadingData;

  @override
  void initState() {
    super.initState();
    _loadData(); // Load users and images on initialization
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
      _errorLoadingData = null;
    });
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) {
        throw Exception('Authentication token not available.');
      }

      // Fetch users
      final fetchedUsers = await _storageService.getAllUsers(token);
      // Add an option to view all users
      final allUsersOption = {'_id': null, 'username': 'All Users'};
      _users = [
        allUsersOption,
        ...fetchedUsers
      ]; // Add 'All Users' option at the beginning

      // Fetch all images initially and store in _allImages
      _allImages =
          await _storageService.getAdminImages(token); // Store all images
      _images = List.from(_allImages); // Initialize _images with all images
      _selectedUser = allUsersOption; // Set default selected user to All Users
    } catch (e) {
      _errorLoadingData = e.toString();
      print('Error loading admin data: $_errorLoadingData');
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _filterImagesByUser(dynamic user) async {
    setState(() {
      _selectedUser = user;
      _isLoadingData = true;
      _errorLoadingData = null;
    });
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) {
        throw Exception('Authentication token not available.');
      }

      final userId = user != null ? user['_id'] : null;
      // Call backend API to get filtered images
      final fetchedImages =
          await _storageService.getAdminImages(token, userId: userId);
      _images =
          fetchedImages; // Update _images with the result from the backend
    } catch (e) {
      _errorLoadingData = e.toString();
      print('Error filtering admin images: $_errorLoadingData');
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      drawer: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final user = auth.user;
          if (user == null) {
            return const Drawer(
              child: Center(child: Text('No user data available')),
            );
          }

          return Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(user['username'] ?? ''),
                  accountEmail: Text(user['email'] ?? ''),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      (user['username'] ?? '')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                  ),
                ),
                // Add other admin specific drawer items here (e.g., Manage Users, Settings)
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () async {
                    await context.read<AuthProvider>().logout();
                    if (mounted) {
                      // Navigate first, then close drawer if needed (though pushReplacement handles this)
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (Route<dynamic> route) =>
                            false, // Remove all previous routes
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _errorLoadingData != null
              ? Center(child: Text('Error: $_errorLoadingData'))
              : Column(
                  children: [
                    // User Filter Dropdown
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: DropdownButton<dynamic>(
                        isExpanded: true,
                        hint: const Text('Select User to Filter'),
                        value:
                            _selectedUser, // Should be the selected user object or null for All Users
                        items: _users.map((user) {
                          return DropdownMenuItem<dynamic>(
                            value: user,
                            child: Text(user['username'] ?? 'Unknown User'),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != _selectedUser) {
                            _filterImagesByUser(
                                newValue); // Filter when user changes
                          }
                        },
                      ),
                    ),
                    // Display Images
                    Expanded(
                      child: _images.isEmpty
                          ? const Center(child: Text('No images found.'))
                          : GridView.builder(
                              padding: const EdgeInsets.all(16.0),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, // Adjust as needed
                                crossAxisSpacing: 8.0,
                                mainAxisSpacing: 8.0,
                                childAspectRatio: 1.0, // Adjust as needed
                              ),
                              itemCount: _images.length,
                              itemBuilder: (context, index) {
                                final image = _images[index];
                                final imageUrl = image[
                                    'supabaseUrl']; // Assuming the URL is stored here
                                final uploaderUsername = image['userId']
                                        ?['username'] ??
                                    'Unknown'; // Get uploader username

                                if (imageUrl == null || !image['isUploaded']) {
                                  // Handle images that are not yet uploaded or have no URL
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                        child: Text(
                                            'Image not available\n($uploaderUsername)')),
                                  );
                                }

                                return GridTile(
                                  header: GridTileBar(
                                    backgroundColor: Colors.black45,
                                    title: Text('by $uploaderUsername',
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error,
                                            stackTrace) =>
                                        const Center(child: Icon(Icons.error)),
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
