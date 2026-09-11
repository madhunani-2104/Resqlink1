import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:resq_app/core/services/file_chunk_transfer.dart';

void main() {
  test('reassembles chunks in order and ignores duplicate indexes', () {
    final bytes = List<int>.generate(700, (index) => index % 251);
    final chunks = <FileChunk>[];
    const chunkSize = 128;
    final total = (bytes.length + chunkSize - 1) ~/ chunkSize;

    for (var index = 0; index < total; index++) {
      final start = index * chunkSize;
      final end = (start + chunkSize).clamp(0, bytes.length);
      chunks.add(
        FileChunk(
          transferId: 'transfer-1',
          fileName: 'report.pdf',
          mimeType: 'application/pdf',
          fileSize: bytes.length,
          index: index,
          total: total,
          data: base64Encode(bytes.sublist(start, end)),
        ),
      );
    }

    final assembler = FileChunkAssembler(chunks.first);
    assembler.add(chunks.first);
    for (final chunk in chunks.skip(1).toList().reversed) {
      expect(assembler.add(chunk), isTrue);
    }

    expect(assembler.isComplete, isTrue);
    expect(base64Decode(assembler.assembleBase64()!), bytes);
  });

  test('rejects malformed and out-of-range chunks', () {
    expect(FileChunk.fromContent('FILE_CHUNK:not-json'), isNull);
    expect(
      FileChunk.fromContent(
        'FILE_CHUNK:{"transferId":"x","fileName":"a","fileSize":1,"index":2,"total":1,"data":"AQ=="}',
      ),
      isNull,
    );
  });
}
