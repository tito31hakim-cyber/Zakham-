import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/admin_api.dart';
import '../services/research_pdfs_api.dart';
import '../theme/app_theme.dart';

/// رفع ملفات PDF لذاكرة البحث — داخل مركز الذكاء.
///
/// يختار المالك ملف PDF (حتى 10MB) فيُرفع إلى الخادم مع مؤشر تقدم،
/// وتظهر قائمة الملفات المرفوعة مع حالتها: قيد المراجعة / أُدخل /
/// مرفوض. الملفات تُحفظ خارج public_html، ولا تدخل ذاكرة المستشار
/// إلا بعد مراجعة بشرية — الرفع وحده لا يعلّم المستشار شيئاً.

class ResearchPdfsPage extends StatefulWidget {
  const ResearchPdfsPage({super.key, required this.api});

  final AdminApi api;

  @override
  State<ResearchPdfsPage> createState() => _ResearchPdfsPageState();
}

class _ResearchPdfsPageState extends State<ResearchPdfsPage> {
  late Future<List<ResearchPdfFile>> _files;
  bool _uploading = false;
  double _progress = 0;
  String? _uploadingName;
  String? _error;

  @override
  void initState() {
    super.initState();
    _files = widget.api.researchPdfsApi.listPdfs();
  }

  Future<void> _refresh() async {
    final future = widget.api.researchPdfsApi.listPdfs();
    setState(() {
      _files = future;
      _error = null;
    });
    try {
      await future;
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    }
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked == null) return;
    List<int>? bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      bytes = null;
    }
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر قراءة الملف المختار.')),
        );
      }
      return;
    }
    if (bytes.length > ResearchPdfsApi.maxFileBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حجم الملف يتجاوز 10MB — اختر ملفاً أصغر.'),
          ),
        );
      }
      return;
    }
    setState(() {
      _uploading = true;
      _progress = 0;
      _uploadingName = picked.name;
      _error = null;
    });
    try {
      await widget.api.researchPdfsApi.uploadPdf(
        filename: picked.name,
        bytes: bytes,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفع الملف — قيد المراجعة قبل دخول المعرفة.'),
        ),
      );
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0;
          _uploadingName = null;
        });
      }
    }
  }

  static String _cleanError(Object e) {
    final text = e.toString();
    for (final prefix in ['Exception: ', 'FormatException: ']) {
      if (text.startsWith(prefix)) return text.substring(prefix.length);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('ملفات PDF للبحث'),
            actions: [
              IconButton(
                onPressed: _uploading ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث القائمة',
              ),
            ],
          ),
          body: Column(
            children: [
              _introNote(context),
              if (_uploading) _uploadProgress(context),
              if (_error != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              Expanded(
                child: FutureBuilder<List<ResearchPdfFile>>(
                  future: _files,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _errorState(context, snapshot.error!);
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final files = snapshot.data!;
                    if (files.isEmpty) return _emptyState(context);
                    return RefreshIndicator(
                      color: context.goldText,
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: files.length,
                        itemBuilder: (context, index) =>
                            _fileCard(context, files[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('رفع ملف PDF'),
          ),
        ),
      );

  Widget _introNote(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.goldText.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.goldText.withOpacity(.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.picture_as_pdf_outlined,
                color: context.goldText, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ملفات PDF تُراجع قبل دخولها ذاكرة المستشار — لا تدخل المعرفة إلا بعد مراجعة بشرية. الحد 10MB للملف الواحد.',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: context.ink, fontSize: 12, height: 1.6),
              ),
            ),
          ],
        ),
      );

  Widget _uploadProgress(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'جارٍ رفع ${_uploadingName ?? 'الملف'}… ${(_progress * 100).round()}٪',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: context.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _progress,
              color: context.goldText,
            ),
          ],
        ),
      );

  Widget _emptyState(BuildContext context) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.picture_as_pdf_outlined,
              color: context.goldText, size: 56),
          const SizedBox(height: 18),
          Text(
            'لا توجد ملفات مرفوعة بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: context.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'ارفع ملف PDF من زر الرفع — سيظهر هنا بحالة «قيد المراجعة» حتى تُراجع حقائقه وتدخل المعرفة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.subdued, height: 1.6),
          ),
        ],
      );

  Widget _errorState(BuildContext context, Object error) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.cloud_off_outlined, color: context.goldText, size: 56),
          const SizedBox(height: 18),
          Text(
            'تعذّر تحميل قائمة الملفات',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: context.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            _cleanError(error),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.subdued, height: 1.6),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton(
              onPressed: _refresh,
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );

  Widget _fileCard(BuildContext context, ResearchPdfFile file) {
    final color = switch (file.status) {
      ResearchPdfStatus.entered => const Color(0xFF62C69A),
      ResearchPdfStatus.rejected => Colors.redAccent,
      ResearchPdfStatus.underReview => Colors.orange,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_outlined,
                color: Colors.redAccent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  file.filename,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: context.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${file.sizeLabel}${file.uploadedAt == null ? '' : ' • ${_date(file.uploadedAt!)}'}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: context.subdued, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              file.status.label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}
