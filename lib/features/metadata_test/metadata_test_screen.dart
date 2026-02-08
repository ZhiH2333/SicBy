import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metadata/db/metadata_db.dart';
import '../../core/metadata/models/audio_metadata.dart';
import '../../core/metadata/repositories/drift_metadata_repository.dart';
import '../../core/metadata/services/metadata_batch_scanner.dart';
import '../../core/metadata/services/metadata_extractor.dart';

class MetadataTestScreen extends ConsumerStatefulWidget {
  const MetadataTestScreen({super.key});

  @override
  ConsumerState<MetadataTestScreen> createState() =>
      _MetadataTestScreenState();
}

class _MetadataTestScreenState extends ConsumerState<MetadataTestScreen> {
  final MetadataExtractor _extractor = MetadataExtractor();
  late final MetadataBatchScanner _batchScanner;
  late final DriftMetadataRepository _repository;
  List<AudioMetadata> _results = const [];
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _batchScanner = MetadataBatchScanner(_extractor);
    _repository = DriftMetadataRepository(MetadataDb());
  }

  Future<void> _pickSingle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    await _runSingle(path);
  }

  Future<void> _pickBatch() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg'],
    );
    if (result == null || result.files.isEmpty) return;
    final paths =
        result.files.map((file) => file.path).whereType<String>().toList();
    if (paths.isEmpty) return;
    await _runBatch(paths);
  }

  Future<void> _runSingle(String path) async {
    setState(() {
      _busy = true;
      _status = 'Extracting metadata...';
    });
    final metadata = await _extractor.read(path);
    if (metadata != null) {
      await _repository.upsert(metadata);
    }
    setState(() {
      _results = metadata == null ? const [] : [metadata];
      _busy = false;
      _status =
          metadata == null ? 'No metadata found' : 'Metadata loaded';
    });
  }

  Future<void> _runBatch(List<String> paths) async {
    setState(() {
      _busy = true;
      _status = 'Scanning ${paths.length} files...';
    });
    final results = await _batchScanner.scan(paths);
    for (final metadata in results) {
      await _repository.upsert(metadata);
    }
    setState(() {
      _results = results;
      _busy = false;
      _status = 'Loaded ${results.length} entries';
    });
  }

  Future<void> _loadFromCache() async {
    final filePaths =
        _results.map((item) => item.path).toList(growable: false);
    if (filePaths.isEmpty) {
      setState(() {
        _status = 'No cached items to load';
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Loading cache...';
    });
    final cached = await _repository.getByPaths(filePaths);
    setState(() {
      _results = cached;
      _busy = false;
      _status = 'Loaded ${cached.length} cached entries';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metadata Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Pick single file',
            onPressed: _busy ? null : _pickSingle,
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Pick batch files',
            onPressed: _busy ? null : _pickBatch,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _status ?? 'Pick a file to test extraction',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _loadFromCache,
                  child: const Text('Load Cache'),
                ),
              ],
            ),
          ),
          if (_busy)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      'No results yet',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        leading: item.artworkPath != null &&
                                item.artworkPath!.isNotEmpty &&
                                File(item.artworkPath!).existsSync()
                            ? Image.file(
                                File(item.artworkPath!),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        const Icon(Icons.music_note),
                              )
                            : const Icon(Icons.music_note),
                        title: Text(
                          item.title,
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${item.artist} • ${item.album ?? 'Unknown Album'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          _formatDuration(item.duration),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        onTap: () => _showDetails(context, item),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        Divider(color: scheme.outlineVariant),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _showDetails(BuildContext context, AudioMetadata item) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (item.artworkPath != null &&
                  item.artworkPath!.isNotEmpty &&
                  File(item.artworkPath!).existsSync())
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 240,
                      maxHeight: 240,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(item.artworkPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.music_note, size: 64),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Center(child: Icon(Icons.music_note, size: 64)),
              const SizedBox(height: 16),
              _detailRow('Title', item.title),
              _detailRow('Artist', item.artist),
              _detailRow('Album', item.album ?? 'Unknown Album'),
              _detailRow('Duration', _formatDuration(item.duration)),
              _detailRow('Path', item.path),
              _detailRow(
                'Last Modified',
                item.lastModified?.toIso8601String() ?? 'Unknown',
              ),
              _detailRow(
                'Size',
                item.fileSizeBytes == null ? 'Unknown' : '${item.fileSizeBytes}',
              ),
              _detailRow(
                'Artwork Path',
                item.artworkPath?.isNotEmpty == true
                    ? item.artworkPath!
                    : 'None',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}
