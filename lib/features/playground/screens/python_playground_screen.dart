
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/python.dart';
import 'package:http/http.dart' as http;

class PythonPlaygroundScreen extends StatefulWidget {
  const PythonPlaygroundScreen({super.key});

  @override
  State<PythonPlaygroundScreen> createState() =>
      _PythonPlaygroundScreenState();
}

class _PythonPlaygroundScreenState
    extends State<PythonPlaygroundScreen> {
  static const String _initialCode = '''# Welcome to Python Playground

numbers = [5, 2, 8, 1]

for i in range(len(numbers)):
    for j in range(len(numbers) - 1 - i):
        if numbers[j] > numbers[j + 1]:
            numbers[j], numbers[j + 1] = numbers[j + 1], numbers[j]

print("Sorted array:", numbers)
''';

  // Local development API address for Flutter Web in Edge.
  static const String _apiUrl =
      'http://127.0.0.1:8000/execute';

  late final CodeController _codeController;

  bool _isRunning = false;
  bool? _executionSuccess;

  String _output =
      'Your program output will appear here.';

  String _executionStatus = 'Ready to execute';

  double? _executionTime;

  @override
  void initState() {
    super.initState();

    _codeController = CodeController(
      text: _initialCode,
      language: python,
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // Reset editor and execution result.
  void _resetCode() {
    setState(() {
      _codeController.text = _initialCode;

      _output = 'Your program output will appear here.';
      _executionStatus = 'Ready to execute';

      _executionSuccess = null;
      _executionTime = null;
    });
  }

  // Send Python code to FastAPI and execute it through Docker.
  Future<void> _runCode() async {
    if (_isRunning) return;

    final code = _codeController.text;

    if (code.trim().isEmpty) {
      setState(() {
        _output = 'Please write some Python code first.';
        _executionStatus = 'Empty code';
        _executionSuccess = false;
        _executionTime = null;
      });

      return;
    }

    setState(() {
      _isRunning = true;

      _executionStatus = 'Executing Python code...';
      _executionSuccess = null;

      _output = '';
      _executionTime = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'code': code,
              'timeout': 5,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      final dynamic decodedResponse =
          jsonDecode(response.body);

      if (decodedResponse is! Map<String, dynamic>) {
        throw Exception('Invalid response received from backend.');
      }

      if (response.statusCode != 200) {
        throw Exception(
          decodedResponse['detail'] ??
              'Server error: ${response.statusCode}',
        );
      }

      final bool success =
          decodedResponse['success'] == true;

      final String resultOutput =
          (decodedResponse['output'] ?? '').toString();

      final String resultError =
          (decodedResponse['error'] ?? '').toString();

      final double? executionTime =
          (decodedResponse['execution_time'] as num?)
              ?.toDouble();

      if (!mounted) return;

      setState(() {
        _executionSuccess = success;

        _output = success
            ? (resultOutput.isEmpty
                ? 'Program executed successfully. No output.'
                : resultOutput)
            : (resultError.isEmpty
                ? 'Python execution failed.'
                : resultError);

        _executionTime = executionTime;

        _executionStatus = success
            ? 'Execution completed'
            : 'Execution failed';
      });
    } on http.ClientException catch (e) {
      if (!mounted) return;

      setState(() {
        _executionSuccess = false;
        _executionStatus = 'Connection error';
        _output = 'Could not connect to Python backend.\n\n$e';
      });
    } on FormatException catch (e) {
      if (!mounted) return;

      setState(() {
        _executionSuccess = false;
        _executionStatus = 'Invalid server response';
        _output = e.toString();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _executionSuccess = false;
        _executionStatus = 'Execution error';
        _output = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded),
            SizedBox(width: 10),
            Text('Python Playground'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reset code',
            onPressed: _isRunning ? null : _resetCode,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 850;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1250,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 20),

                      if (isWide)
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _buildEditor(theme),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 4,
                              child: _buildOutputPanel(theme),
                            ),
                          ],
                        )
                      else ...[
                        _buildEditor(theme),
                        const SizedBox(height: 18),
                        _buildOutputPanel(theme),
                      ],

                      const SizedBox(height: 20),

                      _buildComingNext(theme),
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

  Widget _buildHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WRITE. RUN. VISUALIZE.',
            style: TextStyle(
              color: Color(0xFF67E8F9),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Bring your Python code to life.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Write your own program and explore how it works, '
            'one execution step at a time.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF343843),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editor toolbar.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF22252D),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.circle,
                  color: Color(0xFF67E8F9),
                  size: 11,
                ),
                SizedBox(width: 9),
                Text(
                  'main.py',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                Text(
                  'PYTHON 3',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          // Editable Python code.
          CodeTheme(
            data: CodeThemeData(
              styles: monokaiSublimeTheme,
            ),
            child: SizedBox(
              height: 410,
              child: CodeField(
                controller: _codeController,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.65,
                ),
                background: const Color(0xFF17191F),
                cursorColor: const Color(0xFF67E8F9),
                gutterStyle: const GutterStyle(
                  textStyle: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                expands: false,
              ),
            ),
          ),

          // Editor footer.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF22252D),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.code_rounded,
                  color: Color(0xFF67E8F9),
                  size: 16,
                ),
                const SizedBox(width: 7),
                const Text(
                  'Editable source code',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_codeController.text.split('\n').length} lines',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Run and reset controls.
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isRunning ? null : _runCode,
                    icon: _isRunning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF111827),
                            ),
                          )
                        : const Icon(
                            Icons.play_arrow_rounded,
                          ),
                    label: Text(
                      _isRunning ? 'Running...' : 'Run Code',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF67E8F9),
                      foregroundColor: const Color(0xFF111827),
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Reset code',
                  onPressed: _isRunning ? null : _resetCode,
                  icon: const Icon(
                    Icons.restart_alt_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputPanel(ThemeData theme) {
    final Color outputColor =
        _executionSuccess == null
            ? theme.colorScheme.onSurfaceVariant
            : _executionSuccess!
                ? Colors.green
                : Colors.redAccent;

    return Container(
      width: double.infinity,
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
          Row(
            children: [
              const Icon(
                Icons.terminal_rounded,
                size: 20,
              ),
              const SizedBox(width: 9),
              Text(
                'Execution Output',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              minHeight: 145,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF111827)
                  : const Color(0xFFE9EDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _executionSuccess == false
                      ? 'ERROR'
                      : 'OUTPUT',
                  style: TextStyle(
                    color: outputColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _isRunning
                      ? 'Running your Python code...'
                      : _output,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Icon(
                _isRunning
                    ? Icons.hourglass_top_rounded
                    : _executionSuccess == null
                        ? Icons.info_outline_rounded
                        : _executionSuccess!
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                size: 18,
                color: outputColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _executionStatus,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: outputColor,
                  ),
                ),
              ),
            ],
          ),

          if (_executionTime != null) ...[
            const SizedBox(height: 8),
            Text(
              'Execution time: '
              '${_executionTime!.toStringAsFixed(4)} seconds',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComingNext(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(
              alpha: 0.7,
            ),
            theme.colorScheme.secondaryContainer.withValues(
              alpha: 0.5,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coming to your Playground',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _featureRow(
            Icons.animation_rounded,
            'Live algorithm animations',
          ),
          _featureRow(
            Icons.data_object_rounded,
            'Real-time variable inspector',
          ),
          _featureRow(
            Icons.bug_report_outlined,
            'Execution errors and debugging',
          ),
          _featureRow(
            Icons.translate_rounded,
            'English, Hindi and Marathi explanations',
          ),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title),
          ),
        ],
      ),
    );
  }
}
