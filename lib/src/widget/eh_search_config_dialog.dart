import 'package:flutter/rendering.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import 'eh_search_filter_panel.dart';

enum EHSearchConfigDialogType { update, add, filter }

class EHSearchConfigDialog extends StatefulWidget {
  final EHSearchConfigDialogType type;
  final String? quickSearchName;
  final SearchConfig? searchConfig;

  const EHSearchConfigDialog({Key? key, required this.type, this.quickSearchName, this.searchConfig}) : super(key: key);

  @override
  _EHSearchConfigDialogState createState() => _EHSearchConfigDialogState();
}

class _EHSearchConfigDialogState extends State<EHSearchConfigDialog> {
  String? quickSearchName;
  late SearchConfig searchConfig;

  final ScrollController _bodyScrollController = ScrollController();
  final GlobalKey<EHSearchFilterPanelState> _panelKey = GlobalKey<EHSearchFilterPanelState>();

  @override
  void initState() {
    super.initState();

    if (widget.searchConfig == null) {
      searchConfig = SearchConfig();
    } else {
      searchConfig = widget.searchConfig!.copyWith();
    }

    quickSearchName = widget.quickSearchName;
  }

  @override
  void dispose() {
    _bodyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        height: searchConfig.searchType == SearchType.favorite ? 400 : 500,
        width: 200,
        padding: const EdgeInsets.only(top: 24, bottom: 24, left: 12, right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildHeader(),
            Expanded(child: buildBody()),
          ],
        ),
      ),
    ).enableMouseDrag(withScrollBar: false);
  }

  Widget buildHeader() {
    String title = () {
      switch (widget.type) {
        case EHSearchConfigDialogType.update:
          return 'updateQuickSearch'.tr;
        case EHSearchConfigDialogType.add:
          return 'addQuickSearch'.tr;
        case EHSearchConfigDialogType.filter:
          return 'filter'.tr;
      }
    }();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.type == EHSearchConfigDialogType.update) IconButton(icon: const Icon(Icons.delete), onPressed: _handleDeleteConfig),
        if (widget.type == EHSearchConfigDialogType.filter) IconButton(icon: const Icon(Icons.refresh), onPressed: _resetAllConfig),
        if (widget.type == EHSearchConfigDialogType.add) const IconButton(icon: Icon(Icons.close), onPressed: backRoute),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.check), onPressed: checkAndBack),
      ],
    );
  }

  Widget buildBody() {
    return EHWheelSpeedController(
      controller: _bodyScrollController,
      child: ListView(
        controller: _bodyScrollController,
        scrollCacheExtent: ScrollCacheExtent.pixels(3000),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          if (widget.type != EHSearchConfigDialogType.filter) _buildSearchConfigName(),
          if (widget.type == EHSearchConfigDialogType.add) _buildSearchTypeSelector().marginOnly(top: 16),
          EHSearchFilterPanel(key: _panelKey, searchConfig: searchConfig).marginOnly(top: 20),
        ],
      ),
    );
  }

  Widget _buildSearchConfigName() {
    return TextField(
      decoration: InputDecoration(
        isDense: true,
        alignLabelWithHint: true,
        labelText: 'quickSearchName'.tr,
        labelStyle: const TextStyle(fontSize: 12),
      ),
      controller: TextEditingController(text: quickSearchName),
      onChanged: (title) => quickSearchName = title,
    );
  }

  Widget _buildSearchTypeSelector() {
    return Center(
      child: CupertinoSlidingSegmentedControl<SearchType>(
        groupValue: searchConfig.searchType,
        children: {
          SearchType.gallery: ConstrainedBox(constraints: const BoxConstraints(minWidth: 44), child: Center(child: Text('gallery'.tr))),
          SearchType.favorite: ConstrainedBox(constraints: const BoxConstraints(minWidth: 44), child: Center(child: Text('favorite'.tr))),
          SearchType.watched: ConstrainedBox(constraints: const BoxConstraints(minWidth: 44), child: Center(child: Text('watched'.tr))),
        },
        onValueChanged: (type) => setState(() => searchConfig.searchType = type!),
      ),
    );
  }

  void _resetAllConfig() {
    _panelKey.currentState?.reset();
  }

  Future<void> _handleDeleteConfig() async {
    bool? result = await Get.dialog(EHDialog(title: 'delete'.tr + '?'));

    if (result == true) {
      quickSearchService.removeQuickSearch(quickSearchName!);
      backRoute();
    }
  }

  void checkAndBack() {
    if (widget.type == EHSearchConfigDialogType.filter) {
      backRoute(result: {'searchConfig': searchConfig, 'quickSearchName': quickSearchName});
      return;
    }

    if (quickSearchName?.isEmpty ?? true) {
      toast('pleaseInputValidName'.tr);
      return;
    }

    backRoute(result: {'searchConfig': searchConfig, 'quickSearchName': quickSearchName});
  }
}
