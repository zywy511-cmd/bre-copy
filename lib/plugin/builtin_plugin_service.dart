import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';

/// 内置漫源「拷贝漫画 Copy4000」的 uuid。
const String kBuiltinCopy4000Uuid = '371d33c6-a901-434a-a0ae-d4ea80c7612f';

/// 内置漫源脚本在 asset 里的路径。
const String _kBuiltinCopy4000Asset = 'asset/plugin/copy4000.cjs';

/// 首次启动时把内置漫源装进插件库，用户无需手动导入。
///
/// 必须在 [PluginRegistryService.init] 之后调用（安装流程会用注册表做去重）。
/// 已存在（含被用户删除后重新安装的场景）时不覆盖用户数据；
/// 任何失败都只记日志，绝不影响启动。
Future<void> ensureBuiltinPluginsInstalled() async {
  try {
    final query = objectbox.pluginInfoBox
        .query(PluginInfo_.uuid.equals(kBuiltinCopy4000Uuid))
        .build();
    try {
      final existing = query.findFirst();
      if (existing != null && !existing.isDeleted) {
        return;
      }
    } finally {
      query.close();
    }

    final data = await rootBundle.load(_kBuiltinCopy4000Asset);
    final script = utf8.decode(data.buffer.asUint8List(), allowMalformed: true);
    await PluginInstallService.I.savePluginByScript(
      script,
      sourceLabel: '内置漫源',
      allowReplaceExisting: true,
    );
    logger.d('[builtin-plugin] 已安装内置漫源: $kBuiltinCopy4000Uuid');
  } catch (e, st) {
    logger.e(e, stackTrace: st);
  }
}
