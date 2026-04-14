// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_color_catalog_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetCategoryColorCatalogEntryCollection on Isar {
  IsarCollection<CategoryColorCatalogEntry> get categoryColorCatalogEntrys =>
      this.collection();
}

const CategoryColorCatalogEntrySchema = CollectionSchema(
  name: r'CategoryColorCatalogEntry',
  id: 3974040679340297507,
  properties: {
    r'colorKey': PropertySchema(
      id: 0,
      name: r'colorKey',
      type: IsarType.string,
    ),
    r'label': PropertySchema(id: 1, name: r'label', type: IsarType.string),
    r'sortOrder': PropertySchema(
      id: 2,
      name: r'sortOrder',
      type: IsarType.long,
    ),
  },

  estimateSize: _categoryColorCatalogEntryEstimateSize,
  serialize: _categoryColorCatalogEntrySerialize,
  deserialize: _categoryColorCatalogEntryDeserialize,
  deserializeProp: _categoryColorCatalogEntryDeserializeProp,
  idName: r'id',
  indexes: {
    r'colorKey': IndexSchema(
      id: 5363664777619181052,
      name: r'colorKey',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'colorKey',
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

  getId: _categoryColorCatalogEntryGetId,
  getLinks: _categoryColorCatalogEntryGetLinks,
  attach: _categoryColorCatalogEntryAttach,
  version: '3.3.2',
);

int _categoryColorCatalogEntryEstimateSize(
  CategoryColorCatalogEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.colorKey.length * 3;
  bytesCount += 3 + object.label.length * 3;
  return bytesCount;
}

void _categoryColorCatalogEntrySerialize(
  CategoryColorCatalogEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.colorKey);
  writer.writeString(offsets[1], object.label);
  writer.writeLong(offsets[2], object.sortOrder);
}

CategoryColorCatalogEntry _categoryColorCatalogEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CategoryColorCatalogEntry();
  object.colorKey = reader.readString(offsets[0]);
  object.id = id;
  object.label = reader.readString(offsets[1]);
  object.sortOrder = reader.readLong(offsets[2]);
  return object;
}

P _categoryColorCatalogEntryDeserializeProp<P>(
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

Id _categoryColorCatalogEntryGetId(CategoryColorCatalogEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _categoryColorCatalogEntryGetLinks(
  CategoryColorCatalogEntry object,
) {
  return [];
}

void _categoryColorCatalogEntryAttach(
  IsarCollection<dynamic> col,
  Id id,
  CategoryColorCatalogEntry object,
) {
  object.id = id;
}

extension CategoryColorCatalogEntryByIndex
    on IsarCollection<CategoryColorCatalogEntry> {
  Future<CategoryColorCatalogEntry?> getByColorKey(String colorKey) {
    return getByIndex(r'colorKey', [colorKey]);
  }

  CategoryColorCatalogEntry? getByColorKeySync(String colorKey) {
    return getByIndexSync(r'colorKey', [colorKey]);
  }

  Future<bool> deleteByColorKey(String colorKey) {
    return deleteByIndex(r'colorKey', [colorKey]);
  }

  bool deleteByColorKeySync(String colorKey) {
    return deleteByIndexSync(r'colorKey', [colorKey]);
  }

  Future<List<CategoryColorCatalogEntry?>> getAllByColorKey(
    List<String> colorKeyValues,
  ) {
    final values = colorKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'colorKey', values);
  }

  List<CategoryColorCatalogEntry?> getAllByColorKeySync(
    List<String> colorKeyValues,
  ) {
    final values = colorKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'colorKey', values);
  }

  Future<int> deleteAllByColorKey(List<String> colorKeyValues) {
    final values = colorKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'colorKey', values);
  }

  int deleteAllByColorKeySync(List<String> colorKeyValues) {
    final values = colorKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'colorKey', values);
  }

  Future<Id> putByColorKey(CategoryColorCatalogEntry object) {
    return putByIndex(r'colorKey', object);
  }

  Id putByColorKeySync(
    CategoryColorCatalogEntry object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'colorKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByColorKey(List<CategoryColorCatalogEntry> objects) {
    return putAllByIndex(r'colorKey', objects);
  }

  List<Id> putAllByColorKeySync(
    List<CategoryColorCatalogEntry> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'colorKey', objects, saveLinks: saveLinks);
  }
}

