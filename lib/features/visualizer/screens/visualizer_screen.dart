import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../learning/data/lesson_lookup.dart';
import '../engine/code_examples.dart';
import '../engine/lesson_examples.dart';
import '../engine/py_tracer.dart';
import '../engine/trace_models.dart';
import '../providers/trace_playback_provider.dart';
import '../widgets/array_strip.dart';
import '../widgets/call_stack_view.dart';
import '../widgets/code_view.dart';
import '../widgets/decision_card.dart';
import '../widgets/dict_view.dart';
import '../widgets/matrix_view.dart';
import '../widgets/output_console.dart';
import '../widgets/player_controls.dart';
import '../widgets/step_card.dart';
import '../widgets/variables_view.dart';

/// Main screen.
///
/// Free mode ([lessonId] is null):
///   the user pastes any code and taps "Visualize".
/// Lesson mode ([lessonId] is set):
///   the code of the lesson is loaded and animated right away.
///   The user can still tap "Edit code" and change it.
class VisualizerScreen extends ConsumerStatefulWidget {
  const VisualizerScreen({super.key, this.lessonId});

  /// Id of a lesson from the learning catalog, for example "python_for".
  final String? lessonId;

  @override
  ConsumerState<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends ConsumerState<VisualizerScreen> {
  late final TextEditingController _editor;

  // Values for input(), one per line.
  final TextEditingController _inputBox = TextEditingController();

  // Result of the last run. null = we are in the editor.
  TraceResult? _result;

  // The code that was visualized (shown in the code view).
  String _shownCode = '';

  // Error found before the run could start (for example a syntax error).
  TraceError? _editorError;

  // Lesson data (null in free mode).
  LessonExample? get _lessonExample => lessonExampleFor(widget.lessonId);

  LessonRef? get _lessonInfo =>
      widget.lessonId == null ? null : findLesson(widget.lessonId!);

  // Programs shown as chips. Lesson programs or the general examples.
  List<CodeExample> get _examples => _lessonExample?.codes ?? kCodeExamples;

  @override
  void initState() {
    super.initState();
    _editor = TextEditingController(text: _examples.first.code);

    // In lesson mode, start the animation right away.
    if (_lessonExample != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _visualize();
      });
    }
  }

  @override
  void dispose() {
    _editor.dispose();
    _inputBox.dispose();
    super.dispose();
  }

  // Runs the code and opens the animation view.
  void _visualize() {
    final code = _editor.text;

    if (code.trim().isEmpty) {
      setState(() {
        _editorError =
            const TraceError(null, 'Please type or paste some code first.');
      });
      return;
    }

    final result = PyTracer(code, inputs: _inputLines()).run();

    // Nothing to show: the code has an error before the first step.
    if (result.steps.isEmpty) {
      setState(() {
        _result = null;
        _editorError =
            result.error ?? const TraceError(null, 'Nothing to visualize.');
      });
      return;
    }

    ref.read(tracePlaybackProvider.notifier).load(result.steps);
    setState(() {
      _result = result;
      _shownCode = code;
      _editorError = null;
    });
  }

  // The lines typed in the Input box (used by input()).
  List<String> _inputLines() {
    final text = _inputBox.text;
    if (text.trim().isEmpty) return const <String>[];
    return text.split('\n');
  }

  // Puts an example in the editor. If [run] is true, it starts at once.
  void _loadExample(CodeExample example, {required bool run}) {
    _editor.text = example.code;
    if (run) {
      _visualize();
    } else {
      setState(() => _editorError = null);
    }
  }

  void _backToEditor() {
    ref.read(tracePlaybackProvider.notifier).pause();
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the player state alive while this screen is open.
    // Without this, the steps are deleted before the player can show them.
    ref.watch(tracePlaybackProvider);

    final running = _result != null;
    final info = _lessonInfo;

    return Scaffold(
      appBar: AppBar(
        title: Text(info?.lesson.title ?? 'Code Visualizer'),
        actions: [
          if (running)
            TextButton.icon(
              onPressed: _backToEditor,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit code'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: running ? _buildPlayer(context) : _buildEditor(context),
      bottomNavigationBar: running ? const PlayerControls() : null,
    );
  }

  // ------------------------- shared small parts -------------------------

  // Card with the lesson goal and "what to watch".
  Widget _lessonCard({required bool expanded}) {
    final info = _lessonInfo;
    final example = _lessonExample;
    if (info == null || example == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    Widget line(IconData icon, String label, String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: text),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          initiallyExpanded: expanded,
          leading: const Icon(Icons.school_outlined),
          title: Text(
            info.lesson.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(info.module.title),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(info.lesson.description),
            ),
            line(Icons.flag_outlined, 'Goal', example.goal),
            line(Icons.visibility_outlined, 'Watch for', example.watch),
          ],
        ),
      ),
    );
  }

  // Chips to switch between the programs of a lesson (player view).
  Widget _variantChips() {
    final example = _lessonExample;
    if (example == null || example.codes.length < 2) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in example.codes)
            ChoiceChip(
              label: Text(c.title),
              selected: _shownCode == c.code,
              onSelected: (_) => _loadExample(c, run: true),
            ),
        ],
      ),
    );
  }

  // ------------------------------- editor -------------------------------

  Widget _buildEditor(BuildContext context) {
    final theme = Theme.of(context);
    final error = _editorError;
    final inLesson = _lessonExample != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _lessonCard(expanded: true),

              Text(
                inLesson
                    ? 'Change the code if you like'
                    : 'Paste your code and watch it run',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Every line runs step by step with animation. '
                'Variables, arrays and output change in front of you.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Language switch (Java will come in the next phase).
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'python', label: Text('Python')),
                    ButtonSegment(
                      value: 'java',
                      label: Text('Java (coming soon)'),
                      enabled: false,
                    ),
                  ],
                  selected: const {'python'},
                  onSelectionChanged: (_) {},
                ),
              ),
              const SizedBox(height: 14),

              // Example programs.
              Text(
                inLesson ? 'Programs for this lesson' : 'Try an example',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final example in _examples)
                    ActionChip(
                      label: Text(example.title),
                      onPressed: () => _loadExample(example, run: false),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Code input.
              TextField(
                controller: _editor,
                minLines: 14,
                maxLines: 26,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type or paste your Python code here...',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              // Values for input(). One value per line.
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.keyboard_rounded),
                  title: const Text('Input for input() (optional)'),
                  subtitle: const Text('Type one value per line'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    TextField(
                      controller: _inputBox,
                      minLines: 2,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: 'For example:\nAsha\n20',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              // Error message (syntax error, unsupported feature ...).
              if (error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(error: error),
              ],

              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _visualize,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Visualize'),
                ),
              ),

              const SizedBox(height: 16),
              const _SupportedInfo(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------- player -------------------------------

  Widget _buildPlayer(BuildContext context) {
    final playback = ref.watch(tracePlaybackProvider);

    if (playback.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final step = playback.current;
    final previous = playback.previous;
    final runError = _result?.error;

    // Lists and matrices are drawn as pictures, other variables as chips.
    final arrays = step.vars.values.where((v) => v.type == VarType.list);
    final matrices = step.vars.values.where((v) => v.type == VarType.matrix);
    final dicts = step.vars.values.where((v) => v.type == VarType.dict);
    final objects = step.vars.values.where((v) => v.type == VarType.object);

    final visuals = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _lessonCard(expanded: false),
        _variantChips(),

        // Show the error when the last step is reached.
        if (runError != null && playback.isLast) ...[
          _ErrorBanner(error: runError),
          const SizedBox(height: 12),
        ],

        StepCard(step: step, total: playback.steps.length),
        const SizedBox(height: 12),

        // How an if / while line decided (True or False and the next way).
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: step.decision == null
              ? const SizedBox.shrink(key: ValueKey('no-decision'))
              : Padding(
                  key: ValueKey('decision-${step.number}'),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecisionCard(decision: step.decision!),
                ),
        ),

        for (final a in arrays) ...[
          ArrayStrip(
            snapshot: a,
            marks: step.marks[a.name] ?? const <int, MarkKind>{},
            pointers: step.pointers[a.name] ?? const <int, String>{},
          ),
          const SizedBox(height: 12),
        ],

        for (final m in matrices) ...[
          MatrixView(snapshot: m),
          const SizedBox(height: 12),
        ],

        for (final d in dicts) ...[
          DictView(
            snapshot: d,
            marks: step.dictMarks[d.name] ?? const <String, MarkKind>{},
            previous: previous?.vars[d.name],
          ),
          const SizedBox(height: 12),
        ],

        for (final o in objects) ...[
          DictView(snapshot: o, previous: previous?.vars[o.name]),
          const SizedBox(height: 12),
        ],

        Text('Variables', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        VariablesView(current: step.vars, previous: previous?.vars),
        const SizedBox(height: 14),

        // Call stack is useful only when functions are running.
        if (step.callStack.length > 1) ...[
          Text('Call stack', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          CallStackView(stack: step.callStack),
          const SizedBox(height: 14),
        ],

        Text('Output', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        OutputConsole(lines: step.output),
      ],
    );

    final code = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Python', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: 'Copy code',
              icon: const Icon(Icons.copy),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: _shownCode)),
            ),
          ],
        ),
        CodeView(
          code: _shownCode,
          activeLine: step.line,
          skippedLines: step.skippedLines,
          decisionResult: step.condition,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide screen: code on the right. Small screen: code below.
        final isWide = constraints.maxWidth >= 900;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: visuals),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: code),
                  ],
                )
              : Column(
                  children: [
                    code,
                    const SizedBox(height: 16),
                    visuals,
                  ],
                ),
        );
      },
    );
  }
}

