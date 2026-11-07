
import '../models/learning_models.dart';

const LearningCourse pythonCourse = LearningCourse(
  id: 'python',
  title: 'Python Programming',
  description:
      'Learn Python from your first line of code to advanced programming and problem-solving.',
  language: 'Python',
  languageCode: 'python',
  levels: [
    // ---------------- BEGINNER ----------------
    LearningLevel(
      type: LearningLevelType.beginner,
      title: 'Beginner',
      description:
          'Start programming from zero and understand the fundamentals.',
      modules: [
        LearningModule(
          id: 'python_intro',
          title: 'Introduction to Python',
          description: 'Understand programming and get started with Python.',
          lessons: [
            LearningLesson(
              id: 'python_what_is_programming',
              title: 'What is Programming?',
              description: 'Understand what programming means in everyday life.',
              durationMinutes: 8,
            ),
          LearningLesson(
          id: 'python_intro_lesson',
          title: 'Introduction to Python',
          description: 'Learn what Python is and where it is used.',
          durationMinutes: 8,
        ),
            LearningLesson(
              id: 'python_setup',
              title: 'Python Installation and Setup',
              description: 'Understand the Python development environment.',
              durationMinutes: 10,
            ),
            LearningLesson(
              id: 'python_first_program',
              title: 'Your First Python Program',
              description: 'Write and understand your first print statement.',
              durationMinutes: 10,
            ),
          ],
        ),
        LearningModule(
          id: 'python_variables',
          title: 'Variables and Data Types',
          description: 'Learn how programs store and use information.',
          lessons: [
          LearningLesson(
          id: 'python_variables_lesson',
          title: 'Variables',
          description: 'Understand variables using simple real-life examples.',
          durationMinutes: 10,
        ),
            LearningLesson(
              id: 'python_numbers',
              title: 'Numeric Data Types',
              description: 'Learn integers, floats and complex numbers.',
              durationMinutes: 10,
            ),
            LearningLesson(
              id: 'python_strings',
              title: 'Strings',
              description: 'Understand and work with text data.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_boolean',
              title: 'Boolean Data Type',
              description: 'Understand True and False values.',
              durationMinutes: 8,
            ),
            LearningLesson(
              id: 'python_type_conversion',
              title: 'Type Conversion',
              description: 'Convert values from one data type to another.',
              durationMinutes: 10,
            ),
          ],
        ),
        LearningModule(
          id: 'python_operators',
          title: 'Operators and Expressions',
          description: 'Perform calculations and comparisons.',
          lessons: [
            LearningLesson(
              id: 'python_arithmetic',
              title: 'Arithmetic Operators',
              description: 'Perform addition, subtraction, multiplication and division.',
              durationMinutes: 10,
            ),
            LearningLesson(
              id: 'python_comparison',
              title: 'Comparison Operators',
              description: 'Compare values using comparison operators.',
              durationMinutes: 10,
            ),
            LearningLesson(
              id: 'python_logical',
              title: 'Logical Operators',
              description: 'Combine conditions using and, or and not.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_assignment',
              title: 'Assignment Operators',
              description: 'Understand how assignment operators update variables.',
              durationMinutes: 8,
            ),
          ],
        ),
        LearningModule(
          id: 'python_conditions',
          title: 'Conditional Statements',
          description: 'Make decisions in your programs.',
          lessons: [
            LearningLesson(
              id: 'python_if',
              title: 'If Statement',
              description: 'Execute code when a condition is true.',
              durationMinutes: 10,
            ),
            LearningLesson(
              id: 'python_if_else',
              title: 'If-Else Statement',
              description: 'Choose between two possible execution paths.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_elif',
              title: 'If-Elif-Else',
              description: 'Handle multiple conditions.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_nested_if',
              title: 'Nested If Statements',
              description: 'Understand conditions inside other conditions.',
              durationMinutes: 12,
            ),
          ],
        ),
        LearningModule(
          id: 'python_loops',
          title: 'Loops',
          description: 'Repeat instructions and understand iterations.',
          lessons: [
            LearningLesson(
              id: 'python_for',
              title: 'For Loop',
              description: 'Repeat code using a for loop.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_while',
              title: 'While Loop',
              description: 'Repeat code while a condition remains true.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_nested_loops',
              title: 'Nested Loops',
              description: 'Understand loops inside other loops.',
              durationMinutes: 15,
            ),
            LearningLesson(
              id: 'python_break_continue',
              title: 'Break and Continue',
              description: 'Control how loops execute.',
              durationMinutes: 12,
            ),
          ],
        ),
        LearningModule(
          id: 'python_functions',
          title: 'Functions',
          description: 'Organize reusable blocks of code.',
          lessons: [
            LearningLesson(
              id: 'python_function_intro',
              title: 'Introduction to Functions',
              description: 'Understand why functions are useful.',
              durationMinutes: 10,
            ),
            LearningLesson(
              id: 'python_parameters',
              title: 'Parameters and Arguments',
              description: 'Pass information into functions.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_return',
              title: 'Return Statement',
              description: 'Return results from functions.',
              durationMinutes: 10,
            ),
          ],
        ),
      ],
    ),

    // ---------------- INTERMEDIATE ----------------
    LearningLevel(
      type: LearningLevelType.intermediate,
      title: 'Intermediate',
      description:
          'Work with collections, reusable code and object-oriented programming.',
      modules: [
        LearningModule(
          id: 'python_collections',
          title: 'Python Collections',
          description: 'Store and organize multiple values.',
          lessons: [
            LearningLesson(
              id: 'python_lists',
              title: 'Lists',
              description: 'Create, access and modify lists.',
              durationMinutes: 15,
            ),
            LearningLesson(
              id: 'python_tuples',
              title: 'Tuples',
              description: 'Understand ordered immutable collections.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_sets',
              title: 'Sets',
              description: 'Store unique values and perform set operations.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_dictionaries',
              title: 'Dictionaries',
              description: 'Work with key-value pairs.',
              durationMinutes: 15,
            ),
          ],
        ),
        LearningModule(
          id: 'python_strings_advanced',
          title: 'String Handling',
          description: 'Explore useful string operations and techniques.',
          lessons: [
            LearningLesson(
              id: 'python_string_methods',
              title: 'String Methods',
              description: 'Use built-in methods to manipulate strings.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_string_slicing',
              title: 'String Slicing',
              description: 'Extract parts of a string.',
              durationMinutes: 10,
            ),
            LearningLesson(
              id: 'python_string_formatting',
              title: 'String Formatting',
              description: 'Format output using modern Python techniques.',
              durationMinutes: 10,
            ),
          ],
        ),
        LearningModule(
          id: 'python_oop',
          title: 'Object-Oriented Programming',
          description: 'Understand how Python organizes objects and classes.',
          lessons: [
            LearningLesson(
              id: 'python_classes',
              title: 'Classes and Objects',
              description: 'Create classes and understand objects.',
              durationMinutes: 15,
            ),
            LearningLesson(
              id: 'python_constructor',
              title: 'Constructors',
              description: 'Initialize objects using __init__.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_inheritance',
              title: 'Inheritance',
              description: 'Reuse behavior through inheritance.',
              durationMinutes: 15,
            ),
            LearningLesson(
              id: 'python_polymorphism',
              title: 'Polymorphism',
              description: 'Understand different forms of behavior.',
              durationMinutes: 15,
            ),
            LearningLesson(
              id: 'python_encapsulation',
              title: 'Encapsulation',
              description: 'Understand access and data organization.',
              durationMinutes: 12,
            ),
          ],
        ),
        LearningModule(
          id: 'python_exceptions_files',
          title: 'Exceptions and File Handling',
          description: 'Handle errors and work with files.',
          lessons: [
            LearningLesson(
              id: 'python_exceptions',
              title: 'Exception Handling',
              description: 'Handle runtime errors using try and except.',
              durationMinutes: 15,
            ),
            LearningLesson(
              id: 'python_finally',
              title: 'Finally and Else',
              description: 'Understand the complete exception-handling flow.',
              durationMinutes: 12,
            ),
            LearningLesson(
              id: 'python_files',
              title: 'File Handling',
              description: 'Read from and write to files.',
              durationMinutes: 15,
            ),
            LearningLesson(
              id: 'python_modules',
              title: 'Modules and Packages',
              description: 'Organize code using modules and packages.',
              durationMinutes: 12,
            ),
          ],
        ),
      ],
    ),

    // ---------------- ADVANCED ----------------
    LearningLevel(
      type: LearningLevelType.advanced,
      title: 'Advanced',
      description:
          'Explore advanced Python concepts and professional problem-solving.',
      modules: [
        LearningModule(
          id: 'python_recursion',
          title: 'Recursion',
          description: 'Solve problems by breaking them into smaller problems.',
          lessons: [
            LearningLesson(
              id: 'python_recursion_intro',
              title: 'Introduction to Recursion',
              description: 'Understand recursive function calls.',
              durationMinutes: 15,
            ),
            LearningLesson(
              id: 'python_recursion_stack',
              title: 'Call Stack',
              description: 'Visualize how recursive calls use the stack.',
              durationMinutes: 15,
            ),
          ],
        ),
        LearningModule(
          id: 'python_dsa',
          title: 'Data Structures and Algorithms',
          description: 'Learn core data structures and algorithmic techniques.',
          lessons: [
            LearningLesson(
              id: 'python_searching',
              title: 'Searching Algorithms',
              description: 'Understand linear search and binary search.',
              durationMinutes: 20,
            ),
            LearningLesson(
              id: 'python_sorting',
              title: 'Sorting Algorithms',
              description: 'Understand bubble, selection and insertion sort.',
              durationMinutes: 20,
            ),
            LearningLesson(
              id: 'python_stacks_queues',
              title: 'Stacks and Queues',
              description: 'Understand linear data structures.',
              durationMinutes: 18,
            ),
            LearningLesson(
              id: 'python_linked_lists',
              title: 'Linked Lists',
              description: 'Understand connected nodes and pointers.',
              durationMinutes: 18,
            ),
            LearningLesson(
              id: 'python_trees_graphs',
              title: 'Trees and Graphs',
              description: 'Explore hierarchical and network structures.',
              durationMinutes: 20,
            ),
          ],
        ),
        LearningModule(
          id: 'python_problem_solving',
          title: 'Problem-Solving Techniques',
          description: 'Develop efficient approaches to coding problems.',
          lessons: [
            LearningLesson(
              id: 'python_two_pointers',
              title: 'Two Pointer Technique',
              description: 'Solve array and string problems using two pointers.',
              durationMinutes: 18,
            ),
            LearningLesson(
              id: 'python_sliding_window',
              title: 'Sliding Window',
              description: 'Efficiently process continuous ranges of data.',
              durationMinutes: 18,
            ),
            LearningLesson(
              id: 'python_complexity',
              title: 'Time and Space Complexity',
              description: 'Analyze algorithm efficiency.',
              durationMinutes: 20,
            ),
          ],
        ),
        LearningModule(
          id: 'python_professional',
          title: 'Professional Python',
          description: 'Explore features used in real-world Python development.',
          lessons: [
            LearningLesson(
              id: 'python_generators',
              title: 'Generators and Iterators',
              description: 'Understand lazy iteration and yield.',
              durationMinutes: 15,
            ),
            LearningLesson(
              id: 'python_decorators',
              title: 'Decorators',
              description: 'Understand how decorators extend functions.',
              durationMinutes: 18,
            ),
            LearningLesson(
              id: 'python_context_managers',
              title: 'Context Managers',
              description: 'Manage resources using with statements.',
              durationMinutes: 15,
            ),
            LearningLesson(
              id: 'python_async',
              title: 'Asynchronous Programming',
              description: 'Understand async and await.',
              durationMinutes: 20,
            ),
          ],
        ),
      ],
    ),
  ],
);

const List<LearningCourse> learningCourses = [
  pythonCourse,
];

LearningCourse? getCourseById(String courseId) {
  for (final course in learningCourses) {
    if (course.id == courseId) {
      return course;
    }
  }

  return null;
}
