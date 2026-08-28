import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/formatters.dart';

/// 物品图片生命周期（requirement.md §4.10）。
/// 压缩由 image_picker(maxWidth/maxHeight/imageQuality) 在采集时完成；
/// 这里负责入库存放、更换覆盖与孤儿清理（备份成功后 / 冷启动兜底）。
class ImageService {
  final Directory imagesDir;
  ImageService(this.imagesDir);

  Future<void> ensureDir() async {
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
  }

  /// 把采集到的临时文件收编为受管文件名，返回文件名（不含路径）。
  Future<String?> importPicked(String? pickedPath) async {
    if (pickedPath == null) return null;
    await ensureDir();
    final name = '${newId().substring(0, 8)}${p.extension(pickedPath)}';
    await File(pickedPath).copy(p.join(imagesDir.path, name));
    return name;
  }

  /// 更换照片：先覆盖旧文件再更新引用，不留双份。
  Future<String?> replacePicked(String? pickedPath, String? oldName) async {
    final newName = await importPicked(pickedPath);
    if (oldName != null && oldName.isNotEmpty && newName != null) {
      final old = File(p.join(imagesDir.path, oldName));
      if (await old.exists()) await old.delete();
    }
    return newName ?? oldName;
  }

  File? resolve(String? name) =>
      name == null || name.isEmpty ? null : File(p.join(imagesDir.path, name));

  /// 孤儿扫描：删除未被任何批次引用的图片（仍被引用的一律跳过）。
  Future<int> removeOrphans(Set<String> referencedNames) async {
    if (!await imagesDir.exists()) return 0;
    var removed = 0;
    await for (final f in imagesDir.list()) {
      if (f is! File) continue;
      if (!referencedNames.contains(p.basename(f.path))) {
        await f.delete();
        removed++;
      }
    }
    return removed;
  }

  Future<int> dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final f in dir.list(recursive: true, followLinks: false)) {
      if (f is File) total += await f.length();
    }
    return total;
  }

  Future<int> imagesBytes() => dirSize(imagesDir);
}
