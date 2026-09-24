// `test/helpers/seed_articles.dart` 自身の契約テスト（CLAUDE.md「テスト方針」の
// 例外。D-05 §7・§8 #36）。`seedArticles` は多くの UseCase テストの前提を
// 作る単一障害点のため、D-05 §7 の `ArgumentError` 全ケースと `StateError`
// 1 ケースの引数検証を直接テストする。件数の担保は `group('引数の検証')`
// 内の meta テスト（[_buildArgumentErrorCases] 参照）に置く。
//
// D-05 §7 の各ケースを [_buildArgumentErrorCases] で表（[_ArgumentErrorCase]
// のフラットなリスト）に展開し、[main] で `caseText` ごとにまとめて
// group / test に変換している（複数経路のケースは group 名が `caseText`、
// test 名が `branch`。単一経路のケースは `branch` が無く、そのまま
// `caseText` が test 名）。同一メッセージで複数の入力パターン（id 重複が
// inserts・outOfFeed・withUpdateBadge・readIds のどこで起きたか等）から
// 発火しうるケースは、パターンごとに独立した test に展開して fail
// isolation を確保する（1 つの test の中でループすると、先頭のパターンが
// 落ちた周では残りが一度も実行されない）。
import 'package:collection/collection.dart';
import 'package:curtaincall/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_database.dart';
import 'seed_articles.dart';
import 'test_articles.dart';

/// [_rowCounts] が返す、テーブルごとの行数。位置指定レコードでは失敗時に
/// どのテーブルか分からないため名前付きレコードにする。
typedef _RowCounts = ({
  int articles,
  int savedArticles,
  int readStates,
  int settings,
});

/// [_rowCounts] が返しうる「4 テーブルとも 0 行」の期待値。
///
/// `onCreate`／migration が `settings` に既定行を入れるようになったら、
/// この `settings: 0` を既定行数に更新すること（`seedArticles` の契約が
/// 変わったわけではない）。
const _RowCounts _emptyRowCounts = (
  articles: 0,
  savedArticles: 0,
  readStates: 0,
  settings: 0,
);

/// D-05 §7 の `ArgumentError` 1 ケース分（の 1 パターン）。
///
/// `caseText` が D-05 §7 の箇条書きそのもの。同じ違反が複数の入力パターンで
/// 発火しうるケースは、パターンごとに 1 要素（`caseText` が同じで `branch`
/// が異なる）になる。単一経路のケースは `branch` が `null` で、test 名は
/// `caseText` そのものになる（[main] 参照）。
///
/// `messageMatcher` は `e.message.toString()` に対する `Matcher`。書式
/// （引用符の有無など）に依存しない語句で識別できるよう、`contains` 1 つ
/// または `allOf(contains(...), ...)` を渡す。
typedef _ArgumentErrorCase = ({
  String caseText,
  String? branch,
  Future<void> Function(AppDatabase db) run,
  Matcher messageMatcher,
});

/// [seedArticles] が `inserts` 内の id 重複で投げるメッセージ文言。
/// 引数検証のケース（`group('引数の検証')`）と「2 回目の呼び出し」の
/// ケース（[main] 末尾）の両方が、同じ違反を前提作りに使うため共有する。
const _insertsDuplicateIdMessage = 'inserts の中に id が重複している要素があります';

/// [seedArticles] が `inserts` の id と `outOfFeed`・`withUpdateBadge` の
/// 重複で投げるメッセージ文言。同じ throw 経路を 2 パターン（相手が
/// `outOfFeed`・`withUpdateBadge` のそれぞれ）で検証するため共有する。
const _insertsOverlapMessage =
    'inserts の id は outOfFeed・withUpdateBadge と重複できません';

/// `savedAtByIds` に渡す任意の日時。値そのものは検証対象ではなく、
/// `outOfFeed`・`withUpdateBadge` の id を `savedAtByIds` にも入れるという
/// 形（FK）を満たすためだけに使う。
final _anySavedAt = DateTime.utc(2026);

/// `withUpdateBadge` に渡す任意の `updatedAt`。値そのものは検証対象ではない。
final _anyUpdatedAt = DateTime.utc(2026, 2);

/// `articles`・`saved_articles`・`read_states`・`settings` の行数を返す。
/// `ArgumentError` が **DB に触れる前**に投げられていること（D-05 §10 T-R
/// の完了条件）の確認に使う。1 テーブルだけでなく 4 テーブルすべてを見る
/// ことで、検証より前に他テーブルへ書き込む退行も検知する（`settings` は
/// `DriftArticleRepository.applyFeed` の手順 6 が書く唯一の他テーブル。
/// [seedArticles] は常に `etag`・`generatedAt` を null で渡すため、現状
/// `settings` は常に 0 行のまま）。
Future<_RowCounts> _rowCounts(AppDatabase db) async => (
  articles: (await db.select(db.articles).get()).length,
  savedArticles: (await db.select(db.savedArticles).get()).length,
  readStates: (await db.select(db.readStates).get()).length,
  settings: (await db.select(db.settings).get()).length,
);

