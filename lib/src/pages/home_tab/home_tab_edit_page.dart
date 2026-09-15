import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/model/tab_bar_config.dart';
import 'package:jhentai/src/service/home_tab_bar_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_search_filter_panel.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

/// Add a new home tab (arguments is null) or edit an existing one (arguments is a [TabBarConfig]).
class HomeTabEditPage extends StatefulWidget {
  const HomeTabEditPage({Key? key}) : super(key: key);

  @override
  State<HomeTabEditPage> createState() => _HomeTabEditPageState();
}

class _HomeTabEditPageState extends State<HomeTabEditPage> {
  TabBarConfig? tab;

  late SearchConfig searchConfig;
  String name = '';

  final ScrollController _bodyScrollController = ScrollController();
  final GlobalKey<EHSearchFilterPanelState> _panelKey = GlobalKey<EHSearchFilterPanelState>();

  @override
  void initState() {
    super.initState();

    Object? arguments = Get.arguments;
    if (arguments is TabBarConfig) {
      tab = arguments;
    }

    searchConfig = tab?.searchConfig.copyWith() ?? SearchConfig();
    name = tab?.name ?? '';
  }

  @override
  void dispose() {
    _bodyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(tab == null ? 'addHomeTab'.tr : 'editHomeTab'.tr),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _panelKey.currentState?.reset()),
          IconButton(icon: const Icon(Icons.check), onPressed: _handleSave),
        ],
      ),
      body: EHWheelSpeedController(
        controller: _bodyScrollController,
        child: ListView(
          controller: _bodyScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            _buildNameField(),
            EHSearchFilterPanel(key: _panelKey, searchConfig: searchConfig).marginOnly(top: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      decoration: InputDecoration(
        isDense: true,
        alignLabelWithHint: true,
        labelText: 'tabName'.tr,
        labelStyle: const TextStyle(fontSize: 12),
      ),
      controller: TextEditingController(text: name),
      onChanged: (value) => name = value,
    ).marginOnly(top: 12);
  }

  Future<void> _handleSave() async {
    if (name.trim().isEmpty) {
      toast('pleaseInputValidName'.tr);
      return;
    }

    if (tab == null) {
      await homeTabBarService.addTab(name.trim(), searchConfig);
    } else {
      await homeTabBarService.updateTab(tab!, name: name.trim(), searchConfig: searchConfig);
    }

    backRoute();
  }
}
