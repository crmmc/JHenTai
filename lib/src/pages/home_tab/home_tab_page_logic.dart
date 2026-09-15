import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/tab_bar_config.dart';
import 'package:jhentai/src/pages/home_tab/home_gallery_tab_logic.dart';
import 'package:jhentai/src/pages/home_tab/home_tab_page_state.dart';
import 'package:jhentai/src/service/home_tab_bar_service.dart';
import 'package:jhentai/src/utils/uuid_util.dart';

class HomeTabPageLogic extends GetxController {
  final String tabBarId = 'tabBarId';
  final String pageViewId = 'pageViewId';

  @override
  final HomeTabPageState state = HomeTabPageState();

  List<TabBarConfig> get visibleTabs => homeTabBarService.visibleTabs;

  List<String> _lastVisibleIds = [];

  HomeTabPageLogic() {
    state.currentTabIndex = homeTabBarService.lastIndex.clamp(0, homeTabBarService.visibleTabs.length - 1).toInt();
    state.pageController = PageController(initialPage: state.currentTabIndex);
    _lastVisibleIds = visibleTabs.map((tab) => tab.id).toList();
  }

  /// may be null before the page view built the current tab
  HomeGalleryTabLogic? get currentTabLogic {
    if (state.currentTabIndex >= visibleTabs.length) {
      return null;
    }
    return state.tabLogics[visibleTabs[state.currentTabIndex].id];
  }

  HomeGalleryTabLogic logicFor(TabBarConfig tab) {
    return state.tabLogics.putIfAbsent(tab.id, () => HomeGalleryTabLogic(tabId: tab.id, searchConfig: tab.searchConfig));
  }

  @override
  void onInit() {
    super.onInit();
    homeTabBarService.addListener(_onTabBarChanged);
  }

  @override
  void onClose() {
    homeTabBarService.removeListener(_onTabBarChanged);
    for (HomeGalleryTabLogic logic in state.tabLogics.values) {
      logic.onClose();
    }
    state.pageController.dispose();
    super.onClose();
  }

  void handleTapTab(int index) {
    if (index == state.currentTabIndex) {
      return;
    }

    state.currentTabIndex = index;
    homeTabBarService.saveLastIndex(index);
    updateSafely([tabBarId]);

    state.pageController.jumpToPage(index);
  }

  void onPageChanged(int index) {
    state.currentTabIndex = index;
    homeTabBarService.saveLastIndex(index);
    updateSafely([tabBarId]);
  }

  void _onTabBarChanged() {
    List<String> ids = visibleTabs.map((tab) => tab.id).toList();

    /// tab edited: adopt the new searchConfig object
    for (TabBarConfig tab in visibleTabs) {
      HomeGalleryTabLogic? logic = state.tabLogics[tab.id];
      if (logic != null && !identical(logic.searchConfig, tab.searchConfig)) {
        logic.updateSearchConfig(tab.searchConfig);
      }
    }

    /// tab deleted: dispose its logic after this frame, when its view is unmounted
    Map<String, HomeGalleryTabLogic> removedLogics = {};
    state.tabLogics.removeWhere((id, logic) {
      bool dead = !homeTabBarService.tabBarConfigs.any((tab) => tab.id == id);
      if (dead) {
        removedLogics[id] = logic;
      }
      return dead;
    });
    for (HomeGalleryTabLogic logic in removedLogics.values) {
      Get.engine.addPostFrameCallback((_) => logic.onClose());
    }

    if (!listEquals(ids, _lastVisibleIds)) {
      String? currentTabId = _lastVisibleIds.isEmpty || state.currentTabIndex >= _lastVisibleIds.length ? null : _lastVisibleIds[state.currentTabIndex];

      int newIndex = currentTabId == null ? -1 : ids.indexOf(currentTabId);
      if (newIndex < 0) {
        newIndex = state.currentTabIndex.clamp(0, ids.length - 1).toInt();
      }

      state.currentTabIndex = newIndex;
      state.pageController = PageController(initialPage: newIndex);
      state.pageViewKey = Key(newUUID());
      _lastVisibleIds = ids;

      /// reorder/delete may have moved the selected tab
      homeTabBarService.saveLastIndex(newIndex);
    }

    updateSafely([tabBarId, pageViewId]);
  }
}
