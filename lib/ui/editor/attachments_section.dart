import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/file_sources.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';
import '../files/files_page.dart';

/// Tickets, screenshots and photos linked to an item or card. New files go
/// into the top level of the trip's file workspace; removing one here only
/// unlinks it, the file stays in the workspace.
class AttachmentsSection extends ConsumerWidget {
  final String tripId;
  final String ownerId;
  final List<Attachment> attachments;

  const AttachmentsSection({
    super.key,
    required this.tripId,
    required this.ownerId,
    required this.attachments,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Shrinks first, so the four 48 dp buttons always fit.
            Expanded(
              child: Text(
                l.attachmentsTitle,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: l.takePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: () => _add(context, ref, (s) async => [?await s.takePhoto()]),
            ),
            IconButton(
              tooltip: l.imageFromGallery,
              icon: const Icon(Icons.image_outlined),
              onPressed: () => _add(context, ref, (s) => s.pickImages()),
            ),
            IconButton(
              tooltip: l.attachFileTooltip,
              icon: const Icon(Icons.attach_file),
              onPressed: () => _add(context, ref, (s) => s.pickFiles(dialogTitle: l.attachFileDialog)),
            ),
            IconButton(
              tooltip: l.filesChooseFromWorkspace,
              icon: const Icon(Icons.folder_open_outlined),
              onPressed: () => _fromWorkspace(context, ref),
            ),
          ],
        ),
        if (attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l.attachmentsEmpty, style: const TextStyle(fontSize: 12)),
          ),
        if (attachments.any((a) => a.isImage))
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final a in attachments.where((a) => a.isImage))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => openAttachment(context, ref, a),
                      onLongPress: () => _unlink(context, ref, a),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(repo.files.fileFor(a), width: 96, height: 96, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(width: 96, child: Icon(Icons.broken_image))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        for (final a in attachments.where((a) => !a.isImage))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(fileIcon(a)),
            title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: a.folder.isEmpty ? null : Text(a.folder.replaceAll('/', ' › ')),
            onTap: () => openAttachment(context, ref, a),
            trailing: IconButton(
              tooltip: l.filesUnlink,
              icon: const Icon(Icons.link_off),
              onPressed: () => _unlink(context, ref, a),
            ),
          ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, Future<List<PickedFile>> Function(FileSources) pick) async {
    final l = context.l10n;
    final List<PickedFile> files;
    try {
      files = await pick(ref.read(fileSourcesProvider));
    } catch (e) {
      if (context.mounted) showSnack(context, l.errorWith('$e'));
      return;
    }
    final data = ref.read(tripDataProvider(tripId)).value;
    if (files.isEmpty || data == null) return;
    final label = files.length == 1 ? l.stepFileAttached(files.single.name) : l.stepFilesAdded(files.length);
    await addFilesToWorkspace(ref, data, files, label, ownerIds: [ownerId]);
  }

  Future<void> _fromWorkspace(BuildContext context, WidgetRef ref) async {
    final data = ref.read(tripDataProvider(tripId)).value;
    if (data == null) return;
    final l = context.l10n;
    final picked = await pickWorkspaceFiles(context, data, exclude: {for (final a in attachments) a.id});
    if (picked == null || picked.isEmpty) return;
    final label = picked.length == 1 ? l.stepFileAttached(picked.single.fileName) : l.stepFilesAdded(picked.length);
    await ref.read(planActionsProvider).record(tripId, label, (repo) async {
      for (final a in picked) {
        await repo.linkAttachment(a, ownerId);
      }
    });
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref, Attachment a) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(planActionsProvider);
    final label = l.stepFileUnlinked(a.fileName);
    await actions.record(tripId, label, (repo) => repo.unlinkAttachment(a, ownerId));
    final step = actions.lastStep(tripId);
    showUndoSnack(messenger, label, () => actions.undoStep(tripId, step));
  }
}
