import 'dates.dart';

/// Priority parsed from natural language command tokens.
enum CommandPriority {
  urgent,
  high,
  medium,
  low;

  String get label => switch (this) {
        CommandPriority.urgent => 'Urgent',
        CommandPriority.high => 'High',
        CommandPriority.medium => 'Medium',
        CommandPriority.low => 'Low',
      };

  String get badge => switch (this) {
        CommandPriority.urgent => 'P1',
        CommandPriority.high => 'P2',
        CommandPriority.medium => 'P3',
        CommandPriority.low => 'P4',
      };
}

/// Result of parsing a task creation command from natural language input.
class ParsedTaskCommand {
  const ParsedTaskCommand({
    required this.rawText,
    required this.cleanTitle,
    this.dueDate,
    this.dueString,
    this.category,
    this.tags = const [],
    this.priority = CommandPriority.medium,
  });

  /// The original input text before parsing.
  final String rawText;

  /// The cleaned task title with dates, priority tokens, and tags stripped out.
  final String cleanTitle;

  /// Parsed local calendar due date, or null if no date pattern was matched.
  final DateTime? dueDate;

  /// Human-friendly description of the due date (e.g. "Today", "Tomorrow", "Friday").
  final String? dueString;

  /// Primary category or context tag (e.g. "ios", "work", "finance").
  final String? category;

  /// All tags and context labels extracted from `@tag` or `#tag`.
  final List<String> tags;

  /// Parsed task priority.
  final CommandPriority priority;

  @override
  String toString() =>
      'ParsedTaskCommand(title: "$cleanTitle", dueDate: $dueDate, category: $category, priority: $priority)';
}

/// Natural Language Command Parser for LifeOS.
///
/// Extracts dates, categories, context tags (@tag), hashtags (#tag), and
/// priority flags (!urgent, !high, !p1, etc.) from plain user input.
class CommandParser {
  const CommandParser();

  /// Parses a natural language task command.
  ///
  /// [referenceDate] defaults to today's local date.
  ParsedTaskCommand parseTask(String input, {DateTime? referenceDate}) {
    final ref = referenceDate != null ? calendarDate(referenceDate) : todayLocal();
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return ParsedTaskCommand(
        rawText: input,
        cleanTitle: '',
        priority: CommandPriority.medium,
      );
    }

    var workingText = trimmed;
    DateTime? dueDate;
    String? dueString;
    CommandPriority priority = CommandPriority.medium;
    final tags = <String>[];
    String? primaryCategory;

    // 1. Extract @context or @category tags: e.g. @ios, @work, @personal
    final atTagRegex = RegExp(r'(?:^|\s)@([a-zA-Z0-9_\-\.]+)', caseSensitive: false);
    final atMatches = atTagRegex.allMatches(workingText).toList();
    for (final match in atMatches) {
      final tag = match.group(1)!;
      if (!tags.contains(tag.toLowerCase())) {
        tags.add(tag.toLowerCase());
      }
      primaryCategory ??= tag;
    }
    // Remove @tags from working text
    workingText = workingText.replaceAllMapped(atTagRegex, (m) => ' ').trim();

    // 2. Extract priority markers: !urgent, !high, !med, !low, !p1, !p2, !p3, !p4, #p1, #p2, etc.
    final priorityRegex = RegExp(
      r'(?:^|\s)(!(?:urgent|critical|high|med|medium|low|p[1-4])|#(?:p[1-4]|urgent|high|low))\b',
      caseSensitive: false,
    );
    final priorityMatch = priorityRegex.firstMatch(workingText);
    if (priorityMatch != null) {
      final token = priorityMatch.group(1)!.toLowerCase();
      if (token == '!urgent' || token == '!critical' || token == '!p1' || token == '#p1' || token == '#urgent') {
        priority = CommandPriority.urgent;
      } else if (token == '!high' || token == '!p2' || token == '#p2' || token == '#high') {
        priority = CommandPriority.high;
      } else if (token == '!med' || token == '!medium' || token == '!p3' || token == '#p3') {
        priority = CommandPriority.medium;
      } else if (token == '!low' || token == '!p4' || token == '#p4' || token == '#low') {
        priority = CommandPriority.low;
      }
      workingText = workingText.replaceAll(priorityRegex, ' ').trim();
    }

