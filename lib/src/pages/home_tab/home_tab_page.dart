import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/tab_bar_config.dart';
import 'package:jhentai/src/pages/home_tab/home_gallery_tab_view.dart';
import 'package:jhentai/src/pages/home_tab/home_tab_page_logic.dart';
import 'package:jhentai/src/pages/home_tab/home_tab_page_state.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_state.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/notification/tap_menu_button_notification.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';

/// For mobile v2 layout: user-editable gallery tabs, see [HomeTabBarService]
class HomeTabPage extends StatelessWidget {
  const HomeTabPage({Key? key}) : super(key: key);

  HomeTabPageLogic get logic => Get.put<HomeTabPageLogic>(HomeTabPageLogic(), permanent: true);

  HomeTabPageState get state => Get.find<HomeTabPageLogic>().state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeTabPageLogic>(
      global: false,
      init: logic,
      builder: (_) => Scaffold(
        backgroundColor: UIConfig.backGroundColor(context),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu, size: 20),
            onPressed: () => TapMenuButtonNotification().dispatch(context),
          ),
          title: Text('home'.tr),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () => toRoute(Routes.mobileV2Search)),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'manageHomeTabs'.tr,
              onPressed: () => toRoute(Routes.homeTabManagement),
            ),
            IconButton(icon: const Icon(Icons.more_vert), onPressed: MobileLayoutPageV2State.scaffoldKey.currentState?.openEndDrawer),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: buildTabBar(),
          ),
        ),
        body: buildTabView(),
      ),
    );
  }

  Widget buildTabBar() {
    return SizedBox(
      height: 44,
      child: GetBuilder<HomeTabPageLogic>(
        id: logic.tabBarId,
        builder: (_) => ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (int index = 0; index < logic.visibleTabs.length; index++)
              _HomeTabChip(
                key: ValueKey(logic.visibleTabs[index].id),
                name: logic.visibleTabs[index].name,
                selected: index == state.currentTabIndex,
                onTap: () => logic.handleTapTab(index),
              ),
            IconButton(icon: const Icon(Icons.add, size: 20), onPressed: () => toRoute(Routes.homeTabEdit)),
          ],
        ),
      ),
    );
  }

  Widget buildTabView() {
    return GetBuilder<HomeTabPageLogic>(
      id: logic.pageViewId,
      builder: (_) => PageView(
        key: state.pageViewKey,
        controller: state.pageController,
        onPageChanged: logic.onPageChanged,
        children: [
          for (TabBarConfig tab in logic.visibleTabs) HomeGalleryTabView(key: ValueKey(tab.id), logic: logic.logicFor(tab)),
        ],
      ),
    );
  }
}

class _HomeTabChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _HomeTabChip({Key? key, required this.name, required this.selected, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 200));
        onTap();
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(width: 2, color: selected ? colorScheme.primary : Colors.transparent)),
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
