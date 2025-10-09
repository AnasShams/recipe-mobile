import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe.dart';

class RecipeDetailPage extends StatefulWidget {
  @override
  _RecipeDetailPageState createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  bool _isDeleting = false;
  bool _isSaving = false;
  bool _isSaved = false;
  late Recipe _recipe;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Don't access context here, wait for didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_isInitialized) {
      // Get the recipe from arguments - this is safe to do in didChangeDependencies
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null) {
        _initializeRecipe(args);
      } else {
        // Handle case where no arguments are provided
        _handleError('No recipe data provided');
      }
    }
  }

  void _initializeRecipe(dynamic args) {
    try {
      if (args is Recipe) {
        _recipe = args;
      } else if (args is Map<String, dynamic>) {
        // Handle case where Map is passed (backward compatibility)
        final isUserRecipe = args['isUserRecipe'] ?? false;
        _recipe = Recipe.fromMap(args, isUserRecipe: isUserRecipe);
      } else {
        throw Exception('Invalid arguments type: ${args.runtimeType}');
      }
      
      _isInitialized = true;
      _checkIfSaved();
    } catch (e) {
      _handleError('Error initializing recipe: $e');
    }
  }

  void _handleError(String error) {
    print(error);
    // You might want to navigate back or show an error screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _checkIfSaved() async {
    if (!_isInitialized) return;
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('saved_recipes')
          .select()
          .eq('recipe_id', _recipe.id)
          .eq('user_id', user.id)
          .limit(1);
      
      if (mounted) {
        setState(() {
          _isSaved = response.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking saved status: $e');
    }
  }

  Future<void> _toggleSave() async {
    if (_isSaving || !_isInitialized) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save recipes')),
        );
        return;
      }

      if (_isSaved) {
        // Unsave the recipe
        await Supabase.instance.client
            .from('saved_recipes')
            .delete()
            .eq('recipe_id', _recipe.id)
            .eq('user_id', user.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe removed from saved')),
          );
        }
      } else {
        // Save the recipe
        await Supabase.instance.client
            .from('saved_recipes')
            .insert({
              'recipe_id': _recipe.id,
              'user_id': user.id,
              'saved_at': DateTime.now().toIso8601String(),
            });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe saved successfully')),
          );
        }
      }

      if (mounted) {
        setState(() {
          _isSaved = !_isSaved;
        });
      }
    } catch (e) {
      print('Error toggling save: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving recipe: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteRecipe(BuildContext context) async {
    if (_isDeleting || !_isInitialized) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      if (_recipe.isUserRecipe) {
        // Delete from user_recipes table
        await Supabase.instance.client
            .from('user_recipes')
            .delete()
            .eq('id', _recipe.id);
      } else {
        // For pre-loaded recipes, we might not want to delete them
        // Instead, we can remove them from saved_recipes
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client
              .from('saved_recipes')
              .delete()
              .eq('recipe_id', _recipe.id)
              .eq('user_id', user.id);
        }
      }
      
      // Also remove from saved_recipes
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('saved_recipes')
            .delete()
            .eq('recipe_id', _recipe.id)
            .eq('user_id', user.id);
      }
      
      if (mounted) {
        Navigator.of(context).pop('deleted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe deleted successfully')),
        );
      }
    } catch (e) {
      print('Error deleting recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting recipe: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Recipe Details'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading recipe...'),
            ],
          ),
        ),
      );
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    final isOwner = currentUser?.id == _recipe.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Details'),
        actions: [
          if (!isOwner) 
            IconButton(
              icon: _isSaving
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: _isSaved ? Theme.of(context).colorScheme.primary : null,
                    ),
              tooltip: _isSaved ? 'Unsave Recipe' : 'Save Recipe',
              onPressed: _isSaving ? null : _toggleSave,
            ),
          if (isOwner && _recipe.isUserRecipe) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Recipe',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/edit_recipe',
                  arguments: _recipe,
                ).then((edited) {
                  if (edited == true && mounted) {
                    Navigator.pop(context, true);
                  }
                });
              },
            ),
            IconButton(
              icon: _isDeleting 
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.delete),
              tooltip: 'Delete Recipe',
              onPressed: _isDeleting
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Recipe'),
                          content: const Text('Are you sure you want to delete this recipe?'),
                          actions: [
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(context),
                            ),
                            TextButton(
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteRecipe(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Recipe',
            onPressed: () {
              final textToCopy = '''
${_recipe.title}

Category: ${_recipe.category}

Ingredients:
${_recipe.ingredients}

Steps:
${_recipe.steps}
''';
              Clipboard.setData(ClipboardData(text: textToCopy));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recipe copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_recipe.imageUrl != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(_recipe.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_recipe.isUserRecipe)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'User Recipe',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              _recipe.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            if (_recipe.category.isNotEmpty)
              Chip(
                label: Text(_recipe.category),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              ),
            const SizedBox(height: 16),
            Text(
              'Ingredients',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _recipe.ingredients,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Steps',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _recipe.steps,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}