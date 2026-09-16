import 'package:animate_do/animate_do.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/search/mixin/search_page_mixin.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:throttling/throttling.dart';

import '../config/ui_config.dart';
import '../consts/locale_consts.dart';
import '../database/database.dart';
import '../model/eh_raw_tag.dart';
import '../network/eh_request.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/toast_util.dart';
import '../service/log.dart';
import 'eh_gallery_category_tag.dart';
import 'eh_wheel_speed_controller.dart';

/// Embeddable search filter panel.
/// Hosts pass a mutable [SearchConfig] copy which the panel edits in place;
/// hosts read the same object back on confirm and discard it on cancel.
/// The panel is not scrollable by itself; hosts must provide a scrollable ancestor.
class EHSearchFilterPanel extends StatefulWidget {
  final SearchConfig searchConfig;

  const EHSearchFilterPanel({Key? key, required this.searchConfig}) : super(key: key);

  @override
  EHSearchFilterPanelState createState() => EHSearchFilterPanelState();
}

class EHSearchFilterPanelState extends State<EHSearchFilterPanel> {
  /// same visual order as the former dialog category area
  static const List<String> _categories = [
    'Doujinshi', 'Manga',
    'Image Set', 'Game CG',
    'Artist CG', 'Cosplay',
    'Non-H', 'Asian Porn',
    'Western', 'Misc',
  ];

  final ScrollController _suggestionScrollController = ScrollController();

  bool _isShowingSuggestions = false;
  List<TagAutoCompletionMatch> suggestions = [];
  Debouncing debouncing = Debouncing(duration: const Duration(milliseconds: 300));

  LayerLink layerLink = LayerLink();
  OverlayEntry? overlayEntry;
  FocusNode focusNode = FocusNode();
  bool isDoubleBackspace = false;

  bool _advancedExpanded = false;

  @override
  void initState() {
    super.initState();
    // Expand the advanced section when the loaded config already has advanced fields set,
    // so users editing an existing tab/filter see their previous choices instead of a closed panel.
    _advancedExpanded = _hasAdvancedConfig(widget.searchConfig);
  }

  bool _hasAdvancedConfig(SearchConfig config) {
    return config.language != null
        || config.onlySearchExpungedGalleries
        || config.onlyShowGalleriesWithTorrents
        || config.pageAtLeast != null
        || config.pageAtMost != null
        || config.minimumRating > 1
        || config.disableFilterForLanguage
        || config.disableFilterForUploader
        || config.disableFilterForTags;
  }

  @override
  void dispose() {
    debouncing.close();
    overlayEntry?.remove();
    overlayEntry?.dispose();
    _suggestionScrollController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  /// reset all filter fields, keep searchType
  void reset() {
    hideSuggestions();
    setState(() {
      widget.searchConfig.reset();
      suggestions.clear();
      isDoubleBackspace = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.searchConfig.searchType == SearchType.favorite) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFavoriteTags(),
          _buildKeywordTextField().marginOnly(top: 20),
          _buildFavoriteHint().marginOnly(top: 8),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCategoryTags(),
        _buildKeywordTextField().marginOnly(top: 12),
        _buildAdvancedSection().marginOnly(top: 8),
      ],
    );
  }

