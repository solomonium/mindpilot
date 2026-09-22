/// Helper utility that extracts what the user actually asked the AI to do,
/// stripping out system instructions, roleplay prompts, frameworks,
/// and prompt-engineering boilerplate.
class PromptCleanHelper {
  /// Extracts the clean user question or request from a raw prompt string.
  static String extractUserPrompt(String? rawPrompt) {
    if (rawPrompt == null || rawPrompt.trim().isEmpty) {
      return 'No prompt recorded for this log';
    }

    var text = rawPrompt.trim();

    // 1. Explicit "User message:\n"..." (Decision Analyzer, ChatProcessor)
    final userMsgRegex = RegExp(
      r'User message:\s*["\u201C]?\n*([\s\S]*?)(?:["\u201D]?\s*(?:\n\s*Framework|\n\s*Rules|\n\s*Structure|\z))',
      caseSensitive: false,
    );
    final userMsgMatch = userMsgRegex.firstMatch(text);
    if (userMsgMatch != null) {
      final extracted = userMsgMatch.group(1)?.trim() ?? '';
      if (extracted.isNotEmpty) {
        return _cleanQuotesAndTrim(extracted);
      }
    }

    // 2. Explicit "User spoke: "..." (Voice Bible Study)
    final userSpokeRegex = RegExp(
      r'User spoke:\s*["\u201C]?\n*([\s\S]*?)(?:["\u201D]?\s*(?:\n|\z))',
      caseSensitive: false,
    );
    final userSpokeMatch = userSpokeRegex.firstMatch(text);
    if (userSpokeMatch != null) {
      final extracted = userSpokeMatch.group(1)?.trim() ?? '';
      if (extracted.isNotEmpty) {
        return _cleanQuotesAndTrim(extracted);
      }
    }

    // 3. Explicit "User query: "..." or "User question: "..."
    final userQueryRegex = RegExp(
      r'(?:User query|User question|User inquiry|User input):\s*["\u201C]?\n*([\s\S]*?)(?:["\u201D]?\s*(?:\n|\z))',
      caseSensitive: false,
    );
    final userQueryMatch = userQueryRegex.firstMatch(text);
    if (userQueryMatch != null) {
      final extracted = userQueryMatch.group(1)?.trim() ?? '';
      if (extracted.isNotEmpty) {
        return _cleanQuotesAndTrim(extracted);
      }
    }

    // 4. Candidate Answer evaluation
    final candidateRegex = RegExp(
      r'Candidate(?:.*?Answer)?:\s*["\u201C]?\n*([\s\S]*?)(?:["\u201D]?\s*(?:\n\s*Evaluate|\n\s*Return|\z))',
      caseSensitive: false,
    );
    final candidateMatch = candidateRegex.firstMatch(text);
    if (candidateMatch != null) {
      final extracted = candidateMatch.group(1)?.trim() ?? '';
      if (extracted.isNotEmpty) {
        return 'Candidate evaluation: "${_cleanQuotesAndTrim(extracted)}"';
      }
    }

    // 5. Decision continuation ("The previous analysis was cut off... Context: ...")
    final contextRegex = RegExp(
      r'Context:\s*([^\n]+)',
      caseSensitive: false,
    );
    final contextMatch = contextRegex.firstMatch(text);
    if (contextMatch != null && text.contains('previous analysis was cut off')) {
      final extracted = contextMatch.group(1)?.trim() ?? '';
      if (extracted.isNotEmpty) {
        return 'Continue analysis on: $extracted';
      }
    }

    // 6. Bible chapter explanation
    final bibleChapterRegex = RegExp(
      r'read the chapter:\s*["\u201C]?([^"\u201D\n]+)["\u201D]?',
      caseSensitive: false,
    );
    final bibleChapterMatch = bibleChapterRegex.firstMatch(text);
    if (bibleChapterMatch != null) {
      return 'Explain Bible Chapter: ${bibleChapterMatch.group(1)?.trim()}';
    }

    // 7. Bible verse explanation
    final bibleVerseRegex = RegExp(
      r'explanation of this specific verse:\s*["\u201C]?([^"\u201D\n]+)["\u201D]?',
      caseSensitive: false,
    );
    final bibleVerseMatch = bibleVerseRegex.firstMatch(text);
    if (bibleVerseMatch != null) {
      return 'Explain Bible Verse: ${bibleVerseMatch.group(1)?.trim()}';
    }

    // 8. Bible highlighted scripture
    final bibleHighlightRegex = RegExp(
      r'highlighted scripture text from the book ["\u201C]?([^"\u201D\n]+)["\u201D]?:?\s*["\u201C]?([\s\S]*?)["\u201D]?(?:\s*\nProvide|\z)',
      caseSensitive: false,
    );
    final bibleHighlightMatch = bibleHighlightRegex.firstMatch(text);
    if (bibleHighlightMatch != null) {
      final book = bibleHighlightMatch.group(1)?.trim() ?? '';
      final snippet = bibleHighlightMatch.group(2)?.trim() ?? '';
      final displaySnippet = snippet.length > 80 ? '${snippet.substring(0, 80)}...' : snippet;
      return 'Explain Scripture ($book): "$displaySnippet"';
    }

    // 9. Riddle / Joke generator
    final riddleJokeRegex = RegExp(
      r'Generate exactly 1 (riddle|joke|pun) about:\s*([^\n\.]+)',
      caseSensitive: false,
    );
    final riddleMatch = riddleJokeRegex.firstMatch(text);
    if (riddleMatch != null) {
      return 'Generate ${riddleMatch.group(1)} on: ${riddleMatch.group(2)?.trim()}';
    }

    // 10. Quiz Generator
    final quizRegex = RegExp(
      r'multiple[- ]choice questions (?:based on|about(?: the topic)?):\s*([^\n\.]+)',
      caseSensitive: false,
    );
    final quizMatch = quizRegex.firstMatch(text);
    if (quizMatch != null) {
      return 'Generate Quiz: ${quizMatch.group(1)?.trim()}';
    }

    // 11. Interview Questions
    final interviewRegex = RegExp(
      r'interview questions for a candidate applying for a ([^\n\.]+) position in ([^\n\.]+)',
      caseSensitive: false,
    );
    final interviewMatch = interviewRegex.firstMatch(text);
    if (interviewMatch != null) {
      return 'Interview Questions: ${interviewMatch.group(1)?.trim()} in ${interviewMatch.group(2)?.trim()}';
    }

    // 12. If raw transcript has multi-turn labels: "User: ... \nModel: ..."
    final userTurns = RegExp(r'(?:User|user|Human):\s*([\s\S]+?)(?=(?:\n(?:Model|Assistant|AI|User|Human):|\z))');
    final matches = userTurns.allMatches(text).toList();
    if (matches.isNotEmpty) {
      final lastUserMessage = matches.last.group(1)?.trim() ?? '';
      if (lastUserMessage.isNotEmpty) {
        return extractUserPrompt(lastUserMessage);
      }
    }

    // 13. Strip common system prompt prefixes/suffixes if text starts with system prompt
    final cleaned = _stripSystemBoilerplate(text);
    if (cleaned.isNotEmpty) {
      return _cleanQuotesAndTrim(cleaned);
    }

    return _cleanQuotesAndTrim(text);
  }

