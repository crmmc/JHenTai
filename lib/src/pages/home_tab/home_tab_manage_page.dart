import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/tab_bar_config.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/home_tab_bar_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';

class HomeTabManagePage extends StatelessWidget {
  const HomeTabManagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('manageHomeTabs'.tr),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 24), onPressed: () => toRoute(Routes.homeTabEdit)),
        ],
      ),
      body: GetBuilder<HomeTabBarService>(
        builder: (_) => ReorderableListView.builder(
          itemCount: homeTabBarService.tabBarConfigs.length,
          onReorderItem: homeTabBarService.reOrderTab,
          padding: const EdgeInsets.only(bottom: 120),
          itemBuilder: (_, int index) {
            TabBarConfig tab = homeTabBarService.tabBarConfigs[index];
            return Column(
              key: Key(tab.id),
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  leading: tab.hidden ? const Icon(Icons.visibility_off) : null,
                  title: Text(
                    tab.hidden ? '${tab.name} (${'tabHidden'.tr})' : tab.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab.isEditable)
                        IconButton(icon: const Icon(Icons.settings), onPressed: () => toRoute(Routes.homeTabEdit, arguments: tab)),
                      IconButton(
                        icon: Icon(tab.hidden ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => homeTabBarService.toggleHidden(tab),
                      ),
                      if (tab.isDeleteAble)
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _handleDeleteTab(tab)),
                    ],
                  ),
                  onTap: tab.isEditable ? () => toRoute(Routes.homeTabEdit, arguments: tab) : null,
                ),
                const Divider(thickness: 0.7, height: 2),
              ],
            );
          },
        ).enableMouseDrag(),
      ),
    );
  }

  Future<void> _handleDeleteTab(TabBarConfig tab) async {
    if (!tab.hidden && !homeTabBarService.canRemoveVisibleTab) {
      toast('cantRemoveLastVisibleTab'.tr, isShort: false);
      return;
    }

    bool? result = await Get.dialog(EHDialog(title: '${'delete'.tr} ?'));

    if (result == true) {
      await homeTabBarService.removeTab(tab);
    }
  }
}
