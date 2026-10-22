import 'package:flutter/material.dart';
import 'appearance.dart';

String syncLabel(Map<String, dynamic> p) {
  if (p['sheet_id'] == null) return 'On this device';
  return switch (p['status']) {
    'synced' => 'Backed up',
    'syncing' => 'Syncing…',
    'conflict' => 'Choose a version',
    'error' => 'Saved locally · sync needs attention',
    'pending' => 'Saved locally · waiting to sync',
    _ => 'Ready to sync',
  };
}

class WelcomeScreen extends StatelessWidget {
  final bool busy;
  final String? error;
  final VoidCallback onGoogle, onLocal, onCancel;
  const WelcomeScreen({
    super.key,
    required this.busy,
    required this.onGoogle,
    required this.onLocal,
    required this.onCancel,
    this.error,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppPalette(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 18,
              right: 24,
              child: IconButton(
                tooltip: 'Switch appearance',
                onPressed: () => appearance.setMode(
                  c.dark ? ThemeMode.light : ThemeMode.dark,
                ),
                icon: Icon(
                  c.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: c.muted,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 410),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF394047),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.stacked_line_chart_rounded,
                          size: 39,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome to TrackVerse',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Small habits. A little better, every day.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted, fontSize: 14),
                      ),
                      const SizedBox(height: 38),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy ? null : onGoogle,
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_outlined, size: 20),
                          label: Text(
                            busy
                                ? 'Waiting for Google…'
                                : 'Continue with Google',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'SQLite on your device + automatic Google Sheets backup',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted, fontSize: 11),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(18),
                            side: BorderSide(color: c.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          onPressed: busy ? null : onLocal,
                          icon: const Icon(Icons.computer_outlined, size: 20),
                          label: const Text(
                            'Set up locally',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'SQLite only. No account needed.',
                        style: TextStyle(color: c.muted, fontSize: 11),
                      ),
                      if (busy)
                        TextButton(
                          onPressed: onCancel,
                          child: const Text('Cancel sign-in'),
                        ),
                      if (error != null) ...[
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: c.raised,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 38),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, size: 13, color: c.muted),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Your choice. Connect Google later in Settings.',
                              style: TextStyle(color: c.muted, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CloudPanel extends StatelessWidget {
  final Map<String, dynamic> state;
  final bool busy;
  final bool embedded;
  final Future<void> Function(String, String, bool) action;
  final VoidCallback onCreate;
  final void Function(Map<String, dynamic>) onRename;
  const CloudPanel({
    super.key,
    required this.state,
    required this.busy,
    required this.action,
    required this.onCreate,
    required this.onRename,
    this.embedded = false,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppPalette(context),
        connected = state['connected'] == true,
        configured = state['configured'] == true;
    final profiles = (state['profiles'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    final identity = state['identity'] as Map?;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(embedded ? 0 : 24),
      decoration: BoxDecoration(
        color: c.surface,
        border: embedded ? null : Border.all(color: c.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!embedded)
            Row(
              children: [
                Icon(Icons.cloud_outlined, color: c.accent, size: 23),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Trackers & cloud backup',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            connected
                ? 'Connected as ${identity?['email'] ?? 'your Google account'}. Your trackers are saved in SQLite and backed up to your own Google Sheets.'
                : 'Work locally for free. Connect Google to back up your trackers and restore them after reinstalling.',
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.7),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!connected)
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => action('googleSignIn', '', true),
                  icon: const Icon(Icons.login, size: 17),
                  label: const Text('Continue with Google'),
                ),
              if (connected) ...[
                FilledButton.icon(
                  onPressed: busy ? null : onCreate,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('New tracker'),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => action('discoverTrackers', '', true),
                  icon: const Icon(Icons.restore, size: 17),
                  label: const Text('Find my trackers'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => action('googleSignOut', '', false),
                  child: const Text('Disconnect Google'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          ...profiles.map((p) {
            final selected = p['id'] == state['activeId'];
            final remote = p['sheet_id'] != null;
            final conflict = p['status'] == 'conflict';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected ? c.raised : c.surface,
                border: Border.all(
                  color: selected ? c.accent.withValues(alpha: .45) : c.border,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        remote
                            ? Icons.cloud_done_outlined
                            : Icons.storage_outlined,
                        color: c.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['alias'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              syncLabel(p),
                              style: TextStyle(
                                fontSize: 10,
                                color: conflict
                                    ? Theme.of(context).colorScheme.error
                                    : c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Rename tracker',
                        onPressed: busy ? null : () => onRename(p),
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                  if (remote) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      p['url'] as String,
                      style: TextStyle(color: c.accent, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${p['sharing'] ?? 'Private · Google account only'}${p['lastSync'] != null ? ' · Last checked ${_time(p['lastSync'] as String)}' : ''}',
                      style: TextStyle(color: c.muted, fontSize: 10),
                    ),
                    if (p['error'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        p['error'] as String,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ],
                  if (!selected || remote || conflict)
                    const SizedBox(height: 12),
                  if (!selected || remote || conflict)
                    Wrap(
                      spacing: 9,
                      runSpacing: 8,
                      children: [
                        if (!selected)
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => action(
                                    'switchTracker',
                                    p['id'] as String,
                                    true,
                                  ),
                            child: const Text('Switch tracker'),
                          ),
                        if (remote) ...[
                          TextButton.icon(
                            onPressed:
                                busy || !connected || state['online'] == false
                                ? null
                                : () => _delete(context, p),
                            icon: const Icon(Icons.delete_outline, size: 15),
                            label: const Text('Delete tracker & sheet'),
                          ),
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => action(
                                    'openTrackerSheet',
                                    p['id'] as String,
                                    false,
                                  ),
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text('Open sheet'),
                          ),
                          TextButton.icon(
                            onPressed: busy || !connected
                                ? null
                                : () => action(
                                    'syncTracker',
                                    '{"id":"${p['id']}"}',
                                    true,
                                  ),
                            icon: const Icon(Icons.sync, size: 15),
                            label: const Text('Sync now'),
                          ),
                        ],
                        if (conflict) ...[
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => _resolve(context, p, 'remote'),
                            child: const Text('Use sheet version'),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => _resolve(context, p, 'local'),
                            child: const Text('Keep this device’s version'),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            );
          }),
          Text(
            'Google sign-in creates and finds your backup sheets automatically. No links to paste. Only changes that have finished syncing can be recovered after uninstalling.',
            style: TextStyle(color: c.muted, fontSize: 11, height: 1.7),
          ),
          if (!configured) ...[
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              'Preview setup',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'The app owner must configure the desktop OAuth client once. End users only need Google sign-in.',
              style: TextStyle(color: c.muted, fontSize: 11, height: 1.6),
            ),
            TextButton.icon(
              onPressed: busy ? null : () => action('googleSetup', '', false),
              icon: const Icon(Icons.settings_outlined, size: 15),
              label: const Text('Import Google OAuth configuration'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${p['alias']}?'),
        content: const Text(
          'Move this Google spreadsheet to Drive’s Trash and remove its tracker from the app? A local recovery archive will be kept. Other trackers are unaffected. You can restore the sheet from Drive’s Trash, then use Find my trackers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await action('deleteTracker', p['id'] as String, true);
    }
  }

  Future<void> _resolve(
    BuildContext context,
    Map<String, dynamic> p,
    String choice,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose a tracker version'),
        content: Text(
          choice == 'remote'
              ? 'Replace this device’s tracker with the backed-up sheet version? Export a local backup first if you want to keep unsynced work.'
              : 'Back up this device’s tracker as the next version? Previous sheet snapshots will remain in the backup history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await action(
        'syncTracker',
        '{"id":"${p['id']}","resolve":"$choice"}',
        true,
      );
    }
  }

  String _time(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    return d == null
        ? 'recently'
        : '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class TrackerNameDialog extends StatefulWidget {
  final String? alias;
  const TrackerNameDialog({super.key, this.alias});
  @override
  State<TrackerNameDialog> createState() => _TrackerNameDialogState();
}

class _TrackerNameDialogState extends State<TrackerNameDialog> {
  late final name = TextEditingController(text: widget.alias);
  final form = GlobalKey<FormState>();
  bool copy = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.alias == null
          ? 'A space for a different season.'
          : 'Rename tracker',
    ),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Tracker name',
                  hintText: 'e.g. Exam preparation',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Choose a name for this tracker.'
                    : null,
              ),
              if (widget.alias == null) ...[
                const SizedBox(height: 12),
                const Text(
                  'A Google Sheet is created automatically for this tracker.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Copy habits and history from the current tracker',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: copy,
                  onChanged: (v) => setState(() => copy = v!),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, {
              'alias': name.text.trim(),
              'copyCurrent': copy,
            });
          }
        },
        child: Text(widget.alias == null ? 'Create tracker' : 'Save name'),
      ),
    ],
  );
}
