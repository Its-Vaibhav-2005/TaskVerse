import 'package:flutter/material.dart';
import 'appearance.dart';

class ThemeGallery extends StatefulWidget {
  const ThemeGallery({super.key});
  @override
  State<ThemeGallery> createState() => _ThemeGalleryState();
}

class _ThemeGalleryState extends State<ThemeGallery> {
  String query = '';
  bool saving = false;
  Future<void> choose(ThemePreset theme) async {
    setState(() => saving = true);
    try {
      await appearance.setPreset(theme.name);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save theme.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget preview(Map<String, Color> p) => Container(
    decoration: BoxDecoration(
      color: p['background'],
      borderRadius: BorderRadius.circular(7),
    ),
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        Container(
          width: 20,
          decoration: BoxDecoration(
            color: p['selected'],
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (row) => Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      color: p['muted']!.withValues(alpha: .5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ...List.generate(
                    4,
                    (i) => Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: (i + row) % 3 == 0 ? p['selected'] : p['accent'],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget tile(ThemePreset t, Brightness brightness) {
    final p = t.palette(brightness), selected = t.name == appearance.presetName;
    return Semantics(
      selected: selected,
      button: true,
      label: t.name,
      child: Material(
        color: p['surface'],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? p['accent']! : p['border']!,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: saving ? null : () => choose(t),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p['text'],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, size: 17, color: p['accent']),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  t.group,
                  style: TextStyle(color: p['muted'], fontSize: 10),
                ),
                const SizedBox(height: 16),
                Expanded(child: preview(p)),
                const SizedBox(height: 12),
                Row(
                  children: ['background', 'surface', 'accent', 'text']
                      .map(
                        (key) => Container(
                          width: 16,
                          height: 6,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: p[key],
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: p['border']!),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final filtered = themePresets
        .where(
          (t) => '${t.name} ${t.group}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Find your atmosphere',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close themes',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '42 requested palettes + TrackVerse. Each includes light and dark modes.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search themes or collections',
                ),
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, size) => GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: size.maxWidth > 650
                          ? 3
                          : size.maxWidth > 400
                          ? 2
                          : 1,
                      mainAxisExtent: 190,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        tile(filtered[index], brightness),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