  /// Strips prompt engineering instructions, role definitions, and system guidelines.
  static String _stripSystemBoilerplate(String text) {
    final lines = text.split('\n');
    final filtered = <String>[];
    bool skippingRules = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Check if starting a rules / directives block
      if (trimmed.startsWith('Rules:') ||
          trimmed.startsWith('Rule:') ||
          trimmed.startsWith('Structure your response') ||
          trimmed.startsWith('Policy Directive:') ||
          trimmed.startsWith('Format the response') ||
          trimmed.startsWith('Return ONLY')) {
        skippingRules = true;
        continue;
      }

      // Check if line is a system / role definition
      if (trimmed.startsWith('You are') ||
          trimmed.startsWith('The user\'s name is') ||
          trimmed.startsWith('Your response style') ||
          trimmed.startsWith('Crucial:') ||
          trimmed.startsWith('User intent:') ||
          trimmed.startsWith('Detected emotion') ||
          trimmed.startsWith('User selected feeling:') ||
          trimmed.startsWith('Decision importance') ||
          trimmed.startsWith('Framework to follow')) {
        continue;
      }

      if (skippingRules) {
        // Stop skipping if we hit an actual user content indicator
        if (trimmed.startsWith('User:') || trimmed.startsWith('User message:')) {
          skippingRules = false;
        } else {
          continue;
        }
      }

      filtered.add(trimmed);
    }

    return filtered.join('\n').trim();
  }

  static String _cleanQuotesAndTrim(String str) {
    var s = str.trim();
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith('“') && s.endsWith('”')) ||
        (s.startsWith('\'') && s.endsWith('\''))) {
      if (s.length >= 2) {
        s = s.substring(1, s.length - 1).trim();
      }
    }
    return s.isEmpty ? 'No prompt recorded' : s;
  }
}
