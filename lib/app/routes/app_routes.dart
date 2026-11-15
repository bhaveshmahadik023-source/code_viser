class AppRoutes {
  // Main routes
  static const String pythonPlayground = '/python-playground';
  static const String splash = '/';
  static const String home = '/home';
  static const String settings = '/settings';

  // Authentication routes
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  // Learning routes
  static const String learningPath = '/learning-paths';

  // Code Visualizer.
  // Open a lesson with: '/visualizer?lesson=python_for'
  // Open the free code editor with: '/visualizer'
  static const String visualizer = '/visualizer';
}