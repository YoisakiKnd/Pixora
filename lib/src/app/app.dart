import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth/auth_state.dart';
import '../feature/auth/login_page.dart';
import '../feature/auth/policy_agreement_page.dart';
import '../feature/home/home_page.dart';
import 'providers.dart';

class PixivApp extends ConsumerWidget {
  const PixivApp({super.key, required this.protocolRegistered});

  final bool protocolRegistered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0096FA),
      surface: const Color(0xFFF7F8FA),
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0096FA),
      brightness: Brightness.dark,
      surface: const Color(0xFF101214),
    );
    return MaterialApp(
      title: 'Pixora',
      debugShowCheckedModeBanner: false,
      theme: _theme(lightScheme),
      darkTheme: _theme(darkScheme),
      themeMode: settings.themeMode,
      scrollBehavior: const _DesktopScrollBehavior(),
      home: AuthGate(protocolRegistered: protocolRegistered),
    );
  }

  ThemeData _theme(ColorScheme scheme) => ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      side: BorderSide.none,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
  );
}

class _DesktopScrollBehavior extends MaterialScrollBehavior {
  const _DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

/// 按认证状态决定进哪个页面。
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.protocolRegistered});

  final bool protocolRegistered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authStateProvider).valueOrNull;

    return switch (state) {
      null || AuthUnknown() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),

      AuthLoggedOut() => LoginPage(protocolRegistered: protocolRegistered),

      // 不处理这个状态会表现为「登录成功但什么都刷不出来」。
      AuthPolicyAgreementRequired() => const PolicyAgreementPage(),

      // 凭据失效**不踢回登录页** —— 保留已加载的内容，只在顶部显示重认证横幅。
      AuthAuthenticated() || AuthNeedsReauth() => const HomePage(),
    };
  }
}
