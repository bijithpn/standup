import 'package:flutter/cupertino.dart';

/// Icons a user can give a custom budget category, with search keywords; appended only so stored indices stay valid.
const List<(IconData, String, String)> kBudgetIconSet =
    <(IconData, String, String)>[
      (
        CupertinoIcons.chevron_left_slash_chevron_right,
        'chevron left slash chevron right',
        'code dev programming',
      ),
      (CupertinoIcons.doc_text, 'doc text', 'write document text'),
      (CupertinoIcons.globe, 'globe', 'browse web internet'),
      (CupertinoIcons.paintbrush, 'paintbrush', 'design paint art'),
      (CupertinoIcons.video_camera, 'video camera', 'video meeting call'),
      (CupertinoIcons.chat_bubble_2, 'chat bubble 2', 'chat message social'),
      (CupertinoIcons.mail, 'mail', 'email mail'),
      (CupertinoIcons.book, 'book', 'read book study'),
      (CupertinoIcons.music_note, 'music note', 'music audio'),
      (CupertinoIcons.game_controller, 'game controller', 'game gaming play'),
      (CupertinoIcons.camera, 'camera', 'photo camera'),
      (CupertinoIcons.chart_bar, 'chart bar', 'analytics chart data'),
      (CupertinoIcons.hammer, 'hammer', 'build tools'),
      (CupertinoIcons.lightbulb, 'lightbulb', 'idea think'),
      (CupertinoIcons.cart, 'cart', 'shopping store'),
      (CupertinoIcons.person_2, 'person 2', 'people team social'),
      (CupertinoIcons.heart, 'heart', 'health love'),
      (CupertinoIcons.star, 'star', 'favorite star'),
      (CupertinoIcons.briefcase, 'briefcase', 'work business'),
      (CupertinoIcons.pencil, 'pencil', 'edit write'),
      (CupertinoIcons.tv, 'tv', 'watch tv stream'),
      (CupertinoIcons.cloud, 'cloud', 'cloud storage'),
      (CupertinoIcons.bolt, 'bolt', 'energy fast'),
      (CupertinoIcons.square_grid_2x2, 'square grid 2x2', 'apps grid'),
      (CupertinoIcons.wrench, 'wrench', 'fix settings tools'),
      (CupertinoIcons.bookmark, 'bookmark', 'save bookmark'),
      (CupertinoIcons.calendar, 'calendar', 'calendar plan schedule'),
      (CupertinoIcons.phone, 'phone', 'phone call'),
      (CupertinoIcons.photo, 'photo', 'photos images'),
      (CupertinoIcons.headphones, 'headphones', 'listen podcast audio'),
      (CupertinoIcons.desktopcomputer, 'desktopcomputer', 'desktop computer'),
      (
        CupertinoIcons.device_phone_portrait,
        'device phone portrait',
        'mobile phone',
      ),
      (CupertinoIcons.flame, 'flame', 'hot trending'),
      (CupertinoIcons.flag, 'flag', 'goal target'),
      (CupertinoIcons.gift, 'gift', 'gift reward'),
      (CupertinoIcons.bag, 'bag', 'shopping bag'),
      (CupertinoIcons.creditcard, 'creditcard', 'finance payment'),
      (CupertinoIcons.money_dollar, 'money dollar', 'money finance'),
      (CupertinoIcons.house, 'house', 'home house'),
      (CupertinoIcons.map, 'map', 'map travel'),
      (CupertinoIcons.location, 'location', 'location place'),
      (CupertinoIcons.car, 'car', 'car drive'),
      (CupertinoIcons.airplane, 'airplane', 'travel flight'),
      (CupertinoIcons.bus, 'bus', 'transit bus'),
      (CupertinoIcons.sportscourt, 'sportscourt', 'sport fitness'),
      (CupertinoIcons.alarm, 'alarm', 'alarm time'),
      (CupertinoIcons.timer, 'timer', 'timer focus'),
      (CupertinoIcons.clock, 'clock', 'clock time'),
      (CupertinoIcons.gear, 'gear', 'settings system'),
      (CupertinoIcons.chart_pie, 'chart pie', 'chart report'),
      (CupertinoIcons.folder, 'folder', 'files folder'),
      (CupertinoIcons.tray, 'tray', 'inbox tray'),
      (CupertinoIcons.archivebox, 'archivebox', 'archive box'),
      (CupertinoIcons.paperplane, 'paperplane', 'send message'),
      (CupertinoIcons.search, 'search', 'search find'),
      (CupertinoIcons.cube, 'cube', '3d model'),
      (CupertinoIcons.moon, 'moon', 'night sleep'),
      (CupertinoIcons.sun_max, 'sun max', 'day sun'),
      (CupertinoIcons.drop, 'drop', 'water hydrate'),
      (CupertinoIcons.paw, 'paw', 'pet animal'),
      (CupertinoIcons.tickets, 'tickets', 'tickets event'),
      (CupertinoIcons.mic, 'mic', 'voice record'),
      (CupertinoIcons.speaker_2, 'speaker 2', 'sound speaker'),
      (CupertinoIcons.smiley, 'smiley', 'fun happy'),
      (CupertinoIcons.hand_thumbsup, 'hand thumbsup', 'like approve'),
      (CupertinoIcons.sparkles, 'sparkles', 'magic ai'),
      (CupertinoIcons.scissors, 'scissors', 'cut edit'),
      (CupertinoIcons.printer, 'printer', 'print'),
      (CupertinoIcons.lock, 'lock', 'private lock'),
      (CupertinoIcons.shield, 'shield', 'security safe'),
      (CupertinoIcons.wifi, 'wifi', 'network wifi'),
      (CupertinoIcons.pin, 'pin', 'pin place'),
      (CupertinoIcons.link, 'link', 'link url'),
      (CupertinoIcons.textformat, 'textformat', 'text type'),
      (CupertinoIcons.quote_bubble, 'quote bubble', 'quote comment'),
      (CupertinoIcons.lab_flask, 'lab flask', 'science lab'),
      (CupertinoIcons.film, 'film', 'movie film'),
      (CupertinoIcons.rosette, 'rosette', 'award badge'),
      (CupertinoIcons.compass, 'compass', 'explore compass'),
      (CupertinoIcons.scope, 'scope', 'focus scope'),
      (CupertinoIcons.tag, 'tag', 'tag label'),
      (CupertinoIcons.trash, 'trash', 'delete clean'),
      (CupertinoIcons.bell, 'bell', 'notify bell'),
      (CupertinoIcons.eye, 'eye', 'view watch'),
      (CupertinoIcons.hand_raised, 'hand raised', 'stop hand'),
      (CupertinoIcons.infinite, 'infinite', 'loop infinite'),
      (CupertinoIcons.wand_stars, 'wand stars', 'magic wand'),
      (CupertinoIcons.waveform, 'waveform', 'audio wave'),
      (
        CupertinoIcons.slider_horizontal_3,
        'slider horizontal 3',
        'controls mixer',
      ),
      (CupertinoIcons.layers, 'layers', 'layers stack'),
    ];

