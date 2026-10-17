import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../../domain/models.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';

/// Tickets, screenshots and photos attached to an item or card.
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
            Text(l.attachmentsTitle, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: l.takePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: () => _addImage(context, ref, ImageSource.camera),
            ),
            IconButton(
              tooltip: l.imageFromGallery,
              icon: const Icon(Icons.image_outlined),
              onPressed: () => _addImage(context, ref, ImageSource.gallery),
            ),
            IconButton(
              tooltip: l.attachFileTooltip,
              icon: const Icon(Icons.attach_file),
              onPressed: () => _addFile(context, ref),
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
                      onTap: () => OpenFilex.open(repo.files.fileFor(a).path),
                      onLongPress: () => _delete(context, ref, a),
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
            leading: Icon(a.mime == 'application/pdf' ? Icons.picture_as_pdf : Icons.insert_drive_file),
            title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => OpenFilex.open(repo.files.fileFor(a).path, type: a.mime),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, a)),
          ),
      ],
    );
  }

  Future<void> _addImage(BuildContext context, WidgetRef ref, ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!context.mounted) return;
    await ref.read(planActionsProvider).record(tripId, context.l10n.stepImageAttached, (repo) async {
      final a = await repo.files.addBytes(tripId: tripId, ownerId: ownerId, bytes: bytes, fileName: x.name);
      await repo.saveAttachment(a);
    });
  }

  Future<void> _addFile(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final f = await FilePicker.pickFile(dialogTitle: l.attachFileDialog);
    if (f == null) return;
    final bytes = await f.xFile.readAsBytes();
    await ref.read(planActionsProvider).record(tripId, l.stepFileAttached(f.name), (repo) async {
      final a = await repo.files.addBytes(tripId: tripId, ownerId: ownerId, bytes: bytes, fileName: f.name);
      await repo.saveAttachment(a);
    });
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Attachment a) async {
    final l = context.l10n;
    if (await confirm(context, l.removeQuestion(a.fileName))) {
      await ref
          .read(planActionsProvider)
          .record(tripId, l.stepFileRemoved(a.fileName), (repo) => repo.deleteAttachment(a));
    }
  }
}
