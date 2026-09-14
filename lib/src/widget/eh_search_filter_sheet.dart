import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/search_config.dart';

import 'eh_search_filter_panel.dart';
import 'eh_wheel_speed_controller.dart';

/// Scrollable bottom sheet hosting [EHSearchFilterPanel], for filter-type editing on mobile.
class EHSearchFilterSheet extends StatefulWidget {
  final SearchConfig searchConfig;

  const EHSearchFilterSheet({Key? key, required this.searchConfig}) : super(key: key);

  static Future<Map<String, dynamic>?> show({required SearchConfig searchConfig}) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: Get.context!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EHSearchFilterSheet(searchConfig: searchConfig),
    );
  }

  @override
  _EHSearchFilterSheetState createState() => _EHSearchFilterSheetState();
}

class _EHSearchFilterSheetState extends State<EHSearchFilterSheet> {
  late SearchConfig searchConfig;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<EHSearchFilterPanelState> _panelKey = GlobalKey<EHSearchFilterPanelState>();

  @override
  void initState() {
    super.initState();
    searchConfig = widget.searchConfig.copyWith();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: (MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom) * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.refresh), onPressed: () => _panelKey.currentState?.reset()),
                  Text('filter'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.check), onPressed: _checkAndBack),
                ],
              ).marginOnly(left: 8, right: 8),
              Flexible(
                child: EHWheelSpeedController(
                  controller: _scrollController,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    children: [
                      EHSearchFilterPanel(key: _panelKey, searchConfig: searchConfig),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkAndBack() {
    Get.back(result: {'searchConfig': searchConfig, 'quickSearchName': null});
  }
}
