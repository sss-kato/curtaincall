// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ArticlesTable extends Articles
    with TableInfo<$ArticlesTable, ArticleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 16,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailMeta = const VerificationMeta(
    'thumbnail',
  );
  @override
  late final GeneratedColumn<String> thumbnail = GeneratedColumn<String>(
    'thumbnail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 16,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inFeedMeta = const VerificationMeta('inFeed');
  @override
  late final GeneratedColumn<bool> inFeed = GeneratedColumn<bool>(
    'in_feed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_feed" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _hasUpdateBadgeMeta = const VerificationMeta(
    'hasUpdateBadge',
  );
  @override
  late final GeneratedColumn<bool> hasUpdateBadge = GeneratedColumn<bool>(
    'has_update_badge',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_update_badge" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    title,
    url,
    category,
    publishedAt,
    fetchedAt,
    thumbnail,
    contentHash,
    updatedAt,
    inFeed,
    hasUpdateBadge,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'articles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArticleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('thumbnail')) {
      context.handle(
        _thumbnailMeta,
        thumbnail.isAcceptableOrUnknown(data['thumbnail']!, _thumbnailMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('in_feed')) {
      context.handle(
        _inFeedMeta,
        inFeed.isAcceptableOrUnknown(data['in_feed']!, _inFeedMeta),
      );
    }
    if (data.containsKey('has_update_badge')) {
      context.handle(
        _hasUpdateBadgeMeta,
        hasUpdateBadge.isAcceptableOrUnknown(
          data['has_update_badge']!,
          _hasUpdateBadgeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ArticleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArticleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      thumbnail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      inFeed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_feed'],
      )!,
      hasUpdateBadge: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_update_badge'],
      )!,
    );
  }

  @override
  $ArticlesTable createAlias(String alias) {
    return $ArticlesTable(attachedDatabase, alias);
  }
}

class ArticleRow extends DataClass implements Insertable<ArticleRow> {
  /// D-01 §8 #25。主キー。
  final String id;

  /// companies.json の id。
  final String companyId;

  /// 見出し。
  final String title;

  /// 正規化済みの URL。
  final String url;

  /// 配信の文字列のまま。
  final String category;

  /// 公開日時（UTC）。
  final DateTime publishedAt;

  /// 取得日時（UTC）。
  final DateTime fetchedAt;

  /// URL 参照のみ。無しは null。
  final String? thumbnail;

  /// 内容のハッシュ値。
  final String contentHash;

  /// 更新日時（UTC）。無しは null。
  final DateTime? updatedAt;

  /// 直近の配信（articles.json）に含まれている = ホームの 100 件の範囲内
  /// （S-01 §7.5・§8 #10）。false は「配信から外れたが保存済みなので
  /// 残している」記事（S-02 §7.3）。
  final bool inFeed;

  /// 「更新」バッジ（S-00/ST-03）。`SyncArticlesUseCase` が「更新」と判定
  /// したとき true、記事を開いた（S-00/A-10）・既読の一括クリア（S-03/A-06）
  /// で false（D-04 §5.5）。
  final bool hasUpdateBadge;
  const ArticleRow({
    required this.id,
    required this.companyId,
    required this.title,
    required this.url,
    required this.category,
    required this.publishedAt,
    required this.fetchedAt,
    this.thumbnail,
    required this.contentHash,
    this.updatedAt,
    required this.inFeed,
    required this.hasUpdateBadge,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['title'] = Variable<String>(title);
    map['url'] = Variable<String>(url);
    map['category'] = Variable<String>(category);
    map['published_at'] = Variable<DateTime>(publishedAt);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    if (!nullToAbsent || thumbnail != null) {
      map['thumbnail'] = Variable<String>(thumbnail);
    }
    map['content_hash'] = Variable<String>(contentHash);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['in_feed'] = Variable<bool>(inFeed);
    map['has_update_badge'] = Variable<bool>(hasUpdateBadge);
    return map;
  }

  ArticlesCompanion toCompanion(bool nullToAbsent) {
    return ArticlesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      title: Value(title),
      url: Value(url),
      category: Value(category),
      publishedAt: Value(publishedAt),
      fetchedAt: Value(fetchedAt),
      thumbnail: thumbnail == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnail),
      contentHash: Value(contentHash),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      inFeed: Value(inFeed),
      hasUpdateBadge: Value(hasUpdateBadge),
    );
  }

  factory ArticleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArticleRow(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      title: serializer.fromJson<String>(json['title']),
      url: serializer.fromJson<String>(json['url']),
      category: serializer.fromJson<String>(json['category']),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      thumbnail: serializer.fromJson<String?>(json['thumbnail']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      inFeed: serializer.fromJson<bool>(json['inFeed']),
      hasUpdateBadge: serializer.fromJson<bool>(json['hasUpdateBadge']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'title': serializer.toJson<String>(title),
      'url': serializer.toJson<String>(url),
      'category': serializer.toJson<String>(category),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'thumbnail': serializer.toJson<String?>(thumbnail),
      'contentHash': serializer.toJson<String>(contentHash),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'inFeed': serializer.toJson<bool>(inFeed),
      'hasUpdateBadge': serializer.toJson<bool>(hasUpdateBadge),
    };
  }

  ArticleRow copyWith({
    String? id,
    String? companyId,
    String? title,
    String? url,
    String? category,
    DateTime? publishedAt,
    DateTime? fetchedAt,
    Value<String?> thumbnail = const Value.absent(),
    String? contentHash,
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? inFeed,
    bool? hasUpdateBadge,
  }) => ArticleRow(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    title: title ?? this.title,
    url: url ?? this.url,
    category: category ?? this.category,
    publishedAt: publishedAt ?? this.publishedAt,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    thumbnail: thumbnail.present ? thumbnail.value : this.thumbnail,
    contentHash: contentHash ?? this.contentHash,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    inFeed: inFeed ?? this.inFeed,
    hasUpdateBadge: hasUpdateBadge ?? this.hasUpdateBadge,
  );
  ArticleRow copyWithCompanion(ArticlesCompanion data) {
    return ArticleRow(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      title: data.title.present ? data.title.value : this.title,
      url: data.url.present ? data.url.value : this.url,
      category: data.category.present ? data.category.value : this.category,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      thumbnail: data.thumbnail.present ? data.thumbnail.value : this.thumbnail,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      inFeed: data.inFeed.present ? data.inFeed.value : this.inFeed,
      hasUpdateBadge: data.hasUpdateBadge.present
          ? data.hasUpdateBadge.value
          : this.hasUpdateBadge,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArticleRow(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('category: $category, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('contentHash: $contentHash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('inFeed: $inFeed, ')
          ..write('hasUpdateBadge: $hasUpdateBadge')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    title,
    url,
    category,
    publishedAt,
    fetchedAt,
    thumbnail,
    contentHash,
    updatedAt,
    inFeed,
    hasUpdateBadge,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArticleRow &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.title == this.title &&
          other.url == this.url &&
          other.category == this.category &&
          other.publishedAt == this.publishedAt &&
          other.fetchedAt == this.fetchedAt &&
          other.thumbnail == this.thumbnail &&
          other.contentHash == this.contentHash &&
          other.updatedAt == this.updatedAt &&
          other.inFeed == this.inFeed &&
          other.hasUpdateBadge == this.hasUpdateBadge);
}

class ArticlesCompanion extends UpdateCompanion<ArticleRow> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> title;
  final Value<String> url;
  final Value<String> category;
  final Value<DateTime> publishedAt;
  final Value<DateTime> fetchedAt;
  final Value<String?> thumbnail;
  final Value<String> contentHash;
  final Value<DateTime?> updatedAt;
  final Value<bool> inFeed;
  final Value<bool> hasUpdateBadge;
  final Value<int> rowid;
  const ArticlesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.title = const Value.absent(),
    this.url = const Value.absent(),
    this.category = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.inFeed = const Value.absent(),
    this.hasUpdateBadge = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticlesCompanion.insert({
    required String id,
    required String companyId,
    required String title,
    required String url,
    required String category,
    required DateTime publishedAt,
    required DateTime fetchedAt,
    this.thumbnail = const Value.absent(),
    required String contentHash,
    this.updatedAt = const Value.absent(),
    this.inFeed = const Value.absent(),
    this.hasUpdateBadge = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       title = Value(title),
       url = Value(url),
       category = Value(category),
       publishedAt = Value(publishedAt),
       fetchedAt = Value(fetchedAt),
       contentHash = Value(contentHash);
  static Insertable<ArticleRow> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? title,
    Expression<String>? url,
    Expression<String>? category,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? fetchedAt,
    Expression<String>? thumbnail,
    Expression<String>? contentHash,
    Expression<DateTime>? updatedAt,
    Expression<bool>? inFeed,
    Expression<bool>? hasUpdateBadge,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (title != null) 'title': title,
      if (url != null) 'url': url,
      if (category != null) 'category': category,
      if (publishedAt != null) 'published_at': publishedAt,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (contentHash != null) 'content_hash': contentHash,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (inFeed != null) 'in_feed': inFeed,
      if (hasUpdateBadge != null) 'has_update_badge': hasUpdateBadge,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticlesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? title,
    Value<String>? url,
    Value<String>? category,
    Value<DateTime>? publishedAt,
    Value<DateTime>? fetchedAt,
    Value<String?>? thumbnail,
    Value<String>? contentHash,
    Value<DateTime?>? updatedAt,
    Value<bool>? inFeed,
    Value<bool>? hasUpdateBadge,
    Value<int>? rowid,
  }) {
    return ArticlesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      url: url ?? this.url,
      category: category ?? this.category,
      publishedAt: publishedAt ?? this.publishedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      thumbnail: thumbnail ?? this.thumbnail,
      contentHash: contentHash ?? this.contentHash,
      updatedAt: updatedAt ?? this.updatedAt,
      inFeed: inFeed ?? this.inFeed,
      hasUpdateBadge: hasUpdateBadge ?? this.hasUpdateBadge,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (thumbnail.present) {
      map['thumbnail'] = Variable<String>(thumbnail.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (inFeed.present) {
      map['in_feed'] = Variable<bool>(inFeed.value);
    }
    if (hasUpdateBadge.present) {
      map['has_update_badge'] = Variable<bool>(hasUpdateBadge.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticlesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('category: $category, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('contentHash: $contentHash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('inFeed: $inFeed, ')
          ..write('hasUpdateBadge: $hasUpdateBadge, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadStatesTable extends ReadStates
    with TableInfo<$ReadStatesTable, ReadState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [articleId, readAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'read_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    } else if (isInserting) {
      context.missing(_readAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {articleId};
  @override
  ReadState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadState(
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      )!,
    );
  }

  @override
  $ReadStatesTable createAlias(String alias) {
    return $ReadStatesTable(attachedDatabase, alias);
  }
}

class ReadState extends DataClass implements Insertable<ReadState> {
  /// [Articles.id] への外部キー。
  final String articleId;

  /// 既読にした日時（UTC）。
  final DateTime readAt;
  const ReadState({required this.articleId, required this.readAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['article_id'] = Variable<String>(articleId);
    map['read_at'] = Variable<DateTime>(readAt);
    return map;
  }

  ReadStatesCompanion toCompanion(bool nullToAbsent) {
    return ReadStatesCompanion(
      articleId: Value(articleId),
      readAt: Value(readAt),
    );
  }

  factory ReadState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadState(
      articleId: serializer.fromJson<String>(json['articleId']),
      readAt: serializer.fromJson<DateTime>(json['readAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'articleId': serializer.toJson<String>(articleId),
      'readAt': serializer.toJson<DateTime>(readAt),
    };
  }

  ReadState copyWith({String? articleId, DateTime? readAt}) => ReadState(
    articleId: articleId ?? this.articleId,
    readAt: readAt ?? this.readAt,
  );
  ReadState copyWithCompanion(ReadStatesCompanion data) {
    return ReadState(
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadState(')
          ..write('articleId: $articleId, ')
          ..write('readAt: $readAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(articleId, readAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadState &&
          other.articleId == this.articleId &&
          other.readAt == this.readAt);
}

class ReadStatesCompanion extends UpdateCompanion<ReadState> {
  final Value<String> articleId;
  final Value<DateTime> readAt;
  final Value<int> rowid;
  const ReadStatesCompanion({
    this.articleId = const Value.absent(),
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadStatesCompanion.insert({
    required String articleId,
    required DateTime readAt,
    this.rowid = const Value.absent(),
  }) : articleId = Value(articleId),
       readAt = Value(readAt);
  static Insertable<ReadState> custom({
    Expression<String>? articleId,
    Expression<DateTime>? readAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (articleId != null) 'article_id': articleId,
      if (readAt != null) 'read_at': readAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadStatesCompanion copyWith({
    Value<String>? articleId,
    Value<DateTime>? readAt,
    Value<int>? rowid,
  }) {
    return ReadStatesCompanion(
      articleId: articleId ?? this.articleId,
      readAt: readAt ?? this.readAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadStatesCompanion(')
          ..write('articleId: $articleId, ')
          ..write('readAt: $readAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedArticlesTable extends SavedArticles
    with TableInfo<$SavedArticlesTable, SavedArticleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [articleId, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_articles';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedArticleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {articleId};
  @override
  SavedArticleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedArticleRow(
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $SavedArticlesTable createAlias(String alias) {
    return $SavedArticlesTable(attachedDatabase, alias);
  }
}

class SavedArticleRow extends DataClass implements Insertable<SavedArticleRow> {
  /// [Articles.id] への外部キー。
  final String articleId;

  /// 保存操作の日時（端末時計、UTC）。S-02 §7.1 の並び順キー。
  final DateTime savedAt;
  const SavedArticleRow({required this.articleId, required this.savedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['article_id'] = Variable<String>(articleId);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  SavedArticlesCompanion toCompanion(bool nullToAbsent) {
    return SavedArticlesCompanion(
      articleId: Value(articleId),
      savedAt: Value(savedAt),
    );
  }

  factory SavedArticleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedArticleRow(
      articleId: serializer.fromJson<String>(json['articleId']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'articleId': serializer.toJson<String>(articleId),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  SavedArticleRow copyWith({String? articleId, DateTime? savedAt}) =>
      SavedArticleRow(
        articleId: articleId ?? this.articleId,
        savedAt: savedAt ?? this.savedAt,
      );
  SavedArticleRow copyWithCompanion(SavedArticlesCompanion data) {
    return SavedArticleRow(
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedArticleRow(')
          ..write('articleId: $articleId, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(articleId, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedArticleRow &&
          other.articleId == this.articleId &&
          other.savedAt == this.savedAt);
}

class SavedArticlesCompanion extends UpdateCompanion<SavedArticleRow> {
  final Value<String> articleId;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const SavedArticlesCompanion({
    this.articleId = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedArticlesCompanion.insert({
    required String articleId,
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : articleId = Value(articleId),
       savedAt = Value(savedAt);
  static Insertable<SavedArticleRow> custom({
    Expression<String>? articleId,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (articleId != null) 'article_id': articleId,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedArticlesCompanion copyWith({
    Value<String>? articleId,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return SavedArticlesCompanion(
      articleId: articleId ?? this.articleId,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedArticlesCompanion(')
          ..write('articleId: $articleId, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  /// 設定キー。
  final String key;

  /// 設定値。
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ArticlesTable articles = $ArticlesTable(this);
  late final $ReadStatesTable readStates = $ReadStatesTable(this);
  late final $SavedArticlesTable savedArticles = $SavedArticlesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    articles,
    readStates,
    savedArticles,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'articles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('read_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'articles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_articles', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ArticlesTableCreateCompanionBuilder = ArticlesCompanion Function({
  required String id,
  required String companyId,
  required String title,
  required String url,
  required String category,
  required DateTime publishedAt,
  required DateTime fetchedAt,
  Value<String?> thumbnail,
  required String contentHash,
  Value<DateTime?> updatedAt,
  Value<bool> inFeed,
  Value<bool> hasUpdateBadge,
  Value<int> rowid,
});
typedef $$ArticlesTableUpdateCompanionBuilder = ArticlesCompanion Function({
  Value<String> id,
  Value<String> companyId,
  Value<String> title,
  Value<String> url,
  Value<String> category,
  Value<DateTime> publishedAt,
  Value<DateTime> fetchedAt,
  Value<String?> thumbnail,
  Value<String> contentHash,
  Value<DateTime?> updatedAt,
  Value<bool> inFeed,
  Value<bool> hasUpdateBadge,
  Value<int> rowid,
});

final class $$ArticlesTableReferences
    extends BaseReferences<_$AppDatabase, $ArticlesTable, ArticleRow> {
  $$ArticlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ReadStatesTable, List<ReadState>>
  _readStatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.readStates,
    aliasName: $_aliasNameGenerator(db.articles.id, db.readStates.articleId),
  );

  $$ReadStatesTableProcessedTableManager get readStatesRefs {
    final manager = $$ReadStatesTableTableManager(
      $_db,
      $_db.readStates,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_readStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SavedArticlesTable, List<SavedArticleRow>>
  _savedArticlesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.savedArticles,
    aliasName: $_aliasNameGenerator(db.articles.id, db.savedArticles.articleId),
  );

  $$SavedArticlesTableProcessedTableManager get savedArticlesRefs {
    final manager = $$SavedArticlesTableTableManager(
      $_db,
      $_db.savedArticles,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_savedArticlesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ArticlesTableFilterComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnail => $composableBuilder(
    column: $table.thumbnail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inFeed => $composableBuilder(
    column: $table.inFeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasUpdateBadge => $composableBuilder(
    column: $table.hasUpdateBadge,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> readStatesRefs(
    Expression<bool> Function($$ReadStatesTableFilterComposer f) f,
  ) {
    final $$ReadStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readStates,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadStatesTableFilterComposer(
            $db: $db,
            $table: $db.readStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> savedArticlesRefs(
    Expression<bool> Function($$SavedArticlesTableFilterComposer f) f,
  ) {
    final $$SavedArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedArticles,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedArticlesTableFilterComposer(
            $db: $db,
            $table: $db.savedArticles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArticlesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnail => $composableBuilder(
    column: $table.thumbnail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inFeed => $composableBuilder(
    column: $table.inFeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasUpdateBadge => $composableBuilder(
    column: $table.hasUpdateBadge,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArticlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<String> get thumbnail =>
      $composableBuilder(column: $table.thumbnail, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get inFeed =>
      $composableBuilder(column: $table.inFeed, builder: (column) => column);

  GeneratedColumn<bool> get hasUpdateBadge => $composableBuilder(
    column: $table.hasUpdateBadge,
    builder: (column) => column,
  );

  Expression<T> readStatesRefs<T extends Object>(
    Expression<T> Function($$ReadStatesTableAnnotationComposer a) f,
  ) {
    final $$ReadStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readStates,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.readStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> savedArticlesRefs<T extends Object>(
    Expression<T> Function($$SavedArticlesTableAnnotationComposer a) f,
  ) {
    final $$SavedArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedArticles,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.savedArticles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArticlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArticlesTable,
          ArticleRow,
          $$ArticlesTableFilterComposer,
          $$ArticlesTableOrderingComposer,
          $$ArticlesTableAnnotationComposer,
          $$ArticlesTableCreateCompanionBuilder,
          $$ArticlesTableUpdateCompanionBuilder,
          (ArticleRow, $$ArticlesTableReferences),
          ArticleRow,
          PrefetchHooks Function({bool readStatesRefs, bool savedArticlesRefs})
        > {
  $$ArticlesTableTableManager(_$AppDatabase db, $ArticlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<DateTime> publishedAt = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<String?> thumbnail = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> inFeed = const Value.absent(),
                Value<bool> hasUpdateBadge = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticlesCompanion(
                id: id,
                companyId: companyId,
                title: title,
                url: url,
                category: category,
                publishedAt: publishedAt,
                fetchedAt: fetchedAt,
                thumbnail: thumbnail,
                contentHash: contentHash,
                updatedAt: updatedAt,
                inFeed: inFeed,
                hasUpdateBadge: hasUpdateBadge,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String title,
                required String url,
                required String category,
                required DateTime publishedAt,
                required DateTime fetchedAt,
                Value<String?> thumbnail = const Value.absent(),
                required String contentHash,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> inFeed = const Value.absent(),
                Value<bool> hasUpdateBadge = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticlesCompanion.insert(
                id: id,
                companyId: companyId,
                title: title,
                url: url,
                category: category,
                publishedAt: publishedAt,
                fetchedAt: fetchedAt,
                thumbnail: thumbnail,
                contentHash: contentHash,
                updatedAt: updatedAt,
                inFeed: inFeed,
                hasUpdateBadge: hasUpdateBadge,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ArticlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({readStatesRefs = false, savedArticlesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (readStatesRefs) db.readStates,
                    if (savedArticlesRefs) db.savedArticles,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (readStatesRefs)
                        await $_getPrefetchedData<
                          ArticleRow,
                          $ArticlesTable,
                          ReadState
                        >(
                          currentTable: table,
                          referencedTable: $$ArticlesTableReferences
                              ._readStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArticlesTableReferences(
                                db,
                                table,
                                p0,
                              ).readStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.articleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (savedArticlesRefs)
                        await $_getPrefetchedData<
                          ArticleRow,
                          $ArticlesTable,
                          SavedArticleRow
                        >(
                          currentTable: table,
                          referencedTable: $$ArticlesTableReferences
                              ._savedArticlesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArticlesTableReferences(
                                db,
                                table,
                                p0,
                              ).savedArticlesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.articleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ArticlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArticlesTable,
      ArticleRow,
      $$ArticlesTableFilterComposer,
      $$ArticlesTableOrderingComposer,
      $$ArticlesTableAnnotationComposer,
      $$ArticlesTableCreateCompanionBuilder,
      $$ArticlesTableUpdateCompanionBuilder,
      (ArticleRow, $$ArticlesTableReferences),
      ArticleRow,
      PrefetchHooks Function({bool readStatesRefs, bool savedArticlesRefs})
    >;
typedef $$ReadStatesTableCreateCompanionBuilder = ReadStatesCompanion Function({
  required String articleId,
  required DateTime readAt,
  Value<int> rowid,
});
typedef $$ReadStatesTableUpdateCompanionBuilder = ReadStatesCompanion Function({
  Value<String> articleId,
  Value<DateTime> readAt,
  Value<int> rowid,
});

final class $$ReadStatesTableReferences
    extends BaseReferences<_$AppDatabase, $ReadStatesTable, ReadState> {
  $$ReadStatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ArticlesTable _articleIdTable(_$AppDatabase db) =>
      db.articles.createAlias(
        $_aliasNameGenerator(db.readStates.articleId, db.articles.id),
      );

  $$ArticlesTableProcessedTableManager get articleId {
    final $_column = $_itemColumn<String>('article_id')!;

    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadStatesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadStatesTable> {
  $$ReadStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadStatesTable> {
  $$ReadStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadStatesTable> {
  $$ReadStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadStatesTable,
          ReadState,
          $$ReadStatesTableFilterComposer,
          $$ReadStatesTableOrderingComposer,
          $$ReadStatesTableAnnotationComposer,
          $$ReadStatesTableCreateCompanionBuilder,
          $$ReadStatesTableUpdateCompanionBuilder,
          (ReadState, $$ReadStatesTableReferences),
          ReadState,
          PrefetchHooks Function({bool articleId})
        > {
  $$ReadStatesTableTableManager(_$AppDatabase db, $ReadStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> articleId = const Value.absent(),
                Value<DateTime> readAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadStatesCompanion(
                articleId: articleId,
                readAt: readAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String articleId,
                required DateTime readAt,
                Value<int> rowid = const Value.absent(),
              }) => ReadStatesCompanion.insert(
                articleId: articleId,
                readAt: readAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReadStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (articleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.articleId,
                        referencedTable: $$ReadStatesTableReferences
                            ._articleIdTable(db),
                        referencedColumn: $$ReadStatesTableReferences
                            ._articleIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadStatesTable,
      ReadState,
      $$ReadStatesTableFilterComposer,
      $$ReadStatesTableOrderingComposer,
      $$ReadStatesTableAnnotationComposer,
      $$ReadStatesTableCreateCompanionBuilder,
      $$ReadStatesTableUpdateCompanionBuilder,
      (ReadState, $$ReadStatesTableReferences),
      ReadState,
      PrefetchHooks Function({bool articleId})
    >;
typedef $$SavedArticlesTableCreateCompanionBuilder =
    SavedArticlesCompanion Function({
      required String articleId,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$SavedArticlesTableUpdateCompanionBuilder =
    SavedArticlesCompanion Function({
      Value<String> articleId,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

final class $$SavedArticlesTableReferences
    extends
        BaseReferences<_$AppDatabase, $SavedArticlesTable, SavedArticleRow> {
  $$SavedArticlesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ArticlesTable _articleIdTable(_$AppDatabase db) =>
      db.articles.createAlias(
        $_aliasNameGenerator(db.savedArticles.articleId, db.articles.id),
      );

  $$ArticlesTableProcessedTableManager get articleId {
    final $_column = $_itemColumn<String>('article_id')!;

    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedArticlesTableFilterComposer
    extends Composer<_$AppDatabase, $SavedArticlesTable> {
  $$SavedArticlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedArticlesTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedArticlesTable> {
  $$SavedArticlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedArticlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedArticlesTable> {
  $$SavedArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedArticlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedArticlesTable,
          SavedArticleRow,
          $$SavedArticlesTableFilterComposer,
          $$SavedArticlesTableOrderingComposer,
          $$SavedArticlesTableAnnotationComposer,
          $$SavedArticlesTableCreateCompanionBuilder,
          $$SavedArticlesTableUpdateCompanionBuilder,
          (SavedArticleRow, $$SavedArticlesTableReferences),
          SavedArticleRow,
          PrefetchHooks Function({bool articleId})
        > {
  $$SavedArticlesTableTableManager(_$AppDatabase db, $SavedArticlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> articleId = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedArticlesCompanion(
                articleId: articleId,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String articleId,
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedArticlesCompanion.insert(
                articleId: articleId,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedArticlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (articleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.articleId,
                        referencedTable: $$SavedArticlesTableReferences
                            ._articleIdTable(db),
                        referencedColumn: $$SavedArticlesTableReferences
                            ._articleIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SavedArticlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedArticlesTable,
      SavedArticleRow,
      $$SavedArticlesTableFilterComposer,
      $$SavedArticlesTableOrderingComposer,
      $$SavedArticlesTableAnnotationComposer,
      $$SavedArticlesTableCreateCompanionBuilder,
      $$SavedArticlesTableUpdateCompanionBuilder,
      (SavedArticleRow, $$SavedArticlesTableReferences),
      SavedArticleRow,
      PrefetchHooks Function({bool articleId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ArticlesTableTableManager get articles =>
      $$ArticlesTableTableManager(_db, _db.articles);
  $$ReadStatesTableTableManager get readStates =>
      $$ReadStatesTableTableManager(_db, _db.readStates);
  $$SavedArticlesTableTableManager get savedArticles =>
      $$SavedArticlesTableTableManager(_db, _db.savedArticles);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
