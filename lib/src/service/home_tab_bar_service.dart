import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/model/tab_bar_config.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/utils/uuid_util.dart';

import 'jh_service.dart';
import 'log.dart';

HomeTabBarService homeTabBarService = HomeTabBarService();

/// User-editable gallery tabs on mobileV2 home page. Each tab binds a full [SearchConfig].
class HomeTabBarService extends GetxController with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  List<TabBarConfig> tabBarConfigs = defaultTabs();

  /// index of the last selected tab among [visibleTabs]
  int lastIndex = 0;

  List<TabBarConfig> get visibleTabs => tabBarConfigs.where((tab) => !tab.hidden).toList();

  /// at least one visible tab must remain on home
  bool get canRemoveVisibleTab => visibleTabs.length > 1;

  @override
  ConfigEnum get configEnum => ConfigEnum.homeTabBar;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    tabBarConfigs = (map['tabs'] as List? ?? []).map((tab) => TabBarConfig.fromJson(tab)).toList();
    lastIndex = (map['lastIndex'] ?? 0) as int;

    /// never leave home empty
    if (visibleTabs.isEmpty) {
      tabBarConfigs.addAll(defaultTabs());
    }
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'tabs': tabBarConfigs.map((tab) => tab.toJson()).toList(),
      'lastIndex': lastIndex,
    });
  }

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  void doAfterBeanReady() {}

  Future<void> addTab(String name, SearchConfig searchConfig) async {
    log.info('Add home tab: $name');

    tabBarConfigs.add(TabBarConfig(id: newUUID(), name: name, searchConfig: searchConfig));
    await saveBeanConfig();
    updateSafely();

    toast('saveSuccess'.tr);
  }

  /// [searchConfig] must be a new object, so pages can detect the change by identity
  Future<void> updateTab(TabBarConfig tab, {required String name, required SearchConfig searchConfig}) async {
    log.info('Update home tab: ${tab.name} => $name');

    tab.name = name;
    tab.searchConfig = searchConfig;
    await saveBeanConfig();
    updateSafely();

    toast('updateSuccess'.tr);
  }

  Future<void> removeTab(TabBarConfig tab) async {
    if (!tab.hidden && !canRemoveVisibleTab) {
      toast('cantRemoveLastVisibleTab'.tr, isShort: false);
      return;
    }

    log.info('Remove home tab: ${tab.name}');

    tabBarConfigs.remove(tab);
    lastIndex = lastIndex.clamp(0, visibleTabs.length - 1).toInt();
    await saveBeanConfig();
    updateSafely();
  }

  Future<void> reOrderTab(int oldIndex, int newIndex) async {
    log.info('Reorder home tab, oldIndex:$oldIndex, newIndex:$newIndex');

    final TabBarConfig tab = tabBarConfigs.removeAt(oldIndex);
    tabBarConfigs.insert(newIndex, tab);
    await saveBeanConfig();
    updateSafely();
  }

  Future<void> toggleHidden(TabBarConfig tab) async {
    if (!tab.hidden && !canRemoveVisibleTab) {
      toast('cantRemoveLastVisibleTab'.tr, isShort: false);
      return;
    }

    log.info('${tab.hidden ? 'Unhide' : 'Hide'} home tab: ${tab.name}');

    tab.hidden = !tab.hidden;
    await saveBeanConfig();
    updateSafely();
  }

  /// pure persistence, no UI update needed
  Future<void> saveLastIndex(int index) async {
    lastIndex = index;
    await saveBeanConfig();
  }
}

List<TabBarConfig> defaultTabs() {
  return [
    TabBarConfig(id: newUUID(), name: 'Gallery', searchConfig: SearchConfig(), isDeleteAble: false),
    TabBarConfig(id: newUUID(), name: 'Chinese', searchConfig: SearchConfig(language: 'chinese')),
  ];
}
