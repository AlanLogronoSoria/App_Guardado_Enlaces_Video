import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/category_icons.dart';

class LinkModel {
  final String id;
  final String url;
  final String platform;
  final String title;
  final String? thumbnail;
  final String category;
  final bool favorite;
  final String? notes;
  final String? source;
  final DateTime createdAt;
  final DateTime updatedAt;

  LinkModel({
    required this.id,
    required this.url,
    required this.platform,
    required this.title,
    this.thumbnail,
    required this.category,
    this.favorite = false,
    this.notes,
    this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  LinkModel copyWith({
    String? id,
    String? url,
    String? platform,
    String? title,
    String? thumbnail,
    String? category,
    bool? favorite,
    String? notes,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LinkModel(
      id: id ?? this.id,
      url: url ?? this.url,
      platform: platform ?? this.platform,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      category: category ?? this.category,
      favorite: favorite ?? this.favorite,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'platform': platform,
      'title': title,
      'thumbnail': thumbnail,
      'category': category,
      'favorite': favorite,
      'notes': notes,
      'source': source,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LinkModel.fromMap(Map<String, dynamic> map) {
    return LinkModel(
      id: map['id'] as String,
      url: map['url'] as String,
      platform: map['platform'] as String,
      title: map['title'] as String,
      thumbnail: map['thumbnail'] as String?,
      category: map['category'] as String,
      favorite: map['favorite'] == 1 || map['favorite'] == true,
      notes: map['notes'] as String?,
      source: map['source'] as String?,
      createdAt: _parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  String toJson() => json.encode(toMap());

  factory LinkModel.fromJson(String source) =>
      LinkModel.fromMap(json.decode(source) as Map<String, dynamic>);
}

class CategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    required this.createdAt,
  });

  IconData get iconData => iconDataFromName(icon);
  Color? get displayColor => color != null ? Color(int.parse(color!, radix: 16)) : null;

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      createdAt: _parseDate(map['created_at'] ?? map['createdAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  String toJson() => json.encode(toMap());

  factory CategoryModel.fromJson(String source) =>
      CategoryModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