/// [_ArgumentErrorCase] 1 件分の `test` を登録する。test 名は `branch` が
/// あればそれ、無ければ `caseText`（単一経路のケース）。[errorCase] の
/// `run` が `messageMatcher` に一致する `ArgumentError` を投げ、DB に何も
/// 書き込まれていないこと（[_rowCounts] が [_emptyRowCounts] のままである
/// こと）を検証する。
void _argumentErrorTest(_ArgumentErrorCase errorCase) {
  test(errorCase.branch ?? errorCase.caseText, () async {
    final db = openInMemoryDatabase();
    await expectLater(
      () => errorCase.run(db),
      throwsA(
        isArgumentError.having(
          (e) => e.message.toString(),
          'message',
          errorCase.messageMatcher,
        ),
      ),
    );
    expect(await _rowCounts(db), _emptyRowCounts);
  });
}

/// D-05 §7 の `ArgumentError` 7 ケースを [_ArgumentErrorCase] のフラットな
/// リストに展開する。検証を 1 つ足すときはこのリストに 1 要素（単一経路の
/// ケースなら `branch: null` の 1 件、複数経路のケースなら `branch` 違いの
/// 複数件）足すだけでよい。
List<_ArgumentErrorCase> _buildArgumentErrorCases() {
  // 3 つ目以降のケースは値の違いに意味が無いため、各 `run` の中で
  // `testArticleId(1)` を直接使う。`knownId`・`unknownId` だけは
  // 「savedAtByIds/readIds の id が既知かどうか」という違いに意味があるため
  // 局所変数にする。
  final knownId = testArticleId(1);
  final unknownId = testArticleId(2);

  return [
    (
      caseText:
          'inserts・outOfFeed・withUpdateBadge・readIds のいずれかの中で id が '
          '重複 → ArgumentError',
      branch: 'inserts',
      run: (db) => seedArticles(
        db,
        inserts: [
          testArticle(id: testArticleId(1)),
          testArticle(id: testArticleId(1)),
        ],
      ),
      messageMatcher: contains(_insertsDuplicateIdMessage),
    ),
    (
      caseText:
          'inserts・outOfFeed・withUpdateBadge・readIds のいずれかの中で id が '
          '重複 → ArgumentError',
      branch: 'outOfFeed',
      run: (db) => seedArticles(
        db,
        outOfFeed: [
          testArticle(id: testArticleId(1)),
          testArticle(id: testArticleId(1)),
        ],
        // outOfFeed 内の id 重複だけを違反する入力にする。savedAtByIds
        // を省くと「outOfFeed の id が savedAtByIds に無い」規則も同時
        // に違反し、検証順に暗黙依存してしまうため savedAtByIds も渡す。
        savedAtByIds: {testArticleId(1): _anySavedAt},
      ),
      messageMatcher: contains('outOfFeed の中に id が重複している要素があります'),
    ),
    (
      caseText:
          'inserts・outOfFeed・withUpdateBadge・readIds のいずれかの中で id が '
          '重複 → ArgumentError',
      branch: 'withUpdateBadge',
      run: (db) => seedArticles(
        db,
        withUpdateBadge: [
          testArticle(id: testArticleId(1), updatedAt: _anyUpdatedAt),
          testArticle(id: testArticleId(1), updatedAt: _anyUpdatedAt),
        ],
      ),
      messageMatcher: contains('withUpdateBadge の中に id が重複している要素があります'),
    ),
    (
      caseText:
          'inserts・outOfFeed・withUpdateBadge・readIds のいずれかの中で id が '
          '重複 → ArgumentError',
      branch: 'readIds',
      run: (db) => seedArticles(
        db,
        inserts: [testArticle(id: testArticleId(1))],
        readIds: [testArticleId(1), testArticleId(1)],
      ),
      messageMatcher: contains('readIds の中に id が重複している要素があります'),
    ),
    (
      caseText: 'inserts の id が outOfFeed・withUpdateBadge と重複 → ArgumentError',
      branch: 'outOfFeed',
      run: (db) => seedArticles(
        db,
        inserts: [testArticle(id: testArticleId(1))],
        outOfFeed: [testArticle(id: testArticleId(1), title: 'other')],
        savedAtByIds: {testArticleId(1): _anySavedAt},
      ),
      messageMatcher: contains(_insertsOverlapMessage),
    ),
    (
      caseText: 'inserts の id が outOfFeed・withUpdateBadge と重複 → ArgumentError',
      branch: 'withUpdateBadge',
      run: (db) => seedArticles(
        db,
        inserts: [testArticle(id: testArticleId(1))],
        withUpdateBadge: [
          testArticle(id: testArticleId(1), updatedAt: _anyUpdatedAt),
        ],
      ),
      messageMatcher: contains(_insertsOverlapMessage),
    ),
    (
      caseText: 'withUpdateBadge の記事に updatedAt が無い → ArgumentError',
      branch: null,
      run: (db) => seedArticles(
        db,
        withUpdateBadge: [testArticle(id: testArticleId(1))],
      ),
      messageMatcher: contains('に updatedAt がありません'),
    ),
    (
      caseText: 'outOfFeed の id が savedAtByIds に無い → ArgumentError',
      branch: null,
      run: (db) =>
          seedArticles(db, outOfFeed: [testArticle(id: testArticleId(1))]),
      messageMatcher: contains('が savedAtByIds に無いため'),
    ),
    (
      caseText: 'readIds の id が withUpdateBadge と重複 → ArgumentError',
      branch: null,
      run: (db) => seedArticles(
        db,
        withUpdateBadge: [
          testArticle(id: testArticleId(1), updatedAt: _anyUpdatedAt),
        ],
        readIds: [testArticleId(1)],
      ),
      messageMatcher: contains('readIds の id は withUpdateBadge と重複できません'),
    ),
    (
      caseText:
          'savedAtByIds・readIds の id が 3 つのリストのいずれにも無い → '
          'ArgumentError',
      branch: 'savedAtByIds',
      run: (db) => seedArticles(
        db,
        inserts: [testArticle(id: knownId)],
        savedAtByIds: {unknownId: _anySavedAt},
      ),
      // 引用符の書式（`"$id"`）に依存せず、引数名 + 違反の語で識別する。
      // 引用符の有無を変える書式変更だけではこのテストは落ちない。
      messageMatcher: allOf(
        contains('savedAtByIds の id'),
        contains('いずれにも含まれていません'),
      ),
    ),
    (
      caseText:
          'savedAtByIds・readIds の id が 3 つのリストのいずれにも無い → '
          'ArgumentError',
      branch: 'readIds',
      run: (db) => seedArticles(
        db,
        inserts: [testArticle(id: knownId)],
        readIds: [unknownId],
      ),
      messageMatcher: allOf(
        contains('readIds の id'),
        contains('いずれにも含まれていません'),
      ),
    ),
    (
      caseText: 'outOfFeed と withUpdateBadge に同じ id が別内容で入っている → ArgumentError',
      branch: null,
      run: (db) => seedArticles(
        db,
        outOfFeed: [testArticle(id: testArticleId(1), title: 'from outOfFeed')],
        withUpdateBadge: [
          testArticle(
            id: testArticleId(1),
            title: 'from withUpdateBadge',
            updatedAt: _anyUpdatedAt,
          ),
        ],
        savedAtByIds: {testArticleId(1): _anySavedAt},
      ),
      messageMatcher: contains('が別内容で'),
    ),
  ];
}

