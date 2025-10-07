import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Map<String, dynamic>>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = fetchPublicRecipes();
  }

  Future<List<Map<String, dynamic>>> fetchPublicRecipes() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      
      final response = await Supabase.instance.client
          .from('recipes')
          .select('''
            id,
            user_id,
            title,
            image_url,
            ingredients,
            steps,
            is_public,
            created_at,
            updated_at,
            category,
            category_id,
            profiles (
              username,
              avatar_url
            )
          ''')
          .eq('is_public', true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching recipes: $error');
      return [];
    }
  }

  Future<void> _refreshRecipes() async {
    setState(() {
      _recipesFuture = fetchPublicRecipes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discover Recipes'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshRecipes,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _recipesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error loading recipes'),
                        SizedBox(height: 8),
                        TextButton(
                          onPressed: _refreshRecipes,
                          child: Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final recipes = snapshot.data ?? [];

            if (recipes.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No recipes available',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Pull down to refresh',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              itemCount: recipes.length,
              padding: EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                final profile = recipe['profiles'] as Map<String, dynamic>?;
                
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/recipe_detail',
                      arguments: recipe,
                    ).then((_) => _refreshRecipes()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (recipe['image_url'] != null)
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              image: DecorationImage(
                                image: NetworkImage(recipe['image_url']),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ListTile(
                          title: Text(
                            recipe['title'] ?? 'Untitled Recipe',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (recipe['category'] != null) ...[
                                SizedBox(height: 4),
                                Chip(
                                  label: Text(recipe['category']),
                                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                ),
                              ],
                              SizedBox(height: 4),
                              if (profile != null)
                                Row(
                                  children: [
                                    if (profile['avatar_url'] != null)
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundImage: NetworkImage(profile['avatar_url']),
                                      ),
                                    SizedBox(width: 8),
                                    Text('by ${profile['username'] ?? 'Unknown'}'),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
