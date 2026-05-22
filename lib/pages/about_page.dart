import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../widgets/common.dart';

const apkDownloadUrl = 'https://github.com/azrng/MyItems/releases';
const appDisplayVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Center(child: Text('📦', style: TextStyle(fontSize: 54))),
              const SizedBox(height: 8),
              const Center(
                  child: Text('我的物品',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              const Center(child: Text('版本 $appDisplayVersion')),
              const SizedBox(height: 18),
              const SectionCard(
                title: '简介',
                children: [
                  Text('个人/家庭自用的物品管理 App，用于跟踪保质期、存放位置、购买价格和分类信息。'),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '信息',
                children: [
                  const DetailTile(label: '作者', value: 'azrng'),
                  const ProjectLinkTile(
                    label: '项目地址',
                    value: 'github.com/azrng/MyItems',
                    url: 'https://github.com/azrng/MyItems',
                  ),
                  FilledButton.icon(
                    onPressed: () => openExternalUrl(
                      context,
                      apkDownloadUrl,
                      failurePrefix: '无法打开 APK 下载地址',
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('下载 APK'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '主题模式',
                children: [
                  SegmentedButton<ThemePreference>(
                    segments: ThemePreference.values
                        .map((preference) => ButtonSegment<ThemePreference>(
                              value: preference,
                              label: Text(preference.label),
                            ))
                        .toList(),
                    selected: {store.themePreference},
                    onSelectionChanged: (values) {
                      store.setThemePreference(values.first);
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProjectLinkTile extends StatelessWidget {
  const ProjectLinkTile({
    super.key,
    required this.label,
    required this.value,
    required this.url,
  });

  final String label;
  final String value;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await openExternalUrl(context, url, failurePrefix: '无法打开项目地址');
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    );
  }
}

Future<void> openExternalUrl(
  BuildContext context,
  String url, {
  required String failurePrefix,
}) async {
  try {
    await const MethodChannel('my_items/system').invokeMethod<void>(
      'openUrl',
      {'url': url},
    );
  } catch (error) {
    if (context.mounted) {
      showSnack(context, '$failurePrefix：$error');
    }
  }
}
