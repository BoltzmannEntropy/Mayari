import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/source.dart';
import '../providers/tts_provider.dart';

/// Provider for StorageService (singleton)
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  static const _fileName = 'mayari_data.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File(p.join(path, _fileName));
  }

  Future<Map<String, dynamic>> _loadData() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return {};
      }
      final contents = await file.readAsString();
      final data = json.decode(contents);
      // Handle legacy format (just a list of sources)
      if (data is List) {
        return {'sources': data};
      }
      return data as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  Future<void> _saveData(Map<String, dynamic> data) async {
    final file = await _localFile;
    await file.writeAsString(json.encode(data));
  }

  Future<List<Source>> loadSources() async {
    try {
      final data = await _loadData();
      final sourcesList = data['sources'] as List<dynamic>?;
      if (sourcesList == null) {
        return [];
      }
      return sourcesList
          .map((j) => Source.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSources(List<Source> sources) async {
    final data = await _loadData();
    data['sources'] = sources.map((s) => s.toJson()).toList();
    await _saveData(data);
  }

  Future<TtsSettings> loadTtsSettings() async {
    try {
      final data = await _loadData();
      final ttsData = data['tts'] as Map<String, dynamic>?;
      if (ttsData == null) {
        return const TtsSettings();
      }
      return TtsSettings.fromJson(ttsData);
    } catch (e) {
      return const TtsSettings();
    }
  }

  Future<void> saveTtsSettings(TtsSettings settings) async {
    final data = await _loadData();
    data['tts'] = settings.toJson();
    await _saveData(data);
  }

  /// Load generic JSON data by key
  Future<dynamic> loadJson(String key) async {
    final data = await _loadData();
    return data[key];
  }

  /// Save generic JSON data by key
  Future<void> saveJson(String key, dynamic value) async {
    final data = await _loadData();
    data[key] = value;
    await _saveData(data);
  }
}
