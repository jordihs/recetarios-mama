/// Mutable row-major representation of a GFM table.
///
/// [cells][row][col] — row 0 is the header row; row 1+ are body rows.
class TableData {
  TableData({required this.cells});

  final List<List<String>> cells;

  int get rowCount => cells.length;
  int get colCount => cells.isEmpty ? 0 : cells[0].length;

  static TableData blank() => TableData(cells: [
        ['', ''],
        ['', ''],
      ]);

  factory TableData.fromMarkdown(String markdown) {
    final rows = <List<String>>[];
    bool seenDelimiter = false;
    for (final rawLine in markdown.trim().split('\n')) {
      final line = rawLine.trim();
      if (!line.startsWith('|')) continue;
      final parsed = _parseCells(line);
      if (parsed.isEmpty) continue;
      if (!seenDelimiter && _isDelimiter(parsed)) {
        seenDelimiter = true;
        continue;
      }
      rows.add(parsed);
    }
    if (rows.isEmpty || rows[0].isEmpty) return TableData.blank();
    final cols = rows[0].length;
    return TableData(
      cells: rows.map((r) => _padOrTrim(r, cols)).toList(),
    );
  }

  String toMarkdown() {
    if (cells.isEmpty) return '';
    final lines = <String>[];
    lines.add(_rowLine(cells[0]));
    lines.add(_delimiterLine(colCount));
    for (var i = 1; i < cells.length; i++) {
      lines.add(_rowLine(cells[i]));
    }
    return lines.join('\n');
  }

  TableData addRow() => TableData(cells: [
        ...cells.map((r) => [...r]),
        List.filled(colCount, ''),
      ]);

  TableData addColumn() => TableData(
        cells: cells.map((r) => [...r, '']).toList(),
      );

  TableData removeLastRow() {
    if (rowCount <= 1) return this;
    return TableData(
      cells: cells.sublist(0, rowCount - 1).map((r) => [...r]).toList(),
    );
  }

  TableData removeLastColumn() {
    if (colCount <= 1) return this;
    return TableData(
      cells: cells.map((r) => r.sublist(0, colCount - 1)).toList(),
    );
  }

  static List<String> _parseCells(String line) {
    final parts = line.split('|');
    final start = parts.first.trim().isEmpty ? 1 : 0;
    final end = parts.last.trim().isEmpty ? parts.length - 1 : parts.length;
    if (start >= end) return [];
    // Decode <br> back to newlines so the table editor shows multi-line text.
    return parts
        .sublist(start, end)
        .map((s) => s.trim().replaceAll('<br>', '\n'))
        .toList();
  }

  static bool _isDelimiter(List<String> cells) =>
      cells.isNotEmpty &&
      cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c.trim()));

  static List<String> _padOrTrim(List<String> row, int cols) {
    if (row.length == cols) return row;
    if (row.length < cols) {
      return [...row, ...List.filled(cols - row.length, '')];
    }
    return row.sublist(0, cols);
  }

  static String _rowLine(List<String> cells) {
    // GFM table rows cannot contain literal newlines — encode them as <br>
    // so multi-line cell content survives the markdown round-trip.
    return '| ${cells.map((c) {
      final s = c.isEmpty ? ' ' : c;
      return s.replaceAll('\n', '<br>');
    }).join(' | ')} |';
  }

  static String _delimiterLine(int cols) =>
      '| ${List.filled(cols, '---').join(' | ')} |';
}
