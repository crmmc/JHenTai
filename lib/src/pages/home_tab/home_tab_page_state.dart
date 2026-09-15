import 'package:flutter/material.dart';
import 'package:jhentai/src/utils/uuid_util.dart';

import 'home_gallery_tab_logic.dart';

class HomeTabPageState {
  /// per-tab list logics, keyed by tab id; hidden tabs keep their state
  final Map<String, HomeGalleryTabLogic> tabLogics = {};

  int currentTabIndex = 0;
  PageController pageController = PageController();
  Key pageViewKey = Key(newUUID());
}
