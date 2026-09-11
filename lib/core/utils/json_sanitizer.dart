import 'dart:convert';

class JsonSanitizer {
  /// Cleans raw text from AI (such as ChatGPT or Gemini) that may contain markdown fences,
  /// conversational prefixes/suffixes, and extracts valid JSON structure.
  static dynamic sanitizeAndDecode(String rawInput) {
    String cleaned = rawInput.trim();

    // 1. Remove markdown code blocks like ```json ... ``` or ``` ... ```
    if (cleaned.startsWith('```')) {
      final firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      } else {
        cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '');
      }
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trim();
    }

    // 2. Find outermost brackets if AI added conversational text before or after
    final firstBracket = cleaned.indexOf('[');
    final firstBrace = cleaned.indexOf('{');

    if (firstBracket != -1 && (firstBrace == -1 || firstBracket < firstBrace)) {
      final lastBracket = cleaned.lastIndexOf(']');
      if (lastBracket != -1 && lastBracket > firstBracket) {
        cleaned = cleaned.substring(firstBracket, lastBracket + 1);
      }
    } else if (firstBrace != -1) {
      final lastBrace = cleaned.lastIndexOf('}');
      if (lastBrace != -1 && lastBrace > firstBrace) {
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }
    }

    // 3. Attempt direct decoding
    try {
      return jsonDecode(cleaned);
    } catch (_) {
      // 4. Fallback: clean trailing commas before closing braces/brackets
      cleaned = cleaned.replaceAll(RegExp(r',\s*([\]}])'), r'$1');
      return jsonDecode(cleaned);
    }
  }
}
