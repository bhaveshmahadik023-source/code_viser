import 'py_error.dart';

/// Kinds of tokens.
enum TokType { number, string, name, op, newline, indent, dedent, eof }

/// One small piece of the source code.
class Token {
  const Token(this.type, this.text, this.line, this.start, this.end,
      [this.prefix = '']);

  final TokType type;
  final String text; // for strings this is the text without quotes
  final int line; // 1-based
  final int start; // offset in the source
  final int end; // offset in the source (exclusive)
  final String prefix; // string prefix in lower case: "", "f", "r", "rf" ...
}

const _threeCharOps = {'**=', '//=', '<<=', '>>='};
const _twoCharOps = {
  '==', '!=', '<=', '>=', '+=', '-=', '*=', '/=', '%=', '//', '**', '->', //
  '<<', '>>', '|=', '&=', '^=',
};
const _oneCharOps = '+-*/%<>=()[]{},:.;|&^~@';

const _stringPrefixes = {'f', 'r', 'b', 'u', 'fr', 'rf', 'br', 'rb'};

bool _isDigit(String c) {
  final u = c.codeUnitAt(0);
  return u >= 48 && u <= 57;
}

bool _isIdStart(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95;
}

bool _isIdPart(String c) => _isIdStart(c) || _isDigit(c);