void main() {
  group('引数の検証', () {
    final cases = _buildArgumentErrorCases();

    // 表そのものを定数リストとして複製して比較すると、D-05 §7 のケース文を
    // 二重管理することになるため、ここでは distinct な caseText の件数だけ
    // を見る。
    test('表の caseText は D-05 §7 の 7 ケース分ある（件数）', () {
      expect(
        cases.map((errorCase) => errorCase.caseText).toSet(),
        hasLength(7),
      );
    });

    for (final MapEntry(key: caseText, value: casesInGroup) in groupBy(
      cases,
      (errorCase) => errorCase.caseText,
    ).entries) {
      if (casesInGroup.length == 1) {
        _argumentErrorTest(casesInGroup.single);
      } else {
        group(caseText, () {
          for (final errorCase in casesInGroup) {
            _argumentErrorTest(errorCase);
          }
        });
      }
    }
  });

  group('1 回だけ', () {
    test('0 件投入の 1 回目の後でも 2 回目は StateError', () async {
      final db = openInMemoryDatabase();

      await expectLater(seedArticles(db), completes);
      await expectLater(() => seedArticles(db), throwsStateError);
    });

    test('ArgumentError で弾かれた呼び出しは数えないので次の呼び出しが 1 回目になる', () async {
      final db = openInMemoryDatabase();
      final duplicateId = testArticleId(1);

      // ArgumentError で弾かれる呼び出し。ガードの回数に数えない。ここが
      // 「inserts の重複検証」で弾かれていること自体が前提（このメッセージ
      // でなくなったら、後段の「1 回目は成功する」検証の意味が崩れる）。
      await expectLater(
        () => seedArticles(
          db,
          inserts: [
            testArticle(id: duplicateId),
            testArticle(id: duplicateId),
          ],
        ),
        throwsA(
          isArgumentError.having(
            (e) => e.message.toString(),
            'message',
            contains(_insertsDuplicateIdMessage),
          ),
        ),
      );

      // ArgumentError は数えられていないので、0 件投入のこの呼び出しは
      // 「1 回目」として成功する。
      await expectLater(seedArticles(db), completes);
    });
  });
}
