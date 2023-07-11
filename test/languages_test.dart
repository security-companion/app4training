import 'package:download_assets/download_assets.dart';
import 'package:file/chroot.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:four_training/data/languages.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

class MockDownloadAssetsController extends Mock
    implements DownloadAssetsController {}

class FakeDownloadAssetsController extends Fake
    implements DownloadAssetsController {
  late String _assetDir;
  final FileSystem _fs;
  bool initCalled = false;
  bool startDownloadCalled = false;

  FakeDownloadAssetsController(FileSystem fileSystem) : _fs = fileSystem;
  // TODO use this class to test the startDownload() functionality
  @override
  Future init(
      {String assetDir = 'assets', bool useFullDirectoryPath = false}) async {
    _assetDir = assetDir;
    initCalled = true;
    return;
  }

  @override
  String? get assetsDir => _assetDir;

  @override
  Future<bool> assetsDirAlreadyExists() async {
    return false;
  }

  @override
  Future clearAssets() async {
    return;
  }

  @override
  Future startDownload(
      {required List<String> assetsUrls,
      Function(double p1)? onProgress,
      Function()? onCancel,
      Map<String, dynamic>? requestQueryParams,
      Map<String, String> requestExtraHeaders = const {}}) async {
    // TODO: implement startDownload
    startDownloadCalled = true;
    return;
  }
}

void main() {
  late DownloadAssetsController mock;

  test('Test the download process', () async {
    // TODO this is not testing very much yet
    var fileSystem = MemoryFileSystem();
    var fakeController = FakeDownloadAssetsController(fileSystem);
    var deTest = Language('de',
        assetsController: fakeController, fileSystem: fileSystem);
    try {
      await deTest.init();
      fail('init() should throw because no files are there');
    } catch (e) {
      expect(e, isA<Exception>());
      expect(fakeController.initCalled, true);
      expect(fakeController.startDownloadCalled, true);
    }
  });

  group('Test correct behavior after downloading', () {
    // We assume files are already downloaded, so just mock this
    setUp(() {
      mock = MockDownloadAssetsController();
      when(() => mock.init(assetDir: 'assets-de')).thenAnswer((_) async {
        return;
      });
      when(mock.clearAssets).thenAnswer((_) async {
        return;
      });
      when(() => mock.assetsDir).thenReturn('assets-de');
      when(() => mock.assetsDirAlreadyExists()).thenAnswer((_) async => true);
    });

    group('Test error handling of incorrect files / structure', () {
      test('Test error handling when no files can be found at all', () async {
        var deTest = Language('de',
            assetsController: mock, fileSystem: MemoryFileSystem());
        try {
          await deTest.init();
          fail('Test.init() should throw an exception during _getTimestamp()');
        } catch (e) {
          expect(e.toString(), contains('Error getting timestamp'));
        }
        expect(deTest.downloaded, false);
        expect(deTest.path, equals('assets-de/test-html-de-main'));
      });

      test('Test error handling when structure is inconsistent', () async {
        var fileSystem = MemoryFileSystem();
        await fileSystem
            .directory('assets-de/test-html-de-main/structure')
            .create(recursive: true);
        var contentsJson = fileSystem
            .file('assets-de/test-html-de-main/structure/contents.json');
        contentsJson.writeAsString('invalid');
        var deTest =
            Language('de', assetsController: mock, fileSystem: fileSystem);
        try {
          await deTest.init();
          fail('Test.init() should throw while decoding contents.json');
        } catch (e) {
          expect(e.toString(), contains('FormatException'));
        }
        expect(deTest.downloaded, false);
      });
    });

    test('Test everything with real content from test/assets-de/', () async {
      var fileSystem =
          ChrootFileSystem(const LocalFileSystem(), path.canonicalize('test/'));
      var deTest =
          Language('de', assetsController: mock, fileSystem: fileSystem);
      await deTest.init();

      // Loads Gottes_Geschichte_(fünf_Finger).html
      String content = await deTest.getPageContent(0);

      expect(content, startsWith('<h1>Gottes Geschichte'));
      // The link of this image should have been replaced with image content
      expect(content, isNot(contains('src="files/Hand_4.png"')));
      // This should still be there as the image file is missing
      expect(content, contains('src="files/Hand_5.png"'));

      // Test Languages.getIndexByTitle()
      expect(deTest.getIndexByTitle('Umgang_mit_Geld.html'), null);
      expect(deTest.getIndexByTitle('Schritte_der_Vergebung.html'), 1);

      // Test Languages.getPageTitles()
      expect(
          deTest.getPageTitles(),
          orderedEquals(const [
            'Gottes_Geschichte_(fünf_Finger).html',
            'Schritte_der_Vergebung.html'
          ]));
    });
  });
}
