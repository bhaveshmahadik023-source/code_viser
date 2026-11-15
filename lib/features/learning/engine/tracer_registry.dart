import 'bubble_sort_tracer.dart';
import 'execution_step.dart';

/// Maps an algorithm id (used in the route) to its tracer.
/// To add a new algorithm, add one line here.
final Map<String, AlgorithmTracer Function()> tracerRegistry = {
  'bubble-sort': BubbleSortTracer.new,
};