  Widget _buildCategoryTags() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _categories.length; i += 2)
          Row(
            children: [
              Expanded(child: _buildCategoryTag(_categories[i])),
              const SizedBox(width: 4),
              Expanded(child: _buildCategoryTag(_categories[i + 1])),
            ],
          ).marginOnly(top: i == 0 ? 0 : 4),
      ],
    );
  }

  Widget _buildCategoryTag(String category) {
    return EHGalleryCategoryTag(
      category: category,
      height: 30,
      enabled: _isCategoryEnabled(category),
      textStyle: const TextStyle(height: 1, fontSize: 16, color: UIConfig.galleryCategoryTagTextColor),
      onTap: () => setState(() => _setCategoryEnabled(category, !_isCategoryEnabled(category))),
      onLongPress: () => setState(() => _enableOnlyCategory(category)),
      onSecondaryTap: () => setState(() => _enableOnlyCategory(category)),
    );
  }

  Widget _buildFavoriteTags() {
    return Column(
      children: [0, 2, 4, 6, 8]
          .map((tagIndex) => Row(
                children: [
                  Expanded(
                    child: _buildFavoriteTag(
                      category: favoriteSetting.favoriteTagNames[tagIndex],
                      enabled: (widget.searchConfig.searchFavoriteCategoryIndex ?? tagIndex) == tagIndex,
                      color: UIConfig.favoriteTagColor[tagIndex],
                      onTap: () => setState(() {
                        if (widget.searchConfig.searchFavoriteCategoryIndex == tagIndex) {
                          widget.searchConfig.searchFavoriteCategoryIndex = null;
                        } else {
                          widget.searchConfig.searchFavoriteCategoryIndex = tagIndex;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildFavoriteTag(
                      category: favoriteSetting.favoriteTagNames[tagIndex + 1],
                      enabled: (widget.searchConfig.searchFavoriteCategoryIndex ?? tagIndex + 1) == tagIndex + 1,
                      color: UIConfig.favoriteTagColor[tagIndex + 1],
                      onTap: () => setState(() {
                        if (widget.searchConfig.searchFavoriteCategoryIndex == tagIndex + 1) {
                          widget.searchConfig.searchFavoriteCategoryIndex = null;
                        } else {
                          widget.searchConfig.searchFavoriteCategoryIndex = tagIndex + 1;
                        }
                      }),
                    ),
                  ),
                ],
              ).marginOnly(top: tagIndex == 0 ? 0 : 4))
          .toList(),
    );
  }

  Widget _buildFavoriteTag({
    required String category,
    required bool enabled,
    Color? color,
    VoidCallback? onTap,
  }) {
    return EHGalleryCategoryTag(
      category: category,
      height: 30,
      enabled: enabled,
      color: color,
      textStyle: const TextStyle(height: 1, fontSize: 16, color: UIConfig.galleryCategoryTagTextColor),
      onTap: onTap,
    );
  }

  Widget _buildKeywordTextField() {
    SearchConfig searchConfig = widget.searchConfig;
    return CompositedTransformTarget(
      link: layerLink,
      child: KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: _handleDeleteTag,
        child: TextField(
          decoration: InputDecoration(
            isDense: true,
            alignLabelWithHint: true,
            labelText: 'keyword'.tr,
            labelStyle: const TextStyle(fontSize: 12),
            helperText: searchConfig.computeTagKeywords(withTranslation: true, separator: '  /  '),
            helperMaxLines: 99,
            hintText: searchConfig.tags?.isEmpty ?? true ? null : 'backspace2DeleteTag'.tr,
            hintStyle: TextStyle(fontSize: 12, color: UIConfig.searchConfigDialogFieldHintTextColor(context)),
          ),
          controller: TextEditingController.fromValue(
            TextEditingValue(
              text: searchConfig.keyword ?? '',

              /// make cursor stay at last letter
              selection: TextSelection.fromPosition(TextPosition(offset: searchConfig.keyword?.length ?? 0)),
            ),
          ),
          onTap: hideSuggestions,
          onChanged: (keyword) {
            searchConfig.keyword = keyword;
            waitAndSearchTags(keyword);
          },
          onSubmitted: (keyword) {
            searchConfig.keyword = '';
            hideSuggestions();

            if (keyword.isEmpty) {
              return;
            }

            /// simulate a TagData
            addSearchTag(TagData(namespace: '', key: keyword));
          },
        ),
      ),
    );
  }

  Widget _buildFavoriteHint() {
    return Text(
      'favoriteHint'.tr,
      style: TextStyle(
        fontSize: 12,
        height: 1.6,
        color: UIConfig.searchConfigDialogHintTextColor,
      ),
    );
  }

  OverlayEntry _buildSuggestions(String keyword) {
    return OverlayEntry(
      builder: (BuildContext overlayContext) => UnconstrainedBox(
        child: CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          child: Material(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280 - 24 - 20, maxHeight: 150),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: UIConfig.searchConfigDialogSuggestionShadowColor(overlayContext),
                    blurRadius: 4,
                    blurStyle: BlurStyle.outer,
                  )
                ],
              ),
              child: SearchSuggestionList(
                scrollController: _suggestionScrollController,
                currentKeyword: keyword,
                suggestions: suggestions,
                onTapSuggestion: (TagData tagData) {
                  hideSuggestions();
                  widget.searchConfig.keyword = '';
                  addSearchTag(tagData);
                },
              ),
            ).fadeIn(),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('advanced'.tr, style: const TextStyle(fontSize: 15)),
          trailing: Switch(
            value: _advancedExpanded,
            onChanged: (bool value) => setState(() => _advancedExpanded = value),
          ),
          onTap: () => setState(() => _advancedExpanded = !_advancedExpanded),
        ),
        if (_advancedExpanded)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageSelector(),
              _buildSearchExpungedGalleriesSwitch(),
              _buildOnlySearchGalleriesWithTorrentsSwitch(),
              _buildPageRangeSelector(),
              _buildRatingSelector(),
              _buildDisableFilterForLanguageSwitch(),
              _buildDisableFilterForUploaderSwitch(),
              _buildDisableFilterForTagsSwitch(),
            ],
          ),
      ],
    );
  }

  Widget _buildLanguageSelector() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('language'.tr, style: const TextStyle(fontSize: 15)),
      trailing: DropdownButton<String?>(
        value: widget.searchConfig.language,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (String? newValue) => setState(() => widget.searchConfig.language = newValue),
        menuMaxHeight: 200,
        items: [
          DropdownMenuItem(child: Text('nope'.tr), value: null),
          ...LocaleConsts.language2Abbreviation.keys
              .where((language) => language != 'japanese')
              .map((language) => DropdownMenuItem(child: Text(language.capitalizeFirst!), value: language))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildSearchExpungedGalleriesSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('onlySearchExpungedGalleries'.tr, style: const TextStyle(fontSize: 15)),
      trailing: Switch(
        value: widget.searchConfig.onlySearchExpungedGalleries,
        onChanged: (bool value) => setState(() => widget.searchConfig.onlySearchExpungedGalleries = value),
      ),
    );
  }

  Widget _buildOnlySearchGalleriesWithTorrentsSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('onlyShowGalleriesWithTorrents'.tr, style: const TextStyle(fontSize: 15)),
      trailing: Switch(
        value: widget.searchConfig.onlyShowGalleriesWithTorrents,
        onChanged: (bool value) => setState(() => widget.searchConfig.onlyShowGalleriesWithTorrents = value),
      ),
    );
  }

  Widget _buildPageRangeSelector() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('pagesBetween'.tr, style: const TextStyle(fontSize: 15)),
          GestureDetector(
            child: const Icon(Icons.help, size: 15).marginOnly(left: 4),
            onTap: () => toast('pageRangeSelectHint'.tr, isShort: false),
          ),
        ],
      ),
      trailing: SizedBox(
        width: 110,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 40,
              child: CupertinoTextField(
                controller: TextEditingController(text: widget.searchConfig.pageAtLeast?.toString()),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d'))],
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                onChanged: (value) => widget.searchConfig.pageAtLeast = value.isEmpty ? null : int.parse(value),
              ),
            ),
            Text('to'.tr),
            SizedBox(
              width: 40,
              child: CupertinoTextField(
                controller: TextEditingController(text: widget.searchConfig.pageAtMost?.toString()),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d'))],
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                onChanged: (value) => widget.searchConfig.pageAtMost = value.isEmpty ? null : int.parse(value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSelector() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('minimumRating'.tr, style: const TextStyle(fontSize: 15)),
      trailing: SizedBox(
        width: 50,
        child: DropdownButton<int>(
          value: widget.searchConfig.minimumRating,
          elevation: 4,
          onChanged: (int? newValue) {
            setState(() {
              widget.searchConfig.minimumRating = newValue!;
            });
          },
          items: const [
            DropdownMenuItem(child: Text('1'), value: 1),
            DropdownMenuItem(child: Text('2'), value: 2),
            DropdownMenuItem(child: Text('3'), value: 3),
            DropdownMenuItem(child: Text('4'), value: 4),
            DropdownMenuItem(child: Text('5'), value: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildDisableFilterForLanguageSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('disableFilterForLanguage'.tr, style: const TextStyle(fontSize: 15)),
      trailing: Switch(
        value: widget.searchConfig.disableFilterForLanguage,
        onChanged: (bool value) => setState(() => widget.searchConfig.disableFilterForLanguage = value),
      ),
    );
  }

  Widget _buildDisableFilterForUploaderSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('disableFilterForUploader'.tr, style: const TextStyle(fontSize: 15)),
      trailing: Switch(
        value: widget.searchConfig.disableFilterForUploader,
        onChanged: (bool value) => setState(() => widget.searchConfig.disableFilterForUploader = value),
      ),
    );
  }

  Widget _buildDisableFilterForTagsSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('disableFilterForTags'.tr, style: const TextStyle(fontSize: 15)),
      trailing: Switch(
        value: widget.searchConfig.disableFilterForTags,
        onChanged: (bool value) => setState(() => widget.searchConfig.disableFilterForTags = value),
      ),
    );
  }

  bool _isCategoryEnabled(String category) {
    SearchConfig config = widget.searchConfig;
    switch (category) {
      case 'Doujinshi':
        return config.includeDoujinshi;
      case 'Manga':
        return config.includeManga;
      case 'Image Set':
        return config.includeImageSet;
      case 'Game CG':
        return config.includeGameCg;
      case 'Artist CG':
        return config.includeArtistCG;
      case 'Cosplay':
        return config.includeCosplay;
      case 'Non-H':
        return config.includeNonH;
      case 'Asian Porn':
        return config.includeAsianPorn;
      case 'Western':
        return config.includeWestern;
      case 'Misc':
        return config.includeMisc;
      default:
        return true;
    }
  }

  void _setCategoryEnabled(String category, bool enabled) {
    SearchConfig config = widget.searchConfig;
    switch (category) {
      case 'Doujinshi':
        config.includeDoujinshi = enabled;
        break;
      case 'Manga':
        config.includeManga = enabled;
        break;
      case 'Image Set':
        config.includeImageSet = enabled;
        break;
      case 'Game CG':
        config.includeGameCg = enabled;
        break;
      case 'Artist CG':
        config.includeArtistCG = enabled;
        break;
      case 'Cosplay':
        config.includeCosplay = enabled;
        break;
      case 'Non-H':
        config.includeNonH = enabled;
        break;
      case 'Asian Porn':
        config.includeAsianPorn = enabled;
        break;
      case 'Western':
        config.includeWestern = enabled;
        break;
      case 'Misc':
        config.includeMisc = enabled;
        break;
    }
  }

  /// long press: only keep this category on, all others off
  void _enableOnlyCategory(String category) {
    widget.searchConfig.disableAllCategories();
    _setCategoryEnabled(category, true);
  }

  /// double backspace to delete last selected tag
  void _handleDeleteTag(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return;
    }
    if (widget.searchConfig.keyword?.isNotEmpty ?? false) {
      return;
    }
    if (widget.searchConfig.tags?.isEmpty ?? true) {
      return;
    }
    if (!isDoubleBackspace) {
      isDoubleBackspace = true;
      return;
    }
    isDoubleBackspace = false;
    setState(() => widget.searchConfig.tags!.removeLast());
  }

  /// search only if there's no timer active (300ms)
  Future<void> waitAndSearchTags(String keyword) async {
    if (keyword.isEmpty) {
      hideSuggestions();
      return;
    }

    /// only search after 300ms
    debouncing.debounce(() => searchTags(keyword));
  }

  Future<void> searchTags(String keyword) async {
    log.info('search for ${widget.searchConfig.keyword}');

    /// chinese => database; other => EH api
    if (tagTranslationService.isReady) {
      suggestions = await tagTranslationService.searchTags(keyword, limit: 100);
    } else {
      try {
        String lastPart = keyword.split(' ').last;
        String effectivePart = lastPart;
        String? operator;
        if (lastPart.startsWith('-') || lastPart.startsWith('~')) {
          operator = lastPart[0];
          effectivePart = lastPart.substring(1);
        }

        if (effectivePart.isEmpty) {
          suggestions = [];
        } else {
          List<EHRawTag> tags = await ehRequest.requestTagSuggestion(effectivePart, EHSpiderParser.tagSuggestion2TagList);
          suggestions = tags
              .map((t) => (
                    searchText: keyword,
                    matchStart: keyword.length - lastPart.length,
                    matchEnd: keyword.length,
                    tagData: TagData(namespace: t.namespace, key: t.key),
                    operator: operator,
                    score: 0.0,
                    namespaceMatch: t.namespace.contains(effectivePart)
                        ? (start: t.namespace.indexOf(effectivePart), end: t.namespace.indexOf(effectivePart) + effectivePart.length)
                        : null,
                    translatedNamespaceMatch: null,
                    keyMatch:
                        t.key.contains(effectivePart) ? (start: t.key.indexOf(effectivePart), end: t.key.indexOf(effectivePart) + effectivePart.length) : null,
                    tagNameMatch: null,
                  ))
              .toList();
        }
      } on DioException catch (e) {
        log.error('Request tag suggestion failed', e);
        suggestions = [];
      }
    }

    if (!mounted) {
      return;
    }

    showSuggestions(keyword);
  }

  void showSuggestions(String keyword) {
    if (_isShowingSuggestions) {
      overlayEntry?.remove();
    }

    overlayEntry = _buildSuggestions(keyword);
    Overlay.of(context).insert(overlayEntry!);

    _isShowingSuggestions = true;
  }

  void hideSuggestions() {
    overlayEntry?.remove();
    overlayEntry = null;
    _isShowingSuggestions = false;
  }

  void addSearchTag(TagData tag) {
    SearchConfig searchConfig = widget.searchConfig;
    searchConfig.tags ??= [];
    if (searchConfig.tags!.singleWhereOrNull((t) => t.namespace == tag.namespace && t.key == tag.key) != null) {
      return;
    }

    setState(() => searchConfig.tags!.add(tag));
  }
}

