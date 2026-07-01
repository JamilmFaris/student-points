import 'package:dio/dio.dart';

import '../api_client.dart';
import '_dio_error.dart';

/// The signed-in teacher's *own* Quran memorization, tracked by juz range.
class UserHifzApi {
  UserHifzApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  /// `GET /api/quran/user-hifz/` → merged, sorted juz ranges, e.g.
  /// `[[1, 5], [7, 8]]`. The response is normalized and overlapping/duplicate
  /// ranges are merged, so the caller always gets a small, clean list even if
  /// the server returns one row per record.
  Future<List<List<int>>> getRanges() async {
    try {
      final res = await _dio.get('/api/quran/user-hifz/');
      if (res.statusCode == 200) {
        return _parseRanges(res.data);
      }
      throw ApiException(extractDrfError(res) ?? 'فشل تحميل الحفظ');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// Tolerates several server shapes without throwing:
  ///  - list of pairs:   `[[1, 5], [7, 8]]`
  ///  - flat list:       `[1, 5, 7, 8]`
  ///  - list of objects: `[{"juz_range": [1, 5]}, ...]`
  List<List<int>> _parseRanges(dynamic data) {
    if (data is! List) return const [];
    final pairs = <List<int>>[];
    void addPair(int a, int b) => pairs.add([a < b ? a : b, a < b ? b : a]);

    final lists = data.whereType<List>().toList();
    final maps = data.whereType<Map>().toList();
    if (lists.isNotEmpty) {
      for (final l in lists) {
        final nums = l.whereType<num>().map((n) => n.toInt()).toList();
        if (nums.isEmpty) continue;
        addPair(nums.first, nums.length > 1 ? nums[1] : nums.first);
      }
    } else if (maps.isNotEmpty) {
      for (final m in maps) {
        final jr = m['juz_range'];
        if (jr is List) {
          final nums = jr.whereType<num>().map((n) => n.toInt()).toList();
          if (nums.isNotEmpty) {
            addPair(nums.first, nums.length > 1 ? nums[1] : nums.first);
          }
        }
      }
    } else {
      final nums = data.whereType<num>().map((n) => n.toInt()).toList();
      for (int i = 0; i + 1 < nums.length; i += 2) {
        addPair(nums[i], nums[i + 1]);
      }
    }
    return _mergeJuzRanges(pairs);
  }

  /// Merges overlapping/adjacent [from, to] juz ranges into a minimal set.
  List<List<int>> _mergeJuzRanges(List<List<int>> pairs) {
    if (pairs.isEmpty) return const [];
    pairs.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<int>>[List.of(pairs.first)];
    for (int i = 1; i < pairs.length; i++) {
      final cur = pairs[i];
      final last = merged.last;
      if (cur[0] <= last[1] + 1) {
        if (cur[1] > last[1]) last[1] = cur[1];
      } else {
        merged.add(List.of(cur));
      }
    }
    return merged;
  }

  /// `POST /api/quran/user-hifz/`.
  Future<void> create({
    required int fromJuz,
    required int toJuz,
    required String date,
    String? label,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'juz_range': [fromJuz, toJuz],
        'date': date,
        if (label != null) 'label': label,
        if (notes != null) 'notes': notes,
      };
      final res = await _dio.post('/api/quran/user-hifz/', data: body);
      if (res.statusCode == 201 || res.statusCode == 200) return;
      throw ApiException(extractDrfError(res) ?? 'فشل إضافة الحفظ');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}
