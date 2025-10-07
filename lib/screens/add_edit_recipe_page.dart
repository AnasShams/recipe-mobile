import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/image_helper.dart';

class AddEditRecipePage extends StatefulWidget {
  final Map<String, dynamic>? recipe;
  
  const AddEditRecipePage({Key? key, this.recipe}) : super(key: key);
  
  @override
  _AddEditRecipePageState createState() => _AddEditRecipePageState();
}

class _AddEditRecipePageState extends State<AddEditRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _stepsController = TextEditingController();
  
  bool _isSaving = false;
  String? _selectedImageUrl;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _titleController.text = widget.recipe!['title'] ?? '';
      _ingredientsController.text = widget.recipe!['ingredients'] ?? '';
      _stepsController.text = widget.recipe!['steps'] ?? '';
      _existingImageUrl = widget.recipe!['image_url'];
    }
  }

  Future<void> _pickImage() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final imageUrl = await ImageHelper.pickAndUploadImage(
      context: context,
      bucket: 'recipe-images',
      folder: 'recipes',
      userId: user.id,
    );

    if (imageUrl != null && mounted) {
      setState(() {
        _selectedImageUrl = imageUrl;
        _existingImageUrl = null; // Clear existing image when new one is selected
      });
    }
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final recipeData = {
        'title': _titleController.text.trim(),
        'ingredients': _ingredientsController.text.trim(),
        'steps': _stepsController.text.trim(),
        'user_id': user.id,
        if (_selectedImageUrl != null) 'image_url': _selectedImageUrl
        else if (_existingImageUrl != null) 'image_url': _existingImageUrl,
      };

      if (widget.recipe != null) {
        await Supabase.instance.client
            .from('recipes')
            .update(recipeData)
            .eq('id', widget.recipe!['id']);
      } else {
        await Supabase.instance.client
            .from('recipes')
            .insert(recipeData);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: SelectableText(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Add Recipe' : 'Edit Recipe'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _selectedImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error),
                        ),
                      )
                    : _existingImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _existingImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.error),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add recipe image',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 16),
            // Title field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Ingredients field
            TextFormField(
              controller: _ingredientsController,
              decoration: const InputDecoration(
                labelText: 'Ingredients',
                border: OutlineInputBorder(),
                helperText: 'Enter each ingredient on a new line',
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter ingredients';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Steps field
            TextFormField(
              controller: _stepsController,
              decoration: const InputDecoration(
                labelText: 'Steps',
                border: OutlineInputBorder(),
                helperText: 'Enter each step on a new line',
              ),
              maxLines: 8,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter steps';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Save button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveRecipe,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.recipe == null ? 'Create Recipe' : 'Update Recipe',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    super.dispose();
  }
}
