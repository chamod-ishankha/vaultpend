// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_icon_catalog_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetCategoryIconCatalogEntryCollection on Isar {
  IsarCollection<CategoryIconCatalogEntry> get categoryIconCatalogEntrys =>
      this.collection();
}

const CategoryIconCatalogEntrySchema = CollectionSchema(
  name: r'CategoryIconCatalogEntry',
  id: 8566572412407064185,
  properties: {
    r'iconKey': PropertySchema(id: 0, name: r'iconKey', type: IsarType.string),
    r'label': PropertySchema(id: 1, name: r'label', type: IsarType.string),
    r'sortOrder': PropertySchema(
      id: 2,
      name: r'sortOrder',
      type: IsarType.long,
    ),
  },

  estimateSize: _categoryIconCatalogEntryEstimateSize,
  serialize: _categoryIconCatalogEntrySerialize,
  deserialize: _categoryIconCatalogEntryDeserialize,
  deserializeProp: _categoryIconCatalogEntryDeserializeProp,
  idName: r'id',
  indexes: {
    r'iconKey': IndexSchema(
      id: 9205281669906994891,
      name: r'iconKey',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'iconKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'sortOrder': IndexSchema(
      id: -1119549396205841918,
      name: r'sortOrder',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sortOrder',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _categoryIconCatalogEntryGetId,
  getLinks: _categoryIconCatalogEntryGetLinks,
  attach: _categoryIconCatalogEntryAttach,
  version: '3.3.2',
);

int _categoryIconCatalogEntryEstimateSize(
  CategoryIconCatalogEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.iconKey.length * 3;
  bytesCount += 3 + object.label.length * 3;
  return bytesCount;
}

void _categoryIconCatalogEntrySerialize(
  CategoryIconCatalogEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.iconKey);
  writer.writeString(offsets[1], object.label);
  writer.writeLong(offsets[2], object.sortOrder);
}

CategoryIconCatalogEntry _categoryIconCatalogEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CategoryIconCatalogEntry();
  object.iconKey = reader.readString(offsets[0]);
  object.id = id;
  object.label = reader.readString(offsets[1]);
  object.sortOrder = reader.readLong(offsets[2]);
  return object;
}

P _categoryIconCatalogEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _categoryIconCatalogEntryGetId(CategoryIconCatalogEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _categoryIconCatalogEntryGetLinks(
  CategoryIconCatalogEntry object,
) {
  return [];
}

void _categoryIconCatalogEntryAttach(
  IsarCollection<dynamic> col,
  Id id,
  CategoryIconCatalogEntry object,
) {
  object.id = id;
}

extension CategoryIconCatalogEntryByIndex
    on IsarCollection<CategoryIconCatalogEntry> {
  Future<CategoryIconCatalogEntry?> getByIconKey(String iconKey) {
    return getByIndex(r'iconKey', [iconKey]);
  }

  CategoryIconCatalogEntry? getByIconKeySync(String iconKey) {
    return getByIndexSync(r'iconKey', [iconKey]);
  }

  Future<bool> deleteByIconKey(String iconKey) {
    return deleteByIndex(r'iconKey', [iconKey]);
  }

  bool deleteByIconKeySync(String iconKey) {
    return deleteByIndexSync(r'iconKey', [iconKey]);
  }

  Future<List<CategoryIconCatalogEntry?>> getAllByIconKey(
    List<String> iconKeyValues,
  ) {
    final values = iconKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'iconKey', values);
  }

  List<CategoryIconCatalogEntry?> getAllByIconKeySync(
    List<String> iconKeyValues,
  ) {
    final values = iconKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'iconKey', values);
  }

  Future<int> deleteAllByIconKey(List<String> iconKeyValues) {
    final values = iconKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'iconKey', values);
  }

  int deleteAllByIconKeySync(List<String> iconKeyValues) {
    final values = iconKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'iconKey', values);
  }

  Future<Id> putByIconKey(CategoryIconCatalogEntry object) {
    return putByIndex(r'iconKey', object);
  }

  Id putByIconKeySync(
    CategoryIconCatalogEntry object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'iconKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByIconKey(List<CategoryIconCatalogEntry> objects) {
    return putAllByIndex(r'iconKey', objects);
  }

  List<Id> putAllByIconKeySync(
    List<CategoryIconCatalogEntry> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'iconKey', objects, saveLinks: saveLinks);
  }
}

