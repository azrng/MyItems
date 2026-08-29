# 调试手机档案

> 真机调试与 UI 验证的目标设备记录。换调试手机时必须更新本档案，并同步 README「本项目快速运行命令」中的设备 ID。

## 当前调试手机

| 项目 | 值 |
| --- | --- |
| 品牌 / 型号 | 魅族 Meizu 16th |
| 系统 | Android 8.1.0（API 27） |
| ABI | arm64-v8a |
| USB 序列号（`flutter devices` / `adb` 设备 ID） | `882QAETJEYG3S` |
| 物理分辨率 | 1080 × 2160 |
| 屏幕密度 | 480dpi（3x，逻辑宽度约 360dp） |
| 连接方式 | USB 数据线 + 已授权 USB 调试 |
| 首次记录 | 2026-08-29 |

## 运行方式

见 `README.md`「本项目快速运行命令」：`flutter run -d 882QAETJEYG3S --debug`。

仅安装已构建产物时：

```bash
flutter build apk --debug
adb -s 882QAETJEYG3S install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 本机型已知的适配注意点

- **安装/覆盖前必须先停应用**：`adb install -r` 在 App 进程存活时执行会强杀进程，drift 的 WAL 未合并会导致库损坏、下次启动重建空库并回到 Onboarding（2026-08-29 实际发生，已从快照恢复）。规范：任何 `install`、push 库文件前先 `am force-stop com.azrng.myitems`。
- **手势条遮挡底部内容**：悬浮 TabBar 与底部弹层需叠加系统手势条安全区；历史问题见 T009（弹层确认键被手势条遮挡），`AppBottomSheet` 已统一叠加 `MediaQuery.paddingOf(context).bottom`。
- **通知小图标**：Android 8.1 通知渠道要求小图标资源存在，否则初始化报错；历史问题见 T008。
- **悬浮层点击命中**：`Stack` + `Clip.none` 绘制越界的部分不可点击，中央 FAB 必须整体落在 Stack 尺寸内（历史问题见 T008）。
- **逻辑宽度 360dp**：双列网格、横向按钮行按 360dp 宽度校验不溢出；更窄屏（<360dp）未覆盖。

## 更新约定

1. `adb devices`（或 `flutter devices`）确认新设备 ID；
2. 更新本档案表格与 README 启动命令中的设备 ID；
3. 换机型后需重新过一遍 T011 真机全场景验证，重点回归底部安全区与触摸目标。
