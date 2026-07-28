import 'package:flutter/material.dart';

const Map<String, IconData> categoryIcons = {
  'folder': Icons.folder,
  'fitness_center': Icons.fitness_center,
  'sports_esports': Icons.sports_esports,
  'code': Icons.code,
  'music_note': Icons.music_note,
  'school': Icons.school,
  'restaurant': Icons.restaurant,
  'movie': Icons.movie,
  'camera_alt': Icons.camera_alt,
  'photo': Icons.photo,
  'videocam': Icons.videocam,
  'headphones': Icons.headphones,
  'book': Icons.book,
  'lightbulb': Icons.lightbulb,
  'star': Icons.star,
  'favorite': Icons.favorite,
  'thumb_up': Icons.thumb_up,
  'public': Icons.public,
  'travel_explore': Icons.travel_explore,
  'rocket_launch': Icons.rocket_launch,
  'palette': Icons.palette,
  'shopping_cart': Icons.shopping_cart,
  'build': Icons.build,
  'gamepad': Icons.gamepad,
  'work': Icons.work,
  'home': Icons.home,
  'pets': Icons.pets,
  'mic': Icons.mic,
};

const String defaultCategoryIconName = 'folder';

IconData iconDataFromName(String? name) {
  if (name == null) return Icons.folder;
  return categoryIcons[name] ?? Icons.folder;
}

String iconNameFromIconData(IconData icon) {
  for (final entry in categoryIcons.entries) {
    if (entry.value.codePoint == icon.codePoint) {
      return entry.key;
    }
  }
  return defaultCategoryIconName;
}

const List<String> availableIconNames = [
  'folder', 'fitness_center', 'sports_esports', 'code',
  'music_note', 'school', 'restaurant', 'movie',
  'camera_alt', 'photo', 'videocam', 'headphones',
  'book', 'lightbulb', 'star', 'favorite',
  'thumb_up', 'public', 'travel_explore', 'rocket_launch',
  'palette', 'shopping_cart', 'build', 'gamepad',
  'work', 'home', 'pets', 'mic',
];