extension CategoryIconCatalogEntryQueryWhereSort
    on
        QueryBuilder<
          CategoryIconCatalogEntry,
          CategoryIconCatalogEntry,
          QWhere
        > {
  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterWhere>
  anySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'sortOrder'),
      );
    });
  }
}

extension CategoryIconCatalogEntryQueryWhere
    on
        QueryBuilder<
          CategoryIconCatalogEntry,
          CategoryIconCatalogEntry,
          QWhereClause
        > {
  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  iconKeyEqualTo(String iconKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'iconKey', value: [iconKey]),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  iconKeyNotEqualTo(String iconKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'iconKey',
                lower: [],
                upper: [iconKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'iconKey',
                lower: [iconKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'iconKey',
                lower: [iconKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'iconKey',
                lower: [],
                upper: [iconKey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  sortOrderEqualTo(int sortOrder) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'sortOrder', value: [sortOrder]),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  sortOrderNotEqualTo(int sortOrder) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [],
                upper: [sortOrder],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [sortOrder],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [sortOrder],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [],
                upper: [sortOrder],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  sortOrderGreaterThan(int sortOrder, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'sortOrder',
          lower: [sortOrder],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  sortOrderLessThan(int sortOrder, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'sortOrder',
          lower: [],
          upper: [sortOrder],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterWhereClause
  >
  sortOrderBetween(
    int lowerSortOrder,
    int upperSortOrder, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'sortOrder',
          lower: [lowerSortOrder],
          includeLower: includeLower,
          upper: [upperSortOrder],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension CategoryIconCatalogEntryQueryFilter
    on
        QueryBuilder<
          CategoryIconCatalogEntry,
          CategoryIconCatalogEntry,
          QFilterCondition
        > {
  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  iconKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'iconKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  iconKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'iconKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  iconKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'iconKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  iconKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'iconKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  iconKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'iconKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  iconKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'iconKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  iconKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'iconKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  iconKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'iconKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  iconKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'iconKey', value: ''),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  iconKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'iconKey', value: ''),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  labelEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  labelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  labelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  labelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'label',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  labelStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  labelEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  labelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  labelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'label',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  labelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'label', value: ''),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  labelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'label', value: ''),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  sortOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sortOrder', value: value),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  sortOrderGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sortOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  sortOrderLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sortOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryIconCatalogEntry,
    CategoryIconCatalogEntry,
    QAfterFilterCondition
  >
  sortOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sortOrder',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension CategoryIconCatalogEntryQueryObject
    on
        QueryBuilder<
          CategoryIconCatalogEntry,
          CategoryIconCatalogEntry,
          QFilterCondition
        > {}

extension CategoryIconCatalogEntryQueryLinks
    on
        QueryBuilder<
          CategoryIconCatalogEntry,
          CategoryIconCatalogEntry,
          QFilterCondition
        > {}

extension CategoryIconCatalogEntryQuerySortBy
    on
        QueryBuilder<
          CategoryIconCatalogEntry,
          CategoryIconCatalogEntry,
          QSortBy
        > {
  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  sortByIconKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconKey', Sort.asc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  sortByIconKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconKey', Sort.desc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  sortByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  sortByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }
}

extension CategoryIconCatalogEntryQuerySortThenBy
    on
        QueryBuilder<
          CategoryIconCatalogEntry,
          CategoryIconCatalogEntry,
          QSortThenBy
        > {
  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  thenByIconKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconKey', Sort.asc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  thenByIconKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconKey', Sort.desc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  thenByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  thenByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QAfterSortBy>
  thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }
}

extension CategoryIconCatalogEntryQueryWhereDistinct
    on
        QueryBuilder<
          CategoryIconCatalogEntry,
          CategoryIconCatalogEntry,
          QDistinct
        > {
  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QDistinct>
  distinctByIconKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'iconKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QDistinct>
  distinctByLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'label', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, CategoryIconCatalogEntry, QDistinct>
  distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortOrder');
    });
  }
}

extension CategoryIconCatalogEntryQueryProperty
    on
        QueryBuilder<
          CategoryIconCatalogEntry,
          CategoryIconCatalogEntry,
          QQueryProperty
        > {
  QueryBuilder<CategoryIconCatalogEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, String, QQueryOperations>
  iconKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'iconKey');
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, String, QQueryOperations>
  labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'label');
    });
  }

  QueryBuilder<CategoryIconCatalogEntry, int, QQueryOperations>
  sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortOrder');
    });
  }
}
