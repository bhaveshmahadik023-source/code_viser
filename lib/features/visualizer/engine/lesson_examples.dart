import 'code_examples.dart';

/// Python code for one lesson of the course.
/// The key in [kLessonExamples] is the lesson id from learning_catalog.dart.
class LessonExample {
  const LessonExample({
    required this.goal,
    required this.watch,
    required this.codes,
  });

  /// What the student learns in this lesson.
  final String goal;

  /// What to look at in the animation.
  final String watch;

  /// One or more programs. Many programs = the student can switch.
  final List<CodeExample> codes;
}

/// True when the lesson has an animation.
bool hasLessonExample(String lessonId) => kLessonExamples.containsKey(lessonId);

/// Returns the example of a lesson (null if there is none).
LessonExample? lessonExampleFor(String? lessonId) =>
    lessonId == null ? null : kLessonExamples[lessonId];

/// All lesson examples. Only code that the visualizer supports is used here.
const Map<String, LessonExample> kLessonExamples = {
  // ------------------------- Introduction -------------------------
  'python_what_is_programming': LessonExample(
    goal: 'A program is a list of steps that the computer follows in order.',
    watch: 'The highlighted line moves from top to bottom, one step at a time.',
    codes: [
      CodeExample('Making tea', '''# A program is a list of steps
print("Step 1: Boil water")
print("Step 2: Add tea leaves")
print("Step 3: Add milk and sugar")
print("Tea is ready!")
'''),
    ],
  ),
  'python_intro_lesson': LessonExample(
    goal: 'Python code is simple to read. print() shows a message on the screen.',
    watch: 'Each print() adds a new line in the Output box.',
    codes: [
      CodeExample('Hello Python', '''print("Hello, Python!")
print("Python is easy to learn")
print(2 + 3)
'''),
    ],
  ),
  'python_first_program': LessonExample(
    goal: 'Write your first program with print().',
    watch: 'The text appears in the Output box when the line runs.',
    codes: [
      CodeExample('Hello World', '''print("Hello, World!")
'''),
    ],
  ),

  // ------------------------- Variables ----------------------------
  'python_variables_lesson': LessonExample(
    goal: 'A variable is a name that stores a value.',
    watch: 'A new chip appears in Variables when a name is created, '
        'and it lights up when the value changes.',
    codes: [
      CodeExample('Variables', '''name = "Asha"
age = 20
height = 5.4
print(name)
print(age)
age = age + 1
print(age)
'''),
    ],
  ),
  'python_numbers': LessonExample(
    goal: 'Python has whole numbers (int) and decimal numbers (float).',
    watch: 'Notice 7 / 2 gives 3.5 but 7 // 2 gives 3.',
    codes: [
      CodeExample('Numbers', '''count = 10
price = 99.5
total = count * price
print(total)
print(7 / 2)
print(7 // 2)
'''),
    ],
  ),
  'python_strings': LessonExample(
    goal: 'A string is text. Every character has a position (index).',
    watch: 'Index 0 is the first character. -1 is the last character.',
    codes: [
      CodeExample('Strings', '''word = "python"
print(len(word))
print(word[0])
print(word[-1])
print(word.upper())
print(word + " rocks")
'''),
      CodeExample('Loop over a string', '''for ch in "code":
    print(ch)
'''),
    ],
  ),
  'python_boolean': LessonExample(
    goal: 'A boolean is either True or False.',
    watch: 'The if line shows True or False before it decides what to run.',
    codes: [
      CodeExample('Boolean', '''is_raining = True
if is_raining:
    print("Take an umbrella")
else:
    print("Enjoy the sun")
'''),
    ],
  ),
  'python_type_conversion': LessonExample(
    goal: 'Convert a value from one type to another.',
    watch: 'The same value looks different after int(), str() and float().',
    codes: [
      CodeExample('Type conversion', '''text = "42"
number = int(text)
total = number + 8
print(total)
print(str(total) + " apples")
print(float(number))
'''),
    ],
  ),

  // ------------------------- Operators ----------------------------
  'python_arithmetic': LessonExample(
    goal: 'Use +, -, *, /, //, % and ** to calculate.',
    watch: '// gives the whole part, % gives the remainder.',
    codes: [
      CodeExample('Arithmetic', '''a = 17
b = 5
print(a + b)
print(a - b)
print(a * b)
print(a / b)
print(a // b)
print(a % b)
print(a ** 2)
'''),
    ],
  ),
  'python_comparison': LessonExample(
    goal: 'Comparisons give True or False.',
    watch: 'Each print shows the result of one comparison.',
    codes: [
      CodeExample('Comparison', '''a = 10
b = 20
print(a < b)
print(a == b)
print(a != b)
print(a >= 10)
'''),
    ],
  ),
  'python_logical': LessonExample(
    goal: 'and, or and not combine conditions.',
    watch: 'can_enter is True only when both parts are True.',
    codes: [
      CodeExample('and / or / not', '''age = 20
has_id = True
can_enter = age >= 18 and has_id
print(can_enter)
print(not can_enter)
print(age < 18 or has_id)
'''),
    ],
  ),
  'python_assignment': LessonExample(
    goal: 'Assignment operators update a variable in one short line.',
    watch: 'x changes after every line: 10, 15, 12, 24, 6.',
    codes: [
      CodeExample('Assignment operators', '''x = 10
x += 5
x -= 3
x *= 2
x //= 4
print(x)
'''),
    ],
  ),

  // ------------------------- Conditions ---------------------------
  'python_if': LessonExample(
    goal: 'if runs a block only when the condition is True.',
    watch: 'When the condition is False, the indented line is skipped.',
    codes: [
      CodeExample('if', '''marks = 72
if marks >= 40:
    print("Pass")
print("Done")
'''),
    ],
  ),
  'python_if_else': LessonExample(
    goal: 'if-else chooses one of two paths.',
    watch: 'Only one of the two blocks runs.',
    codes: [
      CodeExample('Even or odd', '''num = 7
if num % 2 == 0:
    print("Even")
else:
    print("Odd")
'''),
    ],
  ),
  'python_elif': LessonExample(
    goal: 'elif checks more conditions, one after another.',
    watch: 'Python stops at the first True condition.',
    codes: [
      CodeExample('Grade', '''marks = 72
if marks >= 90:
    print("Grade A")
elif marks >= 75:
    print("Grade B")
elif marks >= 60:
    print("Grade C")
else:
    print("Grade D")
'''),
    ],
  ),
  'python_nested_if': LessonExample(
    goal: 'An if can be placed inside another if.',
    watch: 'The inner if is checked only when the outer condition is True.',
    codes: [
      CodeExample('Ticket check', '''age = 20
has_ticket = True
if age >= 18:
    if has_ticket:
        print("Welcome")
    else:
        print("Please buy a ticket")
else:
    print("Too young")
'''),
    ],
  ),

  // ------------------------- Loops --------------------------------
  'python_for': LessonExample(
    goal: 'A for loop repeats code for every value in a range or list.',
    watch: 'i gets a new value each time, and total grows.',
    codes: [
      CodeExample('Sum 1 to 5', '''total = 0
for i in range(1, 6):
    total += i
print(total)
'''),
      CodeExample('Loop over a list', '''marks = [40, 55, 70]
for m in marks:
    print(m)
'''),
    ],
  ),
  'python_while': LessonExample(
    goal: 'A while loop repeats while the condition is True.',
    watch: 'The condition is checked before every round. It becomes False '
        'when count is 0.',
    codes: [
      CodeExample('Countdown', '''count = 3
while count > 0:
    print(count)
    count -= 1
print("Go!")
'''),
      CodeExample('Sum of digits', '''num = 1234
total = 0
while num > 0:
    digit = num % 10
    total = total + digit
    num = num // 10
print(total)
'''),
    ],
  ),
  'python_nested_loops': LessonExample(
    goal: 'A loop inside a loop. The inner loop runs fully for each outer round.',
    watch: 'j goes 0..i-1 again for every new i.',
    codes: [
      CodeExample('Star triangle', '''for i in range(1, 4):
    row = ""
    for j in range(i):
        row = row + "*"
    print(row)
'''),
    ],
  ),
  'python_break_continue': LessonExample(
    goal: 'continue skips one round. break stops the whole loop.',
    watch: '3 is skipped, and the loop stops when i is 6.',
    codes: [
      CodeExample('break and continue', '''for i in range(1, 8):
    if i == 3:
        continue
    if i == 6:
        break
    print(i)
'''),
    ],
  ),

  // ------------------------- Functions ----------------------------
  'python_function_intro': LessonExample(
    goal: 'A function is a reusable block of code.',
    watch: 'Defining a function does not run it. A call creates a new frame '
        'in the Call stack.',
    codes: [
      CodeExample('First function', '''def say_hi():
    print("Hi!")

say_hi()
say_hi()
'''),
    ],
  ),
  'python_parameters': LessonExample(
    goal: 'Parameters let you send values into a function.',
    watch: 'The new frame has its own variables (a and b).',
    codes: [
      CodeExample('Parameters', '''def add(a, b):
    return a + b

result = add(3, 4)
print(result)
'''),
      CodeExample('Greeting', '''def greet(name):
    print("Hello,", name)

greet("Asha")
greet("Ravi")
'''),
    ],
  ),
  'python_return': LessonExample(
    goal: 'return sends a result back to the caller.',
    watch: 'The returned value goes back to the line that made the call.',
    codes: [
      CodeExample('Return', '''def square(x):
    return x * x

answer = square(5)
print(answer)
'''),
    ],
  ),

  // ------------------------- Collections --------------------------
  'python_lists': LessonExample(
    goal: 'A list stores many values. Use index to read or change them.',
    watch: 'Changed elements turn red. A new element appears at the end '
        'after append.',
    codes: [
      CodeExample('Lists', '''fruits = ["apple", "banana", "cherry"]
fruits.append("mango")
print(fruits[0])
fruits[1] = "kiwi"
removed = fruits.pop()
print(fruits)
print(len(fruits))
'''),
      CodeExample('Numbers list', '''nums = [4, 8, 15]
nums.append(16)
nums[0] = 23
print(nums)
'''),
    ],
  ),
  'python_string_methods': LessonExample(
    goal: 'Strings have methods such as upper(), lower(), strip() and replace().',
    watch: 'A method returns a new string. The original does not change.',
    codes: [
      CodeExample('String methods', '''text = "  Hello Python  "
clean = text.strip()
print(clean)
print(clean.upper())
print(clean.lower())
print(clean.replace("Python", "World"))
'''),
    ],
  ),

  // ------------------------- Recursion ----------------------------
  'python_recursion_intro': LessonExample(
    goal: 'A recursive function calls itself on a smaller problem.',
    watch: 'Calls pile up in the Call stack, then answers come back one by one.',
    codes: [
      CodeExample('Factorial', '''def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

print(factorial(5))
'''),
      CodeExample('Fibonacci', '''def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

print(fib(4))
'''),
    ],
  ),
  'python_recursion_stack': LessonExample(
    goal: 'Every call gets its own frame on the call stack.',
    watch: 'The stack grows to 5 frames and then shrinks again.',
    codes: [
      CodeExample('Sum to n', '''def sum_to(n):
    if n == 0:
        return 0
    return n + sum_to(n - 1)

print(sum_to(4))
'''),
    ],
  ),

  // ------------------------- Data structures ----------------------
  'python_searching': LessonExample(
    goal: 'Linear search checks one by one. Binary search halves the range.',
    watch: 'Binary search shows low, mid and high pointers under the array.',
    codes: [
      CodeExample('Linear search', '''arr = [4, 9, 2, 7, 5]
target = 7
found = -1
for i in range(len(arr)):
    if arr[i] == target:
        found = i
        break
print(found)
'''),
      CodeExample('Binary search', '''def binary_search(arr, target):
    low = 0
    high = len(arr) - 1
    while low <= high:
        mid = (low + high) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            low = mid + 1
        else:
            high = mid - 1
    return -1

nums = [2, 5, 8, 12, 16, 23, 38]
result = binary_search(nums, 23)
print(result)
'''),
    ],
  ),
  'python_sorting': LessonExample(
    goal: 'Sorting puts values in order. Compare the three simple methods.',
    watch: 'Yellow = being compared. Red = changed or swapped.',
    codes: [
      CodeExample('Bubble sort', '''arr = [5, 3, 8, 1, 2]
n = len(arr)

for i in range(n - 1):
    for j in range(n - i - 1):
        if arr[j] > arr[j + 1]:
            arr[j], arr[j + 1] = arr[j + 1], arr[j]

print(arr)
'''),
      CodeExample('Selection sort', '''arr = [64, 25, 12, 22, 11]
n = len(arr)

for i in range(n - 1):
    min_idx = i
    for j in range(i + 1, n):
        if arr[j] < arr[min_idx]:
            min_idx = j
    arr[i], arr[min_idx] = arr[min_idx], arr[i]

print(arr)
'''),
      CodeExample('Insertion sort', '''arr = [5, 2, 4, 1]

for i in range(1, len(arr)):
    key = arr[i]
    j = i - 1
    while j >= 0 and arr[j] > key:
        arr[j + 1] = arr[j]
        j = j - 1
    arr[j + 1] = key

print(arr)
'''),
    ],
  ),
  'python_stacks_queues': LessonExample(
    goal: 'A stack is last-in first-out. A queue is first-in first-out.',
    watch: 'pop() removes from the end. pop(0) removes from the front.',
    codes: [
      CodeExample('Stack', '''stack = []
stack.append(10)
stack.append(20)
stack.append(30)
top = stack.pop()
print(top)
print(stack)
'''),
      CodeExample('Queue', '''queue = [10, 20, 30]
queue.append(40)
first = queue.pop(0)
print(first)
print(queue)
'''),
    ],
  ),

  // ------------------------- Problem solving ----------------------
  'python_two_pointers': LessonExample(
    goal: 'Two pointers walk through the data from both sides.',
    watch: 'The left and right pointers move towards each other.',
    codes: [
      CodeExample('Reverse an array', '''arr = [1, 2, 3, 4, 5]
left = 0
right = len(arr) - 1

while left < right:
    arr[left], arr[right] = arr[right], arr[left]
    left += 1
    right -= 1

print(arr)
'''),
      CodeExample('Pair with target sum', '''arr = [1, 2, 4, 6, 8, 11]
target = 10
left = 0
right = len(arr) - 1

while left < right:
    current = arr[left] + arr[right]
    if current == target:
        print(left, right)
        break
    elif current < target:
        left += 1
    else:
        right -= 1
'''),
    ],
  ),
  'python_sliding_window': LessonExample(
    goal: 'A window of fixed size slides over the array.',
    watch: 'window_sum is updated by adding the new element and removing '
        'the old one.',
    codes: [
      CodeExample('Max sum of size 3', '''arr = [2, 1, 5, 1, 3, 2]
k = 3
window_sum = 0
best = 0
left = 0

for right in range(len(arr)):
    window_sum += arr[right]
    if right - left + 1 == k:
        if window_sum > best:
            best = window_sum
        window_sum -= arr[left]
        left += 1

print(best)
'''),
    ],
  ),
  'python_complexity': LessonExample(
    goal: 'Count how many times the work is done as the input grows.',
    watch: 'One loop does n rounds. Two nested loops do n x n rounds.',
    codes: [
      CodeExample('One loop: O(n)', '''n = 5
count = 0
for i in range(n):
    count += 1
print(count)
'''),
      CodeExample('Nested loops: O(n squared)', '''n = 4
count = 0
for i in range(n):
    for j in range(n):
        count += 1
print(count)
'''),
    ],
  ),
};