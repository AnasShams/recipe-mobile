import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  bool _isPublic = false;
  String? _currentAvatarUrl;
  File? _newAvatarFile;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await fetchProfile();
    if (profile != null && mounted) {
      final user = Supabase.instance.client.auth.currentUser;
      setState(() {
        _fullNameController.text = profile['full_name'] ?? '';
        _usernameController.text = profile['username'] ?? '';
        _emailController.text = profile['email'] ?? user?.email ?? '';
        _currentAvatarUrl = profile['avatar_url'];
        _isPublic = profile['is_public_profile'] ?? false;
      });
    }
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _newAvatarFile = File(image.path);
      });
    }
  }

  Future<String?> _uploadAvatar(String userId) async {
    if (_newAvatarFile == null) return _currentAvatarUrl;
    
    try {
      final bytes = await _newAvatarFile!.readAsBytes();
      final fileExt = _newAvatarFile!.path.split('.').last;
      final fileName = 'avatar.$fileExt';
      final filePath = 'avatars/$userId/$fileName';
      
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(filePath, bytes);
      
      final String publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);
          
      return publicUrl;
    } catch (e) {
      print('Error uploading avatar: $e');
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for username
    final username = _usernameController.text.trim();
    if (username.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Username cannot contain spaces')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Upload new avatar if selected
      final avatarUrl = await _uploadAvatar(user.id);

      // Update profile
      await Supabase.instance.client.from('profiles').update({
        'full_name': _fullNameController.text,
        'username': username, // Use the trimmed username
        'email': _emailController.text,
        'is_public_profile': _isPublic,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _currentAvatarUrl = avatarUrl ?? _currentAvatarUrl;
          _newAvatarFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  // Reset form
                  _loadProfile();
                  _newAvatarFile = null;
                }
                _isEditing = !_isEditing;
              });
            },
          ),
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => _signOut(context),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _newAvatarFile != null
                            ? FileImage(_newAvatarFile!)
                            : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
                                ? NetworkImage(_currentAvatarUrl!) as ImageProvider
                                : null),
                        child: (_newAvatarFile == null && (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty))
                            ? Icon(Icons.person, size: 60)
                            : null,
                      ),
                      if (_isEditing)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                if (_isEditing) ...[
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixText: '@',
                      helperText: 'No spaces allowed',
                      errorMaxLines: 2,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      if (value.contains(' ')) {
                        return 'Username cannot contain spaces';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    readOnly: true, // Email can't be edited here
                    enabled: false, // Disabled to show it's not editable
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Public Profile'),
                    subtitle: Text('Allow others to see your profile and recipes'),
                    value: _isPublic,
                    onChanged: (bool value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ] else ...[
                  Text(
                    _fullNameController.text,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '@${_usernameController.text}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        _emailController.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Chip(
                    label: Text(_isPublic ? 'Public Profile' : 'Private Profile'),
                    avatar: Icon(
                      _isPublic ? Icons.public : Icons.lock,
                      size: 18,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                  SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: Icon(Icons.logout),
                    label: Text('Logout'),
                    onPressed: () => _signOut(context),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
