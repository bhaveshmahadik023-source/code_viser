import '../models/learning_models.dart';
import 'learning_catalog.dart';

/// A lesson together with the course, level and module it belongs to.
class LessonRef {
  const LessonRef({
    required this.course,
    required this.level,
    required this.module,
    required this.lesson,
  });

  final LearningCourse course;
  final LearningLevel level;
  final LearningModule module;
  final LearningLesson lesson;
}

/// Finds a lesson by its id (for example "python_for").
/// Returns null if the id does not exist.
LessonRef? findLesson(String lessonId) {
  for (final course in learningCourses) {
    for (final level in course.levels) {
      for (final module in level.modules) {
        for (final lesson in module.lessons) {
          if (lesson.id == lessonId) {
            return LessonRef(
              course: course,
              level: level,
              module: module,
              lesson: lesson,
            );
          }
        }
      }
    }
  }
  return null;
}