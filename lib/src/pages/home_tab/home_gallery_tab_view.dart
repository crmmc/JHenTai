import 'package:flutter/material.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/home_tab/home_gallery_tab_logic.dart';
import 'package:jhentai/src/pages/home_tab/home_gallery_tab_state.dart';

class HomeGalleryTabView extends BasePage<HomeGalleryTabLogic, HomeGalleryTabState> {
  const HomeGalleryTabView({Key? key, required this.logic}) : super(key: key, showScroll2TopButton: true);

  @override
  final HomeGalleryTabLogic logic;

  @override
  HomeGalleryTabState get state => logic.state;
}
