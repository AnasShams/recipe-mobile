import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditRecipePage extends StatefulWidget {
  @override
  _EditRecipePageState createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _ingredientsController;
  late TextEditingController _stepsController;
  late TextEditingController _imageUrlController;
  late TextEditingController _categoryController;
  bool _isPublic = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _ingredientsController = TextEditingController();
    _stepsController = TextEditingController();
    _imageUrlController = TextEditingController();
    _categoryController = TextEditingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recipe = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _titleController.text = recipe['title'] ?? '';
      _ingredientsController.text = recipe['ingredients'] ?? '';
      _stepsController.text = recipe['steps'] ?? '';
      _imageUrlController.text = recipe['image_url'] ?? '';
      _categoryController.text = recipe['category'] ?? '';
      setState(() {
        _isPublic = recipe['is_public'] ?? true;
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    _imageUrlController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _updateRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final recipe = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      
      await Supabase.instance.client
          .from('recipes')
          .update({
            'title': _titleController.text,
            'ingredients': _ingredientsController.text,
            'steps': _stepsController.text,
            'image_url': _imageUrlController.text,
            'category': _categoryController.text,
            'is_public': _isPublic,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', recipe['id']);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating recipe: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Recipe'),
        actions: [
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _updateRecipe,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter a title' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlController,
              decoration: InputDecoration(
                labelText: 'Image URL',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _ingredientsController,
              decoration: InputDecoration(
                labelText: 'Ingredients',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter ingredients' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _stepsController,
              decoration: InputDecoration(
                labelText: 'Steps',
                border: OutlineInputBorder(),
              ),
              maxLines: 8,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter steps' : null,
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Public Recipe'),
              subtitle: Text(
                'Make this recipe visible to everyone',
              ),
              value: _isPublic,
              onChanged: (bool value) {
                setState(() => _isPublic = value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
