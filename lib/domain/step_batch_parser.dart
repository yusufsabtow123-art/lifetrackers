class StepBatchItem {
  const StepBatchItem({required this.title, this.isFinalResult = false});

  final String title;
  final bool isFinalResult;
}

class StepBatchPreview {
  const StepBatchPreview({required this.items});

  final List<StepBatchItem> items;

  bool get canAdd => items.length >= 2;

  List<String> get titles =>
      items.map((item) => item.title).toList(growable: false);
}

class StepBatchParser {
  const StepBatchParser();

  StepBatchPreview parse(String input) {
    final normalized = input.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return const StepBatchPreview(items: []);
    }

    final resultSeparator = RegExp(r'\s=\s').firstMatch(normalized);
    final stepText = resultSeparator == null
        ? normalized
        : normalized.substring(0, resultSeparator.start);
    final result = resultSeparator == null
        ? ''
        : normalized.substring(resultSeparator.end).trim();
    final steps = stepText
        .split(RegExp(r'(?:\s+\+\s+|\n+)'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((title) => StepBatchItem(title: title))
        .toList();
    if (result.isNotEmpty) {
      steps.add(StepBatchItem(title: result, isFinalResult: true));
    }
    return StepBatchPreview(items: List.unmodifiable(steps));
  }
}
