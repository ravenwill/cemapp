import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _sharps = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _flatMap = {'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#'};

/// Transpõe um acorde (ex.: "F#m7/A#") por [steps] semitons.
String transposeChord(String chord, int steps) {
  if (steps % 12 == 0) return chord;
  final parts = chord.split('/');
  return parts.map((p) => _transposeRoot(p, steps)).join('/');
}

/// Semitons para ir do tom [from] ao tom [to] (-5..6). Aceita "C#m", "Bb" etc.
int semitonesBetween(String from, String to) {
  int pc(String k) {
    final m = RegExp(r'^([A-G][#b]?)').firstMatch(k);
    if (m == null) return 0;
    final r = _flatMap[m.group(1)!] ?? m.group(1)!;
    final i = _sharps.indexOf(r);
    // tom menor vale pelo seu relativo maior (C#m ~ E), para comparar C#m com G
    final minor = RegExp(r'^[A-G][#b]?m(?!aj)').hasMatch(k);
    return ((i < 0 ? 0 : i) + (minor ? 3 : 0)) % 12;
  }

  var d = ((pc(to) - pc(from)) % 12 + 12) % 12;
  if (d > 6) d -= 12;
  return d;
}

String _transposeRoot(String c, int steps) {
  final m = RegExp(r'^([A-G][#b]?)(.*)$').firstMatch(c);
  if (m == null) return c;
  var root = m.group(1)!;
  root = _flatMap[root] ?? root;
  final i = _sharps.indexOf(root);
  if (i < 0) return c;
  return _sharps[((i + steps) % 12 + 12) % 12] + m.group(2)!;
}

/// Modos de exibição da cifra.
enum SheetMode { cifra, letra, smart }

final _chordRe = RegExp(r'\[([^\]]+)\]');