    // 3. Extract other hashtags (#bug, #feature, etc.)
    final hashTagRegex = RegExp(r'(?:^|\s)#([a-zA-Z0-9_\-\.]+)', caseSensitive: false);
    final hashMatches = hashTagRegex.allMatches(workingText).toList();
    for (final match in hashMatches) {
      final tag = match.group(1)!;
      if (!tags.contains(tag.toLowerCase())) {
        tags.add(tag.toLowerCase());
      }
      primaryCategory ??= tag;
    }
    workingText = workingText.replaceAllMapped(hashTagRegex, (m) => ' ').trim();

    // 4. Extract Due Date expressions
    // A. ISO format: by 2026-09-30 or due:2026-09-30 or due 2026-09-30
    final isoRegex = RegExp(r'\b(?:by\s+|due:?\s*)(\d{4}-\d{2}-\d{2})\b', caseSensitive: false);
    final isoMatch = isoRegex.firstMatch(workingText);
    if (isoMatch != null) {
      final parsed = parseIsoDate(isoMatch.group(1)!);
      if (parsed != null) {
        dueDate = parsed;
        dueString = isoDate(parsed);
        workingText = workingText.replaceRange(isoMatch.start, isoMatch.end, ' ').trim();
      }
    }

    // B. Relative day keywords: today, tomorrow, yesterday, next week
    if (dueDate == null) {
      final relativePatterns = [
        (
          RegExp(r'\b(?:by\s+|due:?\s*)today\b|\bdue:today\b|\bby:today\b|(?:\bby\s+today\b)|(?<=\s)today$', caseSensitive: false),
          ref,
          'Today'
        ),
        (
          RegExp(r'\b(?:by\s+|due:?\s*)tomorrow\b|\bdue:tomorrow\b|\bby:tomorrow\b|(?:\bby\s+tomorrow\b)|(?<=\s)tomorrow$', caseSensitive: false),
          ref.add(const Duration(days: 1)),
          'Tomorrow'
        ),
        (
          RegExp(r'\b(?:by\s+|due:?\s*)yesterday\b|\bdue:yesterday\b|\bby:yesterday\b', caseSensitive: false),
          ref.subtract(const Duration(days: 1)),
          'Yesterday'
        ),
        (
          RegExp(r'\b(?:by\s+|due:?\s*)next\s+week\b|\bdue:next\s+week\b', caseSensitive: false),
          ref.add(const Duration(days: 7)),
          'Next Week'
        ),
      ];

      for (final (regex, date, label) in relativePatterns) {
        if (regex.hasMatch(workingText)) {
          dueDate = calendarDate(date);
          dueString = label;
          workingText = workingText.replaceAll(regex, ' ').trim();
          break;
        }
      }
    }

    // C. Weekdays: by monday, due friday, by fri, etc.
    if (dueDate == null) {
      final weekdayMap = {
        'mon': DateTime.monday,
        'monday': DateTime.monday,
        'tue': DateTime.tuesday,
        'tues': DateTime.tuesday,
        'tuesday': DateTime.tuesday,
        'wed': DateTime.wednesday,
        'wednesday': DateTime.wednesday,
        'thu': DateTime.thursday,
        'thur': DateTime.thursday,
        'thurs': DateTime.thursday,
        'thursday': DateTime.thursday,
        'fri': DateTime.friday,
        'friday': DateTime.friday,
        'sat': DateTime.saturday,
        'saturday': DateTime.saturday,
        'sun': DateTime.sunday,
        'sunday': DateTime.sunday,
      };

      final weekdayRegex = RegExp(
        r'\b(?:by\s+|due:?\s*)(mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:r(?:s(?:day)?)?)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b',
        caseSensitive: false,
      );
      final match = weekdayRegex.firstMatch(workingText);
      if (match != null) {
        final dayStr = match.group(1)!.toLowerCase();
        final targetWeekday = weekdayMap[dayStr];
        if (targetWeekday != null) {
          dueDate = _nextWeekday(ref, targetWeekday);
          dueString = _capitalize(match.group(1)!);
          workingText = workingText.replaceRange(match.start, match.end, ' ').trim();
        }
      }
    }

    // Clean up multiple spaces
    var cleanTitle = workingText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanTitle.isEmpty) {
      cleanTitle = trimmed;
    }

    return ParsedTaskCommand(
      rawText: trimmed,
      cleanTitle: cleanTitle,
      dueDate: dueDate,
      dueString: dueString,
      category: primaryCategory,
      tags: tags,
      priority: priority,
    );
  }

  static DateTime _nextWeekday(DateTime from, int targetWeekday) {
    var daysAhead = targetWeekday - from.weekday;
    if (daysAhead <= 0) {
      daysAhead += 7;
    }
    return calendarDate(from.add(Duration(days: daysAhead)));
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
