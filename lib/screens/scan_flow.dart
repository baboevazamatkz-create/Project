import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/scan_service.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/scanned_transaction.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/scan_review_sheet.dart';

/// Where the snapshot comes from.
enum ScanSource { camera, gallery }

/// Picks snapshots, reads them, and offers what was read for confirmation.
///
/// Written as one function rather than folded into the home screen: it is a
/// sequence of four modal steps with nothing to keep between them, and the
/// home screen is long enough already. The picker and the service are
/// injectable so the whole sequence can be driven in a test without a
/// camera or a network.
class ScanFlow {
  final ScanService service;
  final Future<List<Uint8List>> Function(ScanSource source) pickImages;

  ScanFlow({ScanService? service, this.pickImages = pickScanImages})
      : service = service ?? ScanService();

  Future<void> run(
    BuildContext context, {
    required AppCurrency currency,
    required List<Expense> existing,
    required Future<void> Function(List<Expense> expenses) onAdd,
  }) async {
    final source = await _askSource(context);
    if (source == null || !context.mounted) return;

    final List<Uint8List> raw;
    try {
      raw = await pickImages(source);
    } catch (_) {
      if (context.mounted) {
        _toast(context, 'Не удалось открыть снимок');
      }
      return;
    }
    if (raw.isEmpty || !context.mounted) return;

    final images =
        raw.take(ScanService.maxImages).map(prepareScanImage).toList();

    _showProgress(context);
    ScanResult result;
    try {
      result = await service.scan(images: images, currency: currency);
    } on ScanException catch (error) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _toast(context, error.message);
      }
      return;
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _toast(context, 'Не удалось разобрать снимок');
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassSheet(
        child: ScanReviewSheet(
          result: result,
          currency: currency,
          duplicates: findDuplicates(result.transactions, existing),
          onConfirm: (expenses) async {
            if (expenses.isEmpty) return;
            await onAdd(expenses);
          },
        ),
      ),
    );
  }

  Future<ScanSource?> _askSource(BuildContext context) =>
      showModalBottomSheet<ScanSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => GlassSheet(
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                  child: Text(
                    'РАСПОЗНАТЬ СНИМОК',
                    style:
                        microLabel(context, size: 11, color: goldFor(context)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: const Text('Снять чек'),
                  subtitle: const Text('Кадр целиком, без бликов'),
                  onTap: () => Navigator.of(context).pop(ScanSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Выбрать из галереи'),
                  subtitle: const Text(
                    'Чек или скриншот из банка, до '
                    '${ScanService.maxImages} снимков сразу',
                  ),
                  onTap: () => Navigator.of(context).pop(ScanSource.gallery),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );

  void _showProgress(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: GlassPanel(
          radius: 20,
          blur: 8,
          elevated: true,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: goldFor(context),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Читаю снимок…',
                style: TextStyle(
                  fontSize: 14,
                  color: accentForeground(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The real picker. Resizing is asked of the platform first -- it does it
/// natively, on a full-resolution photo, far faster than Dart can.
Future<List<Uint8List>> pickScanImages(ScanSource source) async {
  final picker = ImagePicker();
  if (source == ScanSource.camera) {
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: kScanMaxEdge.toDouble(),
      maxHeight: kScanMaxEdge.toDouble(),
      imageQuality: 85,
    );
    return file == null ? const [] : [await file.readAsBytes()];
  }
  final files = await picker.pickMultiImage(
    limit: ScanService.maxImages,
    maxWidth: kScanMaxEdge.toDouble(),
    maxHeight: kScanMaxEdge.toDouble(),
    imageQuality: 85,
  );
  return Future.wait(
    files.take(ScanService.maxImages).map((f) => f.readAsBytes()),
  );
}
