
import 'package:flutter/material.dart';

import '../data/learning_catalog.dart';
import '../models/learning_models.dart';

class LearningPathScreen extends StatefulWidget {
  const LearningPathScreen({super.key});

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  bool _guidedLearning = true;

  LearningLevelType _selectedLevel = LearningLevelType.beginner;

  final LearningCourse _pythonCourse = pythonCourse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Learning Paths',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeroSection(context, isDark),
                const SizedBox(height: 28),

                _buildSectionHeading(
                  'Choose Your Learning Experience',
                  'Learn step by step or explore topics freely.',
                ),
                const SizedBox(height: 14),

                _buildLearningModeSelector(context),
                const SizedBox(height: 28),

                _buildSectionHeading(
                  'Programming Languages',
                  'Choose a language to begin your journey.',
                ),
                const SizedBox(height: 14),

                _buildLanguageCards(context),
                const SizedBox(height: 28),

                _buildSectionHeading(
                  'Python Learning Levels',
                  'Your complete journey from beginner to advanced.',
                ),
                const SizedBox(height: 14),

                _buildCourseSummary(context),
                const SizedBox(height: 16),

                ..._pythonCourse.levels.map(
                  (level) => _buildLevelCard(context, level),
                ),

                const SizedBox(height: 30),

                Center(
                  child: Text(
                    'Learn • Visualize • Practice • Master',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF101D3A),
                  Color(0xFF172554),
                  Color(0xFF312E81),
                ]
              : const [
                  Color(0xFFE0F2FE),
                  Color(0xFFDBEAFE),
                  Color(0xFFEDE9FE),
                ],
        ),
        border: Border.all(
          color: Colors.cyan.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'YOUR PROGRAMMING JOURNEY',
                  style: TextStyle(
                    color: Color(0xFF22D3EE),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFF67E8F9),
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Learn Programming.\nSee How Code Works.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF172554),
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Explore complete programming courses, understand '
            'concepts visually, and experience real animated code execution.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark
                  ? Colors.white70
                  : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Icon(
                Icons.play_circle_fill,
                color: Color(0xFF22D3EE),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Your journey starts with Python',
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF172554),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title, String subtitle) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLearningModeSelector(BuildContext context) {
   
    return Row(
      children: [
        Expanded(
          child: _buildModeCard(
            context: context,
            title: 'Guided Learning',
            subtitle: 'Follow a structured course',
            icon: Icons.route_rounded,
            selected: _guidedLearning,
            onTap: () {
              setState(() {
                _guidedLearning = true;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildModeCard(
            context: context,
            title: 'Free Exploration',
            subtitle: 'Choose any topic',
            icon: Icons.explore_rounded,
            selected: !_guidedLearning,
            onTap: () {
              setState(() {
                _guidedLearning = false;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 27,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (selected)
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Selected',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cardWidth = isWide
            ? (constraints.maxWidth - 24) / 3
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildLanguageCard(
                context,
                name: 'Python',
                description: 'Start learning',
                icon: Icons.code_rounded,
                available: true,
                color: const Color(0xFF3776AB),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildLanguageCard(
                context,
                name: 'Java',
                description: 'Coming Soon',
                icon: Icons.coffee_rounded,
                available: false,
                color: const Color(0xFFE76F00),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildLanguageCard(
                context,
                name: 'C / C++',
                description: 'Coming Soon',
                icon: Icons.memory_rounded,
                available: false,
                color: const Color(0xFF6475D9),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildLanguageCard(
                context,
                name: 'JavaScript',
                description: 'Coming Soon',
                icon: Icons.javascript_rounded,
                available: false,
                color: const Color(0xFFF0C419),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageCard(
    BuildContext context, {
    required String name,
    required String description,
    required IconData icon,
    required bool available,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: available
              ? color.withValues(alpha: 0.6)
              : theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 25,
                ),
              ),
              const Spacer(),
              if (available)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 19,
                )
              else
                Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: available
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseSummary(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.terminal_rounded,
                color: Color(0xFF22B8CF),
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _pythonCourse.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Chip(
                label: Text('Available'),
                avatar: Icon(
                  Icons.check_circle,
                  size: 15,
                  color: Colors.green,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _pythonCourse.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildStat(
                context,
                Icons.layers_outlined,
                '${_pythonCourse.totalModules}',
                'Modules',
              ),
              const SizedBox(width: 25),
              _buildStat(
                context,
                Icons.menu_book_outlined,
                '${_pythonCourse.totalLessons}',
                'Lessons',
              ),
              const SizedBox(width: 25),
              _buildStat(
                context,
                Icons.signal_cellular_alt,
                '${_pythonCourse.levels.length}',
                'Levels',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelCard(
    BuildContext context,
    LearningLevel level,
  ) {
    final theme = Theme.of(context);
    final isSelected = _selectedLevel == level.type;

    final levelColor = switch (level.type) {
      LearningLevelType.beginner => const Color(0xFF16A34A),
      LearningLevelType.intermediate => const Color(0xFF0EA5E9),
      LearningLevelType.advanced => const Color(0xFF8B5CF6),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? levelColor.withValues(alpha: 0.8)
              : theme.dividerColor.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: theme.copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: isSelected,
          onExpansionChanged: (expanded) {
            if (expanded) {
              setState(() {
                _selectedLevel = level.type;
              });
            }
          },
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.school_outlined,
              color: levelColor,
            ),
          ),
          title: Text(
            level.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '${level.modules.length} Modules • ${level.totalLessons} Lessons',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                level.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...level.modules.map(
              (module) => _buildModuleTile(context, module),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleTile(
    BuildContext context,
    LearningModule module,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        leading: const Icon(
          Icons.folder_open_rounded,
          color: Color(0xFF22B8CF),
        ),
        title: Text(
          module.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${module.totalLessons} Lessons',
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              module.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...module.lessons.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final lesson = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: theme.colorScheme.primary
                          .withValues(alpha: 0.12),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${lesson.durationMinutes} min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
