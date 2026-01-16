import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/source.dart';

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

  Future<List<Source>> loadSources() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList
          .map((j) => Source.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSources(List<Source> sources) async {
    final file = await _localFile;
    final jsonList = sources.map((s) => s.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }
}