extension CategoryColorCatalogEntryQueryWhereSort
    on
        QueryBuilder<
          CategoryColorCatalogEntry,
          CategoryColorCatalogEntry,
          QWhere
        > {
  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterWhere
  >
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterWhere
  >
  anySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'sortOrder'),
      );
    });
  }
}

extension CategoryColorCatalogEntryQueryWhere
    on
        QueryBuilder<
          CategoryColorCatalogEntry,
          CategoryColorCatalogEntry,
          QWhereClause
        > {
  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterWhereClause
  >
  colorKeyEqualTo(String colorKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'colorKey', value: [colorKey]),
      );
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterWhereClause
  >
  colorKeyNotEqualTo(String colorKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'colorKey',
                lower: [],
                upper: [colorKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'colorKey',
                lower: [colorKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'colorKey',
                lower: [colorKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'colorKey',
                lower: [],
                upper: [colorKey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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

extension CategoryColorCatalogEntryQueryFilter
    on
        QueryBuilder<
          CategoryColorCatalogEntry,
          CategoryColorCatalogEntry,
          QFilterCondition
        > {
  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterFilterCondition
  >
  colorKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'colorKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterFilterCondition
  >
  colorKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'colorKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterFilterCondition
  >
  colorKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'colorKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterFilterCondition
  >
  colorKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'colorKey',
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterFilterCondition
  >
  colorKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'colorKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterFilterCondition
  >
  colorKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'colorKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterFilterCondition
  >
  colorKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'colorKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterFilterCondition
  >
  colorKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'colorKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterFilterCondition
  >
  colorKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'colorKey', value: ''),
      );
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterFilterCondition
  >
  colorKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'colorKey', value: ''),
      );
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
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

extension CategoryColorCatalogEntryQueryObject
    on
        QueryBuilder<
          CategoryColorCatalogEntry,
          CategoryColorCatalogEntry,
          QFilterCondition
        > {}

extension CategoryColorCatalogEntryQueryLinks
    on
        QueryBuilder<
          CategoryColorCatalogEntry,
          CategoryColorCatalogEntry,
          QFilterCondition
        > {}

extension CategoryColorCatalogEntryQuerySortBy
    on
        QueryBuilder<
          CategoryColorCatalogEntry,
          CategoryColorCatalogEntry,
          QSortBy
        > {
  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  sortByColorKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorKey', Sort.asc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  sortByColorKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorKey', Sort.desc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  sortByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  sortByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }
}

extension CategoryColorCatalogEntryQuerySortThenBy
    on
        QueryBuilder<
          CategoryColorCatalogEntry,
          CategoryColorCatalogEntry,
          QSortThenBy
        > {
  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  thenByColorKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorKey', Sort.asc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  thenByColorKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorKey', Sort.desc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  thenByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  thenByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<
    CategoryColorCatalogEntry,
    CategoryColorCatalogEntry,
    QAfterSortBy
  >
  thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }
}

extension CategoryColorCatalogEntryQueryWhereDistinct
    on
        QueryBuilder<
          CategoryColorCatalogEntry,
          CategoryColorCatalogEntry,
          QDistinct
        > {
  QueryBuilder<CategoryColorCatalogEntry, CategoryColorCatalogEntry, QDistinct>
  distinctByColorKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'colorKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CategoryColorCatalogEntry, CategoryColorCatalogEntry, QDistinct>
  distinctByLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'label', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CategoryColorCatalogEntry, CategoryColorCatalogEntry, QDistinct>
  distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortOrder');
    });
  }
}

extension CategoryColorCatalogEntryQueryProperty
    on
        QueryBuilder<
          CategoryColorCatalogEntry,
          CategoryColorCatalogEntry,
          QQueryProperty
        > {
  QueryBuilder<CategoryColorCatalogEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CategoryColorCatalogEntry, String, QQueryOperations>
  colorKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'colorKey');
    });
  }

  QueryBuilder<CategoryColorCatalogEntry, String, QQueryOperations>
  labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'label');
    });
  }

  QueryBuilder<CategoryColorCatalogEntry, int, QQueryOperations>
  sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortOrder');
    });
  }
}
