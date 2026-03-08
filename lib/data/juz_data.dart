// Juz' (part) boundaries of the Quran - 30 parts. Hafs numbering.
// Each entry is (surahIndex, ayah) where that juz' starts.
const List<({int surah, int ayah})> kJuzStarts = [
  (surah: 1, ayah: 1),   // Juz 1
  (surah: 2, ayah: 142), // Juz 2
  (surah: 2, ayah: 253), // Juz 3
  (surah: 3, ayah: 92),  // Juz 4
  (surah: 4, ayah: 24),  // Juz 5
  (surah: 4, ayah: 148), // Juz 6
  (surah: 5, ayah: 82),  // Juz 7
  (surah: 6, ayah: 111), // Juz 8
  (surah: 7, ayah: 88),  // Juz 9
  (surah: 8, ayah: 41),  // Juz 10
  (surah: 9, ayah: 93),  // Juz 11
  (surah: 10, ayah: 26), // Juz 12
  (surah: 11, ayah: 6),  // Juz 13
  (surah: 12, ayah: 53), // Juz 14
  (surah: 15, ayah: 2),  // Juz 15
  (surah: 17, ayah: 1),  // Juz 16
  (surah: 18, ayah: 75), // Juz 17
  (surah: 21, ayah: 1),  // Juz 18
  (surah: 23, ayah: 1),  // Juz 19
  (surah: 25, ayah: 21), // Juz 20
  (surah: 27, ayah: 56), // Juz 21
  (surah: 29, ayah: 46), // Juz 22
  (surah: 33, ayah: 31), // Juz 23
  (surah: 36, ayah: 28), // Juz 24
  (surah: 39, ayah: 32), // Juz 25
  (surah: 41, ayah: 47), // Juz 26
  (surah: 46, ayah: 1),  // Juz 27
  (surah: 51, ayah: 31), // Juz 28
  (surah: 58, ayah: 1),  // Juz 29
  (surah: 78, ayah: 1),  // Juz 30
];

/// Returns the juz' number (1-30) for a given surah and ayah.
int juzForAyah(int surahIndex, int ayah) {
  for (int j = kJuzStarts.length; j >= 1; j--) {
    final s = kJuzStarts[j - 1];
    if (surahIndex > s.surah) return j;
    if (surahIndex == s.surah && ayah >= s.ayah) return j;
  }
  return 1;
}

/// Returns the list of (surah, from, to) ranges that make up juz [j] (1-based).
/// Used for adding a whole juz to memorization.
List<({int surah, int from, int to})> rangesForJuz(int j, int Function(int) maxAyahsOfSurah) {
  if (j < 1 || j > 30) return [];
  final start = kJuzStarts[j - 1];
  int endSurah;
  int endAyah;
  if (j < 30) {
    final next = kJuzStarts[j];
    if (next.ayah > 1) {
      endSurah = next.surah;
      endAyah = next.ayah - 1;
    } else {
      endSurah = next.surah - 1;
      endAyah = maxAyahsOfSurah(endSurah);
    }
  } else {
    endSurah = 114;
    endAyah = 6;
  }
  final result = <({int surah, int from, int to})>[];
  int s = start.surah;
  int a = start.ayah;
  while (s < endSurah || (s == endSurah && a <= endAyah)) {
    final maxInSurah = maxAyahsOfSurah(s);
    final to = s == endSurah ? endAyah : maxInSurah;
    result.add((surah: s, from: a, to: to));
    if (s == endSurah) break;
    s++;
    a = 1;
  }
  return result;
}

/// Splits a range (surah, from, to) into sub-ranges per juz.
/// Returns list of (juz, from, to) for each juz the range touches.
List<({int juz, int from, int to})> splitRangeByJuz(int surahIndex, int from, int to) {
  final result = <({int juz, int from, int to})>[];
  int curFrom = from;
  while (curFrom <= to) {
    final j = juzForAyah(surahIndex, curFrom);
    // End of juz j: next juz starts at (nextSurah, nextAyah)
    int curTo = to;
    if (j < 30) {
      final next = kJuzStarts[j];
      if (next.surah == surahIndex && next.ayah <= to + 1) {
        curTo = next.ayah - 1;
        if (curTo < curFrom) curTo = curFrom;
      }
    }
    if (curTo > to) curTo = to;
    result.add((juz: j, from: curFrom, to: curTo));
    curFrom = curTo + 1;
  }
  return result;
}