final List<IconData> kBudgetIcons = <IconData>[
  for (final i in kBudgetIconSet) i.$1,
];

/// A user-defined budget: a named group of apps with its own icon and daily limit.
class CustomBudgetCategory {
  const CustomBudgetCategory({
    required this.id,
    required this.name,
    required this.iconIndex,
    required this.appNames,
    required this.minutes,
  });

  final String id;
  final String name;
  final int iconIndex;
  final List<String> appNames;
  final int minutes;

  IconData get icon =>
      kBudgetIcons[iconIndex.clamp(0, kBudgetIcons.length - 1)];

  CustomBudgetCategory copyWith({
    String? name,
    int? iconIndex,
    List<String>? appNames,
    int? minutes,
  }) => CustomBudgetCategory(
    id: id,
    name: name ?? this.name,
    iconIndex: iconIndex ?? this.iconIndex,
    appNames: appNames ?? this.appNames,
    minutes: minutes ?? this.minutes,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'icon': iconIndex,
    'apps': appNames,
    'minutes': minutes,
  };

  static CustomBudgetCategory? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String || name.trim().isEmpty) return null;
    return CustomBudgetCategory(
      id: id,
      name: name,
      iconIndex: (raw['icon'] as num?)?.toInt() ?? 0,
      appNames: <String>[
        for (final a in (raw['apps'] as List? ?? const [])) a.toString(),
      ],
      minutes: (raw['minutes'] as num?)?.toInt() ?? 0,
    );
  }

  static List<CustomBudgetCategory> listFromJson(Object? raw) =>
      <CustomBudgetCategory>[
        if (raw is List)
          for (final item in raw) ?tryFromJson(item),
      ];
}
