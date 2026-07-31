import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/core/services/storage_service.dart';
import 'package:mobile/features/recipe/data/datasources/local_recipe_datasource.dart';
import 'package:mobile/features/recipe/data/repositories/local_recipe_repository.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kinraidee_recipe_fav_');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageService.pantryBoxName);
  });

  tearDown(() async {
    await Hive.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('favorite recipe ids start empty', () {
    const repository = LocalRecipeRepository(LocalRecipeDataSource());

    expect(repository.getFavoriteRecipeIds(), isEmpty);
  });

  test('saved favorite recipe ids survive closing and reopening Hive', () async {
    const repository = LocalRecipeRepository(LocalRecipeDataSource());

    await repository.saveFavoriteRecipeIds(<String>{'fried-rice', 'omelette'});
    expect(
      repository.getFavoriteRecipeIds(),
      <String>{'fried-rice', 'omelette'},
    );

    await Hive.close();
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageService.pantryBoxName);

    const reopened = LocalRecipeRepository(LocalRecipeDataSource());
    expect(
      reopened.getFavoriteRecipeIds(),
      <String>{'fried-rice', 'omelette'},
    );
  });

  test('saving favorites overwrites the previous set', () async {
    const repository = LocalRecipeRepository(LocalRecipeDataSource());

    await repository.saveFavoriteRecipeIds(<String>{'fried-rice'});
    await repository.saveFavoriteRecipeIds(<String>{'omelette'});

    expect(repository.getFavoriteRecipeIds(), <String>{'omelette'});
  });

  test('blank and whitespace-only ids are dropped when saving', () async {
    const repository = LocalRecipeRepository(LocalRecipeDataSource());

    await repository.saveFavoriteRecipeIds(<String>{'  ', '', 'omelette '});

    expect(repository.getFavoriteRecipeIds(), <String>{'omelette'});
  });
}
