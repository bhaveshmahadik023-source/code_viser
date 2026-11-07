
enum LearningLevelType {
  beginner,
  intermediate,
  advanced,
}

class LearningLesson {
  final String id;
  final String title;
  final String description;
  final int durationMinutes;

  const LearningLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
  });
}

class LearningModule {
  final String id;
  final String title;
  final String description;
  final List<LearningLesson> lessons;

  const LearningModule({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
  });

  int get totalLessons => lessons.length;
}

class LearningLevel {
  final LearningLevelType type;
  final String title;
  final String description;
  final List<LearningModule> modules;

  const LearningLevel({
    required this.type,
    required this.title,
    required this.description,
    required this.modules,
  });

  int get totalLessons {
    return modules.fold(
      0,
      (total, module) => total + module.totalLessons,
    );
  }
}

class LearningCourse {
  final String id;
  final String title;
  final String description;
  final String language;
  final String languageCode;
  final List<LearningLevel> levels;

  const LearningCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.language,
    required this.languageCode,
    required this.levels,
  });

  int get totalModules {
    return levels.fold(
      0,
      (total, level) => total + level.modules.length,
    );
  }

  int get totalLessons {
    return levels.fold(
      0,
      (total, level) => total + level.totalLessons,
    );
  }
}
