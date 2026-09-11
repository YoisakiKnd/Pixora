import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/feature/illust/illust_grid.dart';

/// 瀑布流列数必须随窗口宽度变化 —— README 宣传「适配手机和桌面窗口」，
/// 但列数曾被写死为 2，Windows 宽窗口下卡片被拉成大色块。
void main() {
  group('IllustMasonrySliver.columnsFor', () {
    test('手机竖屏宽度保持 2 列', () {
      expect(IllustMasonrySliver.columnsFor(360), 2);
      expect(IllustMasonrySliver.columnsFor(411), 2);
    });

    test('平板 / 桌面宽度按目标卡片宽度增列', () {
      // 800 / 260 = 3.07 → 3 列
      expect(IllustMasonrySliver.columnsFor(800), 3);
      // 1280 / 260 = 4.9 → 4 列
      expect(IllustMasonrySliver.columnsFor(1280), 4);
      // 1600 / 260 = 6.1 → 6 列
      expect(IllustMasonrySliver.columnsFor(1600), 6);
    });

    test('极窄宽度不塌到 1 列', () {
      expect(IllustMasonrySliver.columnsFor(120), 2);
      expect(IllustMasonrySliver.columnsFor(0), 2);
    });

    test('超宽窗口受 maxColumns 约束', () {
      expect(IllustMasonrySliver.columnsFor(10000), 8);
      expect(IllustMasonrySliver.columnsFor(10000, maxColumns: 4), 4);
    });

    test('非法宽度回落到 2 列，不抛异常', () {
      expect(IllustMasonrySliver.columnsFor(double.infinity), 2);
      expect(IllustMasonrySliver.columnsFor(double.nan), 2);
      expect(IllustMasonrySliver.columnsFor(-100), 2);
    });
  });
}
