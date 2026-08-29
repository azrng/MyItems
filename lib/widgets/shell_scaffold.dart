import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/library/library_state.dart';

/// 四 Tab 悬浮胶囊 TabBar + 中央渐变 FAB（design-system float_tabbar / app_bar_tabs）。
class ShellScaffold extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const ShellScaffold({super.key, required this.shell});

  static const _tabs = [
    (icon: Icons.home_rounded, label: '首页', route: '/home'),
    (icon: Icons.inventory_2_rounded, label: '物品库', route: '/library'),
    (icon: Icons.local_fire_department_rounded, label: '消耗', route: '/consume'),
    (icon: Icons.face_retouching_natural_rounded, label: '我的', route: '/mine'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final current = shell.currentIndex;
    // 分支页内的 PopScope 拦不住根 Navigator 的系统返回（go_router Shell 结构），
    // 多选模式的返回键拦截必须挂在 Shell 这一层（§5.3）
    final selecting = ref.watch(selectModeProvider);

    void exitSelect() {
      ref.read(selectModeProvider.notifier).state = false;
      ref.read(selectedIdsProvider.notifier).state = {};
    }

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) exitSelect();
      },
      child: Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: SafeArea(
          top: false,
          // 顶部预留 28px 给上浮的中央 FAB：Stack 边界外绘制可见但命中不到（Clip.none 只放开绘制），
          // FAB 必须整体落在 Stack 尺寸内点击才生效
          child: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.only(
                      left: 14, right: 14, top: 8, bottom: 8),
                  height: 68,
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerLowest.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: scheme.outline),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.onSurface.withValues(alpha: 0.22),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                        spreadRadius: -12,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++) ...[
                        if (i == 2) const Spacer(),
                        _TabItem(
                          icon: _tabs[i].icon,
                          label: _tabs[i].label,
                          selected: current == i,
                          color: colors,
                          scheme: scheme,
                          onTap: () => shell.goBranch(
                            i,
                            initialLocation: i == shell.currentIndex,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 中央 FAB：56x56 r20 accent 渐变，上浮叠压 TabBar 顶部
                Positioned(
                  top: 0,
                  child: _AddFab(onTap: () => context.push('/editor')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final AppColors color;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? scheme.onPrimaryContainer : color.inkFaint;
    return Expanded(
      flex: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w900, color: fg)),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: selected ? scheme.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFDE7931), Color(0xFFBE5E18)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFBE5E18).withValues(alpha: 0.65),
                blurRadius: 26,
                offset: const Offset(0, 14),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Icon(Icons.add_rounded, color: scheme.onPrimary, size: 30),
        ),
      ),
    );
  }
}