class _Ln {
  _Ln(this.raw)
      : dir = RegExp(r'^\{(.*)\}$')
            .firstMatch(raw.trim())
            ?.group(1)
            ?.replaceFirst(RegExp(r'^\w+:\s*'), '') {
    chords = _chordRe.allMatches(raw).map((m) => m.group(1)!).toList();
    lyric = dir != null
        ? ''
        : raw.replaceAll(_chordRe, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  final String raw;
  final String? dir;
  late final List<String> chords;
  late final String lyric;
  bool get blank => dir == null && raw.trim().isEmpty;
}

class _Block {
  String? title;
  final lines = <_Ln>[];
}

class _Pat {
  _Pat(this.pre, this.unit, this.post, this.reps);
  final List<String> pre, unit, post;
  final int reps;
}

/// Renderiza cifra em ChordPro ([G]texto) em 3 modos: cifra completa,
/// só letra e smart (progressões sem repetição).
class ChordSheet extends StatelessWidget {
  const ChordSheet(
      {super.key,
      required this.source,
      this.semitones = 0,
      this.mode = SheetMode.cifra});
  final String source;
  final int semitones;
  final SheetMode mode;

  static const _mono = TextStyle(
      fontFamily: 'Courier New',
      fontFamilyFallback: ['Consolas', 'Menlo', 'monospace'],
      fontSize: 14,
      height: 1.35);

  @override
  Widget build(BuildContext context) {
    final lines = source.split('\n').map((l) => _Ln(l.trimRight())).toList();
    switch (mode) {
      case SheetMode.letra:
        return _letra(context, lines);
      case SheetMode.smart:
        return _smart(context, lines);
      case SheetMode.cifra:
        return _cifra(lines);
    }
  }

  // ---------- cifra completa: letra intacta, acordes alinhados por coluna
  Widget _cifra(List<_Ln> lines) {
    final out = <Widget>[];
    for (final l in lines) {
      if (l.dir != null) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(l.dir!, style: _mono.copyWith(fontWeight: FontWeight.w800)),
        ));
        continue;
      }
      if (!l.raw.contains('[')) {
        out.add(Text(l.raw.isEmpty ? ' ' : l.raw, style: _mono));
        continue;
      }
      final chords = StringBuffer();
      final lyric = StringBuffer();
      var rest = l.raw;
      while (true) {
        final m = _chordRe.firstMatch(rest);
        if (m == null) {
          lyric.write(rest);
          break;
        }
        lyric.write(rest.substring(0, m.start));
        // acorde na coluna do trecho; se colidir, só afasta o acorde (letra intacta)
        while (chords.length < lyric.length) {
          chords.write(' ');
        }
        if (chords.isNotEmpty && !chords.toString().endsWith(' ')) {
          chords.write(' ');
        }
        chords.write(transposeChord(m.group(1)!, semitones));
        rest = rest.substring(m.end);
      }
      out.add(Text(chords.toString(),
          style: _mono.copyWith(
              color: AppColors.primary, fontWeight: FontWeight.w800)));
      if (lyric.toString().trim().isNotEmpty) {
        out.add(Text(lyric.toString(), style: _mono));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }

  // ---------- só letra
  Widget _letra(BuildContext context, List<_Ln> lines) {
    final t = Theme.of(context).textTheme.bodyLarge!.copyWith(height: 1.5);
    final out = <Widget>[];
    var lastBlank = true;
    for (final l in lines) {
      if (l.dir != null) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(l.dir!, style: t.copyWith(fontWeight: FontWeight.w800)),
        ));
        lastBlank = true;
        continue;
      }
      if (l.lyric.isEmpty) {
        // linha só de acordes ou vazia
        if (!lastBlank) out.add(const SizedBox(height: 10));
        lastBlank = true;
        continue;
      }
      out.add(Text(l.lyric, style: t));
      lastBlank = false;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }

  // ---------- smart: só progressões, sem repetir padrões
  List<_Block> _blocks(List<_Ln> lines) {
    final blocks = <_Block>[];
    var cur = _Block();
    void flush() {
      if (cur.lines.isNotEmpty || cur.title != null) blocks.add(cur);
      cur = _Block();
    }

    for (final l in lines) {
      if (l.dir != null) {
        flush();
        cur.title = l.dir;
      } else if (l.blank) {
        flush();
      } else {
        cur.lines.add(l);
      }
    }
    flush();
    return blocks;
  }

  /// Acha o trecho que mais se repete (ciclo) numa lista de linhas de acordes.
  /// Ex.: D4 | C9 G | Em D4 | C9 G | Em D4 | C9 G ...  ->  unit [Em D4, C9 G] x N.
  _Pat _pattern(List<String> s) {
    final n = s.length;
    var bestO = 0, bestP = 0, bestR = 1, bestCov = 0;
    for (var p = 1; p <= n ~/ 2; p++) {
      for (var o = 0; o + 2 * p <= n; o++) {
        var end = o + p;
        while (end < n && s[end] == s[end - p]) {
          end++;
        }
        final reps = (end - o) ~/ p;
        if (reps < 2) continue;
        if (reps * p > bestCov) {
          bestCov = reps * p;
          bestO = o;
          bestP = p;
          bestR = reps;
        }
      }
    }
    if (bestP == 0) return _Pat(s, const [], const [], 1);
    var pre = s.sublist(0, bestO);
    var unit = s.sublist(bestO, bestO + bestP);
    var post = s.sublist(bestO + bestR * bestP);
    // sobra parcial do ciclo (ex.: última volta cortada) não é conteúdo novo
    if (post.length < unit.length) {
      var same = true;
      for (var i = 0; i < post.length; i++) {
        if (post[i] != unit[i]) same = false;
      }
      if (same) post = const [];
    }
    // entrada que é só o final da última linha do ciclo (ex.: "D4" antes de "Em D4")
    if (pre.isNotEmpty) {
      final last = pre.last.split(' ');
      final u = unit.last.split(' ');
      var tail = u.length > last.length;
      for (var i = 0; tail && i < last.length; i++) {
        if (u[u.length - last.length + i] != last[i]) tail = false;
      }
      if (tail) {
        pre = pre.sublist(0, pre.length - 1);
        unit = [unit.last, ...unit.sublist(0, unit.length - 1)];
      }
    }
    return _Pat(pre, unit, post, bestR);
  }

  String _ref(String lyric) {
    final w = lyric.split(' ').where((e) => e.isNotEmpty).take(4).join(' ');
    return '$w...';
  }

  Widget _chordLine(String k) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
            k
                .split(' ')
                .where((e) => e.isNotEmpty)
                .map((c) => transposeChord(c, semitones))
                .join('   '),
            style: _mono.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w800)),
      );

  Widget _smart(BuildContext context, List<_Ln> lines) {
    final blocks = _blocks(lines);
    final seen = <String>{};
    final out = <Widget>[];
    var first = true;
    var omitted = 0;
    var n = 0;
    for (final b in blocks) {
      final withChords = b.lines.where((l) => l.chords.isNotEmpty).toList();
      if (withChords.isEmpty) continue;
      final lineKeys = withChords.map((l) => l.chords.join(' ')).toList();
      final pat = _pattern(lineKeys);
      final key = [...pat.pre, '~', ...pat.unit, '~', ...pat.post].join('|');
      if (!seen.add(key)) {
        first = false;
        omitted++;
        continue; // padrão já mostrado
      }
      final firstLyric = withChords
          .firstWhere((l) => l.lyric.isNotEmpty, orElse: () => withChords.first)
          .lyric;
      final title = b.title ??
          (firstLyric.isNotEmpty ? _ref(firstLyric) : (first ? 'Intro' : ''));
      first = false;
      final letter = String.fromCharCode(65 + (n % 26));
      n++;
      out.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(letter,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title.isNotEmpty)
                Text(title.toUpperCase(),
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: .6,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mutedForeground)),
              for (final k in pat.pre) _chordLine(k),
              if (pat.reps > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [for (final k in pat.unit) _chordLine(k)]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${pat.reps}x',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ),
                      ]),
                )
              else
                for (final k in pat.unit) _chordLine(k),
              for (final k in pat.post) _chordLine(k),
            ]),
          ),
        ]),
      ));
    }
    if (out.isEmpty) {
      return Text('Sem acordes para resumir.', style: _mono);
    }
    if (omitted > 0) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
            '$omitted bloco(s) repetido(s) omitido(s) por repetir uma progressão já mostrada.',
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }
}
