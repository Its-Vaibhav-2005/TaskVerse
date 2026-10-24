import 'package:flutter/material.dart';
import 'appearance.dart';
import 'theme_gallery.dart';

class SettingsPage extends StatelessWidget {
  final Widget? cloudPanel;
  final String trackerName;
  final bool connected, busy, browserOnly;
  final ValueChanged<ThemeMode> onMode;
  final ValueChanged<int> onFontStep;
  final VoidCallback onExport, onRestore;
  const SettingsPage({
    super.key,
    this.cloudPanel,
    required this.trackerName,
    required this.connected,
    required this.busy,
    required this.browserOnly,
    required this.onMode,
    required this.onFontStep,
    required this.onExport,
    required this.onRestore,
  });

  Future<void> typography(
    BuildContext context, {
    String? family,
    int? step,
  }) async {
    try {
      await appearance.setTypography(family: family, step: step);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save typography. Please try again.'),
          ),
        );
      }
    }
  }

  Widget label(BuildContext context, String title, String detail) {
    final c = AppPalette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          style: TextStyle(color: c.muted, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }

  Widget settingRow(
    BuildContext context,
    String title,
    String detail,
    Widget control,
  ) => LayoutBuilder(
    builder: (context, size) {
      final text = label(context, title, detail);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: size.maxWidth >= 560
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 24),
                  control,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 14), control],
              ),
      );
    },
  );
  Widget card(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget child,
  ) {
    final c = AppPalette(context);
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.selected,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 18, color: c.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: TextStyle(color: c.muted, fontSize: 12, height: 1.5),
                ),
              ],
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget appearanceCard(BuildContext context) {
    final c = AppPalette(context);
    return card(
      context,
      Icons.palette_outlined,
      'Appearance',
      'Choose your atmosphere. Every theme supports light and dark.',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          settingRow(
            context,
            'Color mode',
            'System adapts to Windows automatically.',
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final mode in ThemeMode.values)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      mode == ThemeMode.system
                          ? Icons.brightness_auto_outlined
                          : mode == ThemeMode.light
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 16,
                    ),
                    label: Text(
                      mode == ThemeMode.system
                          ? 'System'
                          : mode == ThemeMode.light
                          ? 'Light'
                          : 'Dark',
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: appearance.mode == mode,
                    onSelected: (_) => onMode(mode),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          settingRow(
            context,
            'Theme collection',
            '42 inspired palettes + the TrackVerse original.',
            OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const ThemeGallery(),
              ),
              icon: const Icon(Icons.grid_view_rounded, size: 16),
              label: const Text('Browse 43 themes'),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.background,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                ...['background', 'surface', 'accent', 'text'].map(
                  (key) => Container(
                    width: 20,
                    height: 28,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: appearance.preset.palette(
                        Theme.of(context).brightness,
                      )[key],
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: c.border),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appearance.presetName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appearance.preset.group,
                        style: TextStyle(color: c.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle_outline, size: 17, color: c.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget typographyCard(BuildContext context) {
    final c = AppPalette(context);
    return card(
      context,
      Icons.text_fields_rounded,
      'Typography',
      'Fine-tune readability across your entire workspace.',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: LayoutBuilder(
              builder: (context, size) => Wrap(
                spacing: 16,
                runSpacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: size.maxWidth < 240 ? size.maxWidth : 220,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(appearance.fontFamily),
                      isExpanded: true,
                      initialValue: appearance.fontFamily,
                      decoration: const InputDecoration(
                        labelText: 'Font style',
                        isDense: true,
                      ),
                      items: Appearance.fonts
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(
                                f,
                                style: TextStyle(fontFamily: f, fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => typography(context, family: value),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Decrease font size by 1',
                          onPressed: appearance.fontStep > -2
                              ? () => onFontStep(-1)
                              : null,
                          icon: const Icon(Icons.text_decrease, size: 18),
                        ),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${appearance.fontStep >= 0 ? '+' : ''}${appearance.fontStep}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Increase font size by 1',
                          onPressed: appearance.fontStep < 4
                              ? () => onFontStep(1)
                              : null,
                          icon: const Icon(Icons.text_increase, size: 18),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        typography(context, family: 'Inter', step: 0),
                    child: const Text('Reset fonts'),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Small steps. Extraordinary you.',
                  style: TextStyle(
                    fontFamily: appearance.fontFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Live type preview · Bundled fonts work offline',
                  style: TextStyle(color: c.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget backupsCard(BuildContext context) {
    final c = AppPalette(context);
    return card(
      context,
      Icons.shield_outlined,
      'Data & privacy',
      browserOnly
          ? 'This browser preview stores data on this device.'
          : 'Your habits stay in a private SQLite database on this device.',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : onExport,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export backup'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onRestore,
                icon: const Icon(Icons.upload_outlined, size: 16),
                label: const Text('Restore backup'),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            'Keep a portable copy of your habits, month tabs, and focus sessions.',
            style: TextStyle(color: c.muted, fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget rulesCard(BuildContext context) {
    final c = AppPalette(context);
    return card(
      context,
      Icons.schedule_outlined,
      'Daily rhythm',
      'Your device sets the date. Only today’s check-ins can be changed.',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 14),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 15, color: c.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Past days stay protected',
                    style: TextStyle(color: c.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text(
                'How progress is calculated',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              children: [
                Text(
                  'Completion is completed check-ins ÷ scheduled check-ins through today. Future dates and dates before habit creation are excluded. Streaks follow scheduled days; an incomplete today only breaks a streak after the day ends.',
                  style: TextStyle(color: c.muted, fontSize: 11, height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'A workspace that feels like yours.',
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.selected,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: c.accent,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Saved automatically',
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (cloudPanel != null) ...[
              Material(
                color: c.surface,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: c.border),
                  borderRadius: BorderRadius.circular(13),
                ),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const PageStorageKey('settings-trackers'),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    leading: Icon(Icons.cloud_outlined, color: c.accent),
                    title: const Text(
                      'Trackers & cloud backup',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '$trackerName · ${connected ? 'Google connected' : 'On this device'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 11),
                    ),
                    children: [cloudPanel!],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            LayoutBuilder(
              builder: (context, size) {
                final left = Column(
                      children: [
                        appearanceCard(context),
                        const SizedBox(height: 18),
                        typographyCard(context),
                      ],
                    ),
                    right = Column(
                      children: [
                        backupsCard(context),
                        const SizedBox(height: 18),
                        rulesCard(context),
                      ],
                    );
                return size.maxWidth >= 980
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 8, child: left),
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: right),
                        ],
                      )
                    : Column(
                        children: [left, const SizedBox(height: 18), right],
                      );
              },
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Icon(Icons.storage_outlined, size: 13, color: c.muted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Private by design. Your pace, your data.',
                    style: TextStyle(color: c.muted, fontSize: 10),
                  ),
                ),
                Text(
                  'TrackVerse 1.2.1',
                  style: TextStyle(color: c.muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
