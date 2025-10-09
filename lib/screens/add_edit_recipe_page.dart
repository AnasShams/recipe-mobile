import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/image_helper.dart';
import '../models/category.dart';
import '../models/recipe.dart';
import '../services/category_service.dart';

class AddEditRecipePage extends StatefulWidget {
  final Recipe? recipe;
  
  const AddEditRecipePage({Key? key, this.recipe}) : super(key: key);
  
  @override
  _AddEditRecipePageState createState() => _AddEditRecipePageState();
}

class _AddEditRecipePageState extends State<AddEditRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _stepsController = TextEditingController();
  
  final CategoryService _categoryService = CategoryService();
  
  Category? _selectedCategory;
  List<Category> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSaving = false;
  String? _selectedImageUrl;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.recipe != null) {
      _titleController.text = widget.recipe!.title;
      _ingredientsController.text = widget.recipe!.ingredients;
      _stepsController.text = widget.recipe!.steps;
      _existingImageUrl = widget.recipe!.imageUrl;
      // We'll set the category after categories are loaded
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final categories = await _categoryService.fetchCategories();
      
      if (mounted) {
        setState(() {
          _categories = categories;
          
          // Set the selected category if editing an existing recipe
          if (widget.recipe != null && widget.recipe!.category.isNotEmpty) {
            final categoryName = widget.recipe!.category;
            _selectedCategory = _categories.firstWhere(
              (category) => category.name == categoryName,
              orElse: () => _categories.isNotEmpty ? _categories.first : Category(id: 0, name: 'Other'),
            );
          } else if (_categories.isNotEmpty) {
            // Set default category to first one if available
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final imageUrl = await ImageHelper.pickAndUploadImage(
      context: context,
      bucket: 'recipe-images',
      folder: 'user-recipes',
      userId: user.id,
    );

    if (imageUrl != null && mounted) {
      setState(() {
        _selectedImageUrl = imageUrl;
        _existingImageUrl = null;
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
        'ingredients': _ingredientsController.text.split('\n').where((line) => line.trim().isNotEmpty).toList(),
        'steps': _stepsController.text.split('\n').where((line) => line.trim().isNotEmpty).toList(),
        'user_id': user.id,
        'category': _selectedCategory?.name ?? 'Other',
        'category_id': _selectedCategory?.id,
        'updated_at': DateTime.now().toIso8601String(),
        if (_selectedImageUrl != null) 'image_url': _selectedImageUrl
        else if (_existingImageUrl != null) 'image_url': _existingImageUrl,
      };

      if (widget.recipe != null) {
        // Update existing recipe
        await Supabase.instance.client
            .from('user_recipes')
            .update(recipeData)
            .eq('id', widget.recipe!.id);
      } else {
        // Create new recipe
        recipeData['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client
            .from('user_recipes')
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
            content: SelectableText('Failed to save recipe: ${e.toString()}'),
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
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _selectedImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _selectedImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error, size: 48),
                        ),
                      )
                    : _existingImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _existingImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.error, size: 48),
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

            // Category dropdown
            _buildCategoryDropdown(),
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
              onPressed: (_isSaving || _isLoadingCategories) ? null : _saveRecipe,
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

  Widget _buildCategoryDropdown() {
    if (_isLoadingCategories) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(),
          SizedBox(height: 4),
          Text(
            'Loading categories...',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );
    }

    if (_categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No categories available. Using "Other" as default.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return DropdownButtonFormField<Category>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
      ),
      items: _categories.map((category) {
        return DropdownMenuItem<Category>(
          value: category,
          child: Text(category.name),
        );
      }).toList(),
      onChanged: (Category? newValue) {
        setState(() {
          _selectedCategory = newValue;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Please select a category';
        }
        return null;
      },
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