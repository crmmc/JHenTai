import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/utils/uuid_util.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class TabBarConfig {
  /// stable identity of the tab, used as per-tab list key
  String id;
  String name;
  SearchConfig searchConfig;
  bool hidden;
  bool isDeleteAble;
  bool isEditable;
  bool advancedExpanded;

  TabBarConfig({
    required this.id,
    required this.name,
    required this.searchConfig,
    this.hidden = false,
    this.isDeleteAble = true,
    this.isEditable = true,
    this.advancedExpanded = false,
  });

  factory TabBarConfig.fromJson(Map<String, dynamic> json) {
    return TabBarConfig(
      id: json['id'] ?? newUUID(),
      name: json["name"],
      searchConfig: SearchConfig.fromJson(json["searchConfig"]),
      hidden: json['hidden'] ?? false,
      isDeleteAble: json['isDeleteAble'] ?? true,
      isEditable: json['isEditable'] ?? true,
      advancedExpanded: json['advancedExpanded'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "searchConfig": searchConfig.toJson(),
      'hidden': hidden,
      'isDeleteAble': isDeleteAble,
      'isEditable': isEditable,
      'advancedExpanded': advancedExpanded,
    };
  }

  @override
  String toString() {
    return 'TabBarConfig{id: $id, name: $name, searchConfig: $searchConfig, hidden: $hidden, isDeleteAble: $isDeleteAble, isEditable: $isEditable, advancedExpanded: $advancedExpanded}';
  }
}
