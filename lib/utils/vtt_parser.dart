import 'dart:convert';
import 'package:http/http.dart' as http;

class VttCue {
  final Duration start;
  final Duration end;
  final String text;
  VttCue({required this.start, required this.end, required this.text});
}

// Very small WebVTT parser supporting the common format:
//
// WEBVTT
//
// 00:00:01.000 --> 00:00:03.000
// First line
//
// 00:00:03.500 --> 00:00:05.000
// Second line
List<VttCue> parseWebVtt(String input) {
  final lines = const LineSplitter().convert(input);
  final cues = <VttCue>[];
  int i = 0;
  // Skip optional WEBVTT header
  if (i < lines.length && lines[i].trim().toUpperCase().startsWith('WEBVTT')) {
    i++;
  }
  while (i < lines.length) {
    // Skip empty and note lines
    while (i < lines.length && lines[i].trim().isEmpty) i++;
    if (i >= lines.length) break;

    // Optional cue identifier line (non-timing)
    if (!lines[i].contains('-->')) {
      i++;
    }
    if (i >= lines.length) break;

    // Timing line
    final timing = lines[i];
    i++;
    final parts = timing.split('-->');
    if (parts.length != 2) continue;
    final start = _parseTimestamp(parts[0].trim());
    final end = _parseTimestamp(parts[1].trim().split(' ')[0]);

    final buffer = StringBuffer();
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(lines[i]);
      i++;
    }
    final text = buffer.toString();
    if (start != null && end != null) {
      cues.add(VttCue(start: start, end: end, text: text));
    }
  }
  return cues;
}

Duration? _parseTimestamp(String s) {
  // 00:00:03.500 or 00:03.500
  final parts = s.split(':');
  int hours = 0;
  int minutes = 0;
  double seconds = 0;
  try {
    if (parts.length == 3) {
      hours = int.parse(parts[0]);
      minutes = int.parse(parts[1]);
      seconds = double.parse(parts[2]);
    } else if (parts.length == 2) {
      minutes = int.parse(parts[0]);
      seconds = double.parse(parts[1]);
    } else {
      seconds = double.parse(s);
    }
    final ms = (seconds * 1000).round();
    return Duration(hours: hours, minutes: minutes, milliseconds: ms);
  } catch (_) {
    return null;
  }
}

Future<List<VttCue>> fetchAndParseVtt(String url) async {
  final res = await http.get(Uri.parse(url));
  if (res.statusCode != 200) {
    throw Exception('Failed to fetch transcript');
  }
  return parseWebVtt(utf8.decode(res.bodyBytes));
}
