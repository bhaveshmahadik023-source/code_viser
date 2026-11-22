/// A ready-made program the user can load with one tap.
class CodeExample {
  const CodeExample(this.title, this.code);

  final String title;
  final String code;
}

/// Small examples. The user can edit them or paste any other code.
const List<CodeExample> kCodeExamples = [
  CodeExample('Bubble Sort', '''arr = [5, 3, 8, 1, 2]
n = len(arr)

for i in range(n - 1):
    for j in range(n - i - 1):
        if arr[j] > arr[j + 1]:
            arr[j], arr[j + 1] = arr[j + 1], arr[j]

print(arr)
'''),
  CodeExample('Binary Search', '''def binary_search(arr, target):
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
  CodeExample('Two Pointers (reverse)', '''arr = [1, 2, 3, 4, 5]
left = 0
right = len(arr) - 1

while left < right:
    arr[left], arr[right] = arr[right], arr[left]
    left += 1
    right -= 1

print(arr)
'''),
  CodeExample('Factorial (recursion)', '''def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

print(factorial(5))
'''),
  CodeExample('Sum of digits', '''num = 1234
total = 0

while num > 0:
    digit = num % 10
    total = total + digit
    num = num // 10

print(total)
'''),
  CodeExample('Character frequency', '''text = "banana"
count = {}
for ch in text:
    if ch in count:
        count[ch] += 1
    else:
        count[ch] = 1
print(count)
'''),
  CodeExample('if / elif / else', '''age = 20
if age >= 18:
    print(f"Age {age}: adult")
elif age >= 13:
    print(f"Age {age}: teenager")
else:
    print(f"Age {age}: child")
print("Done")
'''),
  CodeExample('Class and objects', '''class Dog:
    def __init__(self, name):
        self.name = name
        self.tricks = 0

    def learn(self):
        self.tricks += 1

    def __str__(self):
        return f"{self.name} knows {self.tricks} tricks"

d = Dog("Rex")
d.learn()
d.learn()
print(d)
'''),
  CodeExample('try / except', '''def divide(a, b):
    try:
        return a / b
    except ZeroDivisionError:
        print("Cannot divide by zero")
        return 0
    finally:
        print("done")

print(divide(10, 2))
print(divide(5, 0))
'''),
  CodeExample('List comprehension', '''nums = [1, 2, 3, 4, 5, 6]
squares = [n * n for n in nums if n % 2 == 0]
print(squares)
'''),
];