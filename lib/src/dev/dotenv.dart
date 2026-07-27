import 'dart:io';

/// 极简 `.env` 读取，**仅供本地测试与命令行探针使用**，不参与 App 运行。
///
/// 没有引第三方包：需求就是「读一个 key=value 文件」，为此加一个依赖不划算，
/// 而且 `flutter_dotenv` 那类包依赖 Flutter 的 asset 机制，在纯 Dart 的
/// `dart run tool/...` 和 `flutter test` 里都不好用。
///
/// 查找顺序：**真实环境变量优先**，再回落到 `.env` 文件。这样 CI 上用环境变量、
/// 本地用文件，两边都不用改代码。
class DotEnv {
  const DotEnv._();

  static Map<String, String>? _cache;
  static String? _loadedFrom;

  /// 实际读到的文件路径，null 表示没找到 `.env`。
  static String? get loadedFrom {
    values;
    return _loadedFrom;
  }

  static Map<String, String> get values => _cache ??= _load();

  /// 取值。环境变量优先于 `.env`。
  static String? get(String key) {
    final fromEnvironment = Platform.environment[key];
    if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
      return fromEnvironment;
    }
    final fromFile = values[key];
    return (fromFile == null || fromFile.isEmpty) ? null : fromFile;
  }

  static void reset() {
    _cache = null;
    _loadedFrom = null;
  }

  static Map<String, String> _load() {
    final file = _locate();
    if (file == null) return const {};
    _loadedFrom = file.path;

    final result = <String, String>{};
    for (var line in file.readAsLinesSync()) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('export ')) line = line.substring(7).trim();

      final separator = line.indexOf('=');
      if (separator <= 0) continue;

      final key = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();

      // 去掉成对的引号，但保留值内部的引号。
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      result[key] = value;
    }
    return result;
  }

  /// 从当前目录向上找 `.env`。
  ///
  /// `flutter test` 与 `dart run` 的工作目录通常已经是项目根，但从 IDE 或子目录
  /// 启动时不一定 —— 向上找到含 `pubspec.yaml` 的目录为止，避免「明明有 .env
  /// 却读不到」这种排查起来很烦的问题。
  static File? _locate() {
    var dir = Directory.current;
    for (var depth = 0; depth < 6; depth++) {
      final env = File('${dir.path}${Platform.pathSeparator}.env');
      if (env.existsSync()) return env;

      final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
      if (pubspec.existsSync()) return null; // 到项目根了还没有，就是真没有

      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}
