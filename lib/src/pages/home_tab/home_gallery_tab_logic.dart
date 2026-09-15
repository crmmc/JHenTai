import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/home_tab/home_gallery_tab_state.dart';

/// One gallery list per home tab. The [SearchConfig] comes from [HomeTabBarService],
/// not from the per-page searchConfig storage.
class HomeGalleryTabLogic extends BasePageLogic {
  final String tabId;

  /// the authoritative [SearchConfig] object from the tab config; replaced (not mutated) on tab edit
  SearchConfig searchConfig;

  @override
  bool get useSearchConfig => false;

  @override
  String get searchConfigKey => tabId;

  @override
  final HomeGalleryTabState state = HomeGalleryTabState();

  HomeGalleryTabLogic({required this.tabId, required this.searchConfig}) {
    state.searchConfig = searchConfig;
    state.pageStorageKey = PageStorageKey('HomeGalleryTabState::$tabId');
  }

  void updateSearchConfig(SearchConfig newConfig) {
    searchConfig = newConfig;
    state.searchConfig = newConfig;

    /// if the view has never been built, onInit will load with the new config by itself
    if (state.searchConfigInitCompleter.isCompleted) {
      handleClearAndRefresh();
    }
  }
}
