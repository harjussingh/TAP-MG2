/// A picture for a dish or ingredient, chosen from its name. The menu has no
/// photos yet, so this keeps every tile recognisable.
String foodEmoji(String name) {
  final n = name.toLowerCase();
  const table = <(String, String)>[
    ('build', '\u{1F963}'),
    ('salmon', '\u{1F41F}'),
    ('tuna', '\u{1F41F}'),
    ('poke', '\u{1F41F}'),
    ('chicken', '\u{1F357}'),
    ('beef', '\u{1F969}'),
    ('tofu', '\u{1F9C6}'),
    ('egg', '\u{1F95A}'),
    ('edamame', '\u{1FAD8}'),
    ('soup', '\u{1F35C}'),
    ('noodle', '\u{1F35C}'),
    ('udon', '\u{1F35C}'),
    ('tea', '\u{1F375}'),
    ('lemon', '\u{1F34B}'),
    ('quinoa', '\u{1F33E}'),
    ('brown rice', '\u{1F33E}'),
    ('rice', '\u{1F35A}'),
    ('greens', '\u{1F96C}'),
    ('cabbage', '\u{1F96C}'),
    ('corn', '\u{1F33D}'),
    ('cucumber', '\u{1F952}'),
    ('avocado', '\u{1F951}'),
    ('carrot', '\u{1F955}'),
    ('kimchi', '\u{1F336}'),
    ('sriracha', '\u{1F336}'),
    ('peanut', '\u{1F95C}'),
    ('sesame', '\u{1F330}'),
    ('spring onion', '\u{1F331}'),
    ('onion', '\u{1F9C5}'),
    ('nori', '\u{1F359}'),
    ('teriyaki', '\u{1F36F}'),
    ('ginger', '\u{1F36F}'),
    ('sauce', '\u{1F36F}'),
  ];
  for (final (key, emoji) in table) {
    if (n.contains(key)) return emoji;
  }
  return '\u{1F957}';
}

/// A stable, readable id from a name: "Brown Rice" -> "brown-rice". Used to
/// look up the curated ingredient colours, which are keyed this way.
String slugOf(String name) =>
    name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
