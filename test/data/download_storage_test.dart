import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/platform/download_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late DownloadStorage storage;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'pixora_storage_test',
    );
    storage = DownloadStorage();
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('Android 目标可编码、恢复并显示用户可读路径', () {
    const descriptor = DownloadDestinationDescriptor(
      kind: 'androidTree',
      root: 'content://tree/primary%3APictures',
      rootLabel: '我的图片',
      relativeSegments: ['米山舞', 'illust'],
      fileName: '123_p0.png',
    );

    final decoded = DownloadDestinationDescriptor.decode(descriptor.encode());
    expect(decoded, isNotNull);
    expect(decoded!.kind, 'androidTree');
    expect(decoded.root, descriptor.root);
    expect(decoded.relativeSegments, descriptor.relativeSegments);
    expect(
      decoded.displayPath,
      ['我的图片', '米山舞', 'illust', '123_p0.png'].join(Platform.pathSeparator),
    );
  });

  test('旧绝对路径保持原样显示', () {
    final path = '${tempDirectory.path}${Platform.pathSeparator}old.png';
    expect(storage.displayPath(path), path);
  });

  test('文件系统提交自动创建分类目录', () async {
    final target = [
      tempDirectory.path,
      'author',
      'illust',
      '1_p0.png',
    ].join(Platform.pathSeparator);
    final source = File('${tempDirectory.path}${Platform.pathSeparator}a.part');
    await source.writeAsBytes([1, 2, 3]);

    final result = await storage.commit(source.path, target);

    expect(result.storedDestination, target);
    expect(await File(target).readAsBytes(), [1, 2, 3]);
    expect(await source.exists(), isFalse);
  });

  test('同名文件不会覆盖而是追加序号', () async {
    final target = '${tempDirectory.path}${Platform.pathSeparator}same.jpg';
    await File(target).writeAsBytes([1]);
    final source = File('${tempDirectory.path}${Platform.pathSeparator}b.part');
    await source.writeAsBytes([2]);

    final result = await storage.commit(source.path, target);

    expect(result.storedDestination, contains('same (1).jpg'));
    expect(await File(target).readAsBytes(), [1]);
    expect(await File(result.storedDestination).readAsBytes(), [2]);
  });
}