/// Splits the source code into tokens.
/// It also creates indent / dedent tokens, like Python does.
List<Token> tokenize(String src, {int firstLine = 1}) {
  final tokens = <Token>[];
  final indents = <int>[0];
  final n = src.length;
  var i = 0;
  var line = firstLine;
  var depth = 0; // depth of ( [ { brackets
  var atLineStart = true;

  // Reads a string. [i] must point to the opening quote.
  void scanString(int start, String prefix) {
    final q = src[i];
    final triple = src.startsWith(q * 3, i);
    final isRaw = prefix.contains('r');
    final isF = prefix.contains('f');
    i += triple ? 3 : 1;
    final buf = StringBuffer();
    final startLine = line;
    var closed = false;
    while (i < n) {
      final ch = src[i];
      if (ch == '\\' && i + 1 < n) {
        final nx = src[i + 1];
        if (isRaw || isF) {
          // Keep the text as it is. The parser handles f-string escapes.
          buf.write(ch);
          buf.write(nx);
        } else if (nx == '\n') {
          // A backslash at the end of a line joins the lines.
        } else if (nx == 'n') {
          buf.write('\n');
        } else if (nx == 't') {
          buf.write('\t');
        } else if (nx == 'r') {
          buf.write('\r');
        } else if (nx == '0') {
          buf.write('\u0000');
        } else if (nx == '\\' || nx == "'" || nx == '"') {
          buf.write(nx);
        } else {
          buf.write(ch);
          buf.write(nx);
        }
        if (nx == '\n') line++;
        i += 2;
        continue;
      }
      if (triple) {
        if (src.startsWith(q * 3, i)) {
          closed = true;
          i += 3;
          break;
        }
        if (ch == '\n') line++;
        buf.write(ch);
        i++;
        continue;
      }
      if (ch == q) {
        closed = true;
        i++;
        break;
      }
      if (ch == '\n') break;
      buf.write(ch);
      i++;
    }
    if (!closed) {
      throw PyError(startLine, 'String is not closed');
    }
    tokens.add(
        Token(TokType.string, buf.toString(), startLine, start, i, prefix));
  }

  while (i < n) {
    // ---- Indentation at the start of a line ----
    if (atLineStart && depth == 0) {
      var col = 0;
      var j = i;
      while (j < n && (src[j] == ' ' || src[j] == '\t')) {
        col += src[j] == '\t' ? 4 : 1;
        j++;
      }
      if (j >= n) {
        i = j;
        break;
      }
      // Blank line or comment-only line: skip it.
      if (src[j] == '\n' || src[j] == '\r' || src[j] == '#') {
        while (j < n && src[j] != '\n') {
          j++;
        }
        if (j < n) {
          j++;
          line++;
        }
        i = j;
        continue;
      }
      if (col > indents.last) {
        indents.add(col);
        tokens.add(Token(TokType.indent, '', line, j, j));
      } else {
        while (col < indents.last) {
          indents.removeLast();
          tokens.add(Token(TokType.dedent, '', line, j, j));
        }
        if (col != indents.last) {
          throw PyError(line, 'Indentation does not match any outer level');
        }
      }
      i = j;
      atLineStart = false;
    }

    final c = src[i];

    if (c == '\r') {
      i++;
      continue;
    }
    if (c == '\n') {
      if (depth == 0) {
        tokens.add(Token(TokType.newline, '', line, i, i));
        atLineStart = true;
      }
      i++;
      line++;
      continue;
    }
    if (c == ' ' || c == '\t') {
      i++;
      continue;
    }
    if (c == '#') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    // Line continuation with a backslash.
    if (c == '\\' && i + 1 < n && (src[i + 1] == '\n' || src[i + 1] == '\r')) {
      i++;
      if (i < n && src[i] == '\r') i++;
      if (i < n && src[i] == '\n') i++;
      line++;
      continue;
    }

    // ---- Numbers ----
    if (_isDigit(c) || (c == '.' && i + 1 < n && _isDigit(src[i + 1]))) {
      final start = i;
      while (i < n && (_isDigit(src[i]) || src[i] == '_')) {
        i++;
      }
      if (i < n && src[i] == '.') {
        i++;
        while (i < n && _isDigit(src[i])) {
          i++;
        }
      }
      if (i < n && (src[i] == 'e' || src[i] == 'E')) {
        var k = i + 1;
        if (k < n && (src[k] == '+' || src[k] == '-')) k++;
        if (k < n && _isDigit(src[k])) {
          i = k;
          while (i < n && _isDigit(src[i])) {
            i++;
          }
        }
      }
      tokens.add(Token(TokType.number,
          src.substring(start, i).replaceAll('_', ''), line, start, i));
      continue;
    }

    // ---- Names, keywords and string prefixes ----
    if (_isIdStart(c)) {
      final start = i;
      while (i < n && _isIdPart(src[i])) {
        i++;
      }
      final word = src.substring(start, i);
      if (i < n &&
          (src[i] == '"' || src[i] == "'") &&
          _stringPrefixes.contains(word.toLowerCase())) {
        final prefix = word.toLowerCase();
        if (prefix.contains('b')) {
          throw PyError(line, 'Bytes strings are not supported yet');
        }
        scanString(start, prefix);
        continue;
      }
      tokens.add(Token(TokType.name, word, line, start, i));
      continue;
    }

    // ---- Strings ----
    if (c == '"' || c == "'") {
      scanString(i, '');
      continue;
    }

    // ---- Operators and brackets ----
    String? op;
    if (i + 3 <= n && _threeCharOps.contains(src.substring(i, i + 3))) {
      op = src.substring(i, i + 3);
    } else if (i + 2 <= n && _twoCharOps.contains(src.substring(i, i + 2))) {
      op = src.substring(i, i + 2);
    } else if (_oneCharOps.contains(c)) {
      op = c;
    }
    if (op == null) {
      throw PyError(line, "Unexpected character '$c'");
    }
    if (op == '(' || op == '[' || op == '{') depth++;
    if ((op == ')' || op == ']' || op == '}') && depth > 0) depth--;
    tokens.add(Token(TokType.op, op, line, i, i + op.length));
    i += op.length;
  }

  // Make sure the last line ends with a newline token.
  if (tokens.isNotEmpty && tokens.last.type != TokType.newline) {
    tokens.add(Token(TokType.newline, '', line, n, n));
  }
  // Close all open blocks.
  while (indents.length > 1) {
    indents.removeLast();
    tokens.add(Token(TokType.dedent, '', line, n, n));
  }
  tokens.add(Token(TokType.eof, '', line, n, n));
  return tokens;
}