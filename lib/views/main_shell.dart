import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'shopping_list_screen.dart';
import 'widgets/offline_banner.dart';

/// The currently selected bottom-navigation tab. Exposed as a provider so
/// screens (e.g. Home's search bar) can switch tabs without a callback chain.
final selectedTabProvider =
    NotifierProvider<SelectedTabNotifier, int>(SelectedTabNotifier.new);

class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

/// True while a detail screen is closing with its hero return flight. The hero
/// image flies in the Navigator overlay ABOVE the bottom nav and Home FAB, so
/// we fade those out for the flight (nothing to cover / flash) and fade them
/// back in once it lands.
final chromeHiddenProvider =
    NotifierProvider<ChromeHiddenNotifier, bool>(ChromeHiddenNotifier.new);

class ChromeHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Root shell that hosts the four top-level tabs behind a [NavigationBar].
/// Drill-down screens (detail, create, etc.) push on top and cover the bar.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _tabs = [
    HomeScreen(),
    ShoppingListScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(selectedTabProvider);
    final chromeHidden = ref.watch(chromeHiddenProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OfflineBanner(),
          // Faded out (but keeping its space) during a detail hero return so
          // the flying image never covers it.
          IgnorePointer(
            ignoring: chromeHidden,
            child: AnimatedOpacity(
              opacity: chromeHidden ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) =>
                    ref.read(selectedTabProvider.notifier).select(i),
                backgroundColor: AppColors.surface,
                indicatorColor: AppColors.blush,
                surfaceTintColor: Colors.transparent,
                height: 68,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon:
                    Icon(Icons.home_rounded, color: AppColors.primary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon:
                    Icon(Icons.shopping_cart_rounded, color: AppColors.primary),
                label: 'Shopping',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border_rounded),
                selectedIcon:
                    Icon(Icons.favorite_rounded, color: AppColors.primary),
                label: 'Favorites',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon:
                    Icon(Icons.person_rounded, color: AppColors.primary),
                label: 'Profile',
              ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