/// Red box that shows an error message.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final TraceError error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final where = error.line == null ? '' : 'Line ${error.line}: ';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$where${error.message}',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Short list of what the visualizer understands now.
class _SupportedInfo extends StatelessWidget {
  const _SupportedInfo();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ExpansionTile(
        title: Text('What is supported right now?'),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supported: numbers, text, f-strings, True/False, lists, tuples, '
            'sets, dictionaries, 2D lists, slicing, list / set / dict '
            'comprehensions, arithmetic and bit operators, if / elif / else, '
            'for / while (with else), break, continue, functions with default '
            'values, lambda, recursion, classes with methods, inheritance and '
            'super(), try / except / finally, raise, assert, del, global, '
            'import math, and input().',
          ),
          SizedBox(height: 8),
          Text(
            'Built-in functions: print (sep, end), len, range, int, float, '
            'str, bool, abs, min, max, sum, round, pow, divmod, sorted, '
            'reversed, enumerate, zip, map, filter, any, all, list, tuple, '
            'set, dict, chr, ord, type, isinstance, bin, hex, oct, format.',
          ),
          SizedBox(height: 8),
          Text(
            'Not supported yet: other modules (random, os ...), file '
            'handling and with blocks, multiple inheritance, decorators other '
            'than staticmethod / classmethod / property, *args, **kwargs, '
            'generators (yield), async, and Java code.',
          ),
          SizedBox(height: 8),
          Text(
            'Limits: 1500 steps, 60 nested calls, and whole numbers up to '
            '9007199254740991. These limits stop infinite loops.',
          ),
        ],
      ),
    );
  }
}