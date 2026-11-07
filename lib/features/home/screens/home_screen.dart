
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/routes/app_routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Arrays',
      'description': 'Learn array operations',
      'icon': Icons.view_array_rounded,
      'color': Colors.blue,
    },
    {
      'name': 'Searching',
      'description': 'Find elements efficiently',
      'icon': Icons.search_rounded,
      'color': Colors.green,
    },
    {
      'name': 'Sorting',
      'description': 'Understand sorting algorithms',
      'icon': Icons.swap_vert_rounded,
      'color': Colors.orange,
    },
    {
      'name': 'Linked Lists',
      'description': 'Explore connected nodes',
      'icon': Icons.link_rounded,
      'color': Colors.purple,
    },
    {
      'name': 'Trees',
      'description': 'Visualize tree structures',
      'icon': Icons.account_tree_rounded,
      'color': Colors.teal,
    },
    {
      'name': 'Graphs',
      'description': 'Explore graph algorithms',
      'icon': Icons.hub_rounded,
      'color': Colors.pink,
    },
  ];

  List<Map<String, dynamic>> get _filteredCategories {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      return _categories;
    }

    return _categories.where((category) {
      return category['name']
              .toString()
              .toLowerCase()
              .contains(query) ||
          category['description']
              .toString()
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Navigate to Learning Paths.
  void _openLearningPaths() {
    context.push(AppRoutes.learningPath);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = _filteredCategories;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_graph_rounded),
            const SizedBox(width: 10),
            Text(l10n.homeTitle),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: l10n.settings,
            onPressed: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 18,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome heading
                      Text(
                        'Welcome to Code Visualizer 👋',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Learn programming by watching code come alive.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Learning Progress Dashboard
                      _buildProgressDashboard(theme),

                      const SizedBox(height: 24),

                      // Dark gradient hero section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF111827),
                              Color(0xFF312E81),
                              Color(0xFF164E63),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: isWide
                            ? Row(
                                children: [
                                  Expanded(
                                    child: _buildHeroContent(),
                                  ),
                                  const SizedBox(width: 20),
                                  const Icon(
                                    Icons.code_rounded,
                                    color: Colors.white,
                                    size: 110,
                                  ),
                                ],
                              )
                            : _buildHeroContent(),
                      ),

                      const SizedBox(height: 28),

                      // Search bar
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search algorithms or categories...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Categories heading
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Explore Categories',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${categories.length} categories',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Category cards
                      if (categories.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Text(
                              'No matching categories found.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categories.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWide ? 3 : 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            mainAxisExtent: 145,
                          ),
                          itemBuilder: (context, index) {
                            final category = categories[index];

                            return _buildCategoryCard(
                              category,
                              theme,
                              isDark,
                            );
                          },
                        ),

                      const SizedBox(height: 30),

                      // Featured algorithm
                      Text(
                        'Featured Algorithm',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.swap_vert_rounded,
                                color: Colors.orange,
                                size: 34,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bubble Sort',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Understand sorting through animation.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Beginner • Sorting',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _openLearningPaths,
                              tooltip: 'Explore Learning Paths',
                              icon: const Icon(
                                Icons.play_circle_fill_rounded,
                                size: 34,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      Center(
                        child: Text(
                          'Learn • Visualize • Master',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Learning Progress Dashboard
  Widget _buildProgressDashboard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Learning Progress',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildProgressCard(
                theme: theme,
                icon: Icons.code_rounded,
                title: '0',
                subtitle: 'Algorithms Completed',
                color: Colors.blue,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: _buildProgressCard(
                theme: theme,
                icon: Icons.local_fire_department_rounded,
                title: '0',
                subtitle: 'Day Learning Streak',
                color: Colors.orange,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall Progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '0 / 50',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: const LinearProgressIndicator(
                  value: 0,
                  minHeight: 9,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Start learning to build your progress!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Individual progress cards
  Widget _buildProgressCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // Hero section content
  Widget _buildHeroContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MAKE CODE VISIBLE',
          style: TextStyle(
            color: Color(0xFF67E8F9),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'See how your code works!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Experience algorithms with interactive animations, '
          'step-by-step execution and visual explanations.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.6,
          ),
        ),

        const SizedBox(height: 20),
FilledButton.icon(
  onPressed: () {
    context.push(AppRoutes.pythonPlayground);
  },
  icon: const Icon(Icons.play_arrow_rounded),
  label: const Text('Start Visualizing'),
  style: FilledButton.styleFrom(
    backgroundColor: const Color(0xFF67E8F9),
    foregroundColor: const Color(0xFF111827),
  ),
),
      ],
    );
  }

  // Category cards
  Widget _buildCategoryCard(
    Map<String, dynamic> category,
    ThemeData theme,
    bool isDark,
  ) {
    final Color color = category['color'] as Color;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openLearningPaths,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category['icon'] as IconData,
                color: color,
                size: 25,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              category['name'].toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              category['description'].toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