class SearchSuggestionList extends StatelessWidget {
  final String currentKeyword;
  final List<TagAutoCompletionMatch> suggestions;
  final ValueChanged<TagData> onTapSuggestion;
  final ScrollController scrollController;

  const SearchSuggestionList({
    Key? key,
    required this.currentKeyword,
    required this.suggestions,
    required this.onTapSuggestion,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EHWheelSpeedController(
      controller: scrollController,
      child: ListView.builder(
        itemCount: suggestions.length,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        controller: scrollController,
        itemBuilder: (_, index) {
          return FadeIn(
            duration: const Duration(milliseconds: 400),
            child: ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
              minVerticalPadding: 0,
              title: highlightRawTag(
                context,
                suggestions[index],
                TextStyle(fontSize: UIConfig.searchDialogSuggestionTitleTextSize, color: UIConfig.searchPageSuggestionTitleColor(context)),
                const TextStyle(fontSize: UIConfig.searchDialogSuggestionTitleTextSize, color: UIConfig.searchPageSuggestionHighlightColor),
                singleLine: true,
              ),
              subtitle: suggestions[index].tagData.tagName == null
                  ? null
                  : highlightTranslatedTag(
                      context,
                      suggestions[index],
                      TextStyle(fontSize: UIConfig.searchDialogSuggestionSubTitleTextSize, color: UIConfig.searchPageSuggestionSubTitleColor(context)),
                      const TextStyle(fontSize: UIConfig.searchDialogSuggestionSubTitleTextSize, color: UIConfig.searchPageSuggestionHighlightColor),
                      singleLine: true,
                    ),
              onTap: () => onTapSuggestion(suggestions[index].tagData),
            ),
          );
        },
      ),
    );
  }
}
