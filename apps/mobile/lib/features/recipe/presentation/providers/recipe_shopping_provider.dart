import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../../shopping/application/shopping_providers.dart';
import '../../application/recipe_missing_shopping_controller.dart';

final recipeMissingShoppingControllerProvider =
    Provider<RecipeMissingShoppingController?>((ref) {
      final engine = ref.watch(shoppingEngineProvider);
      if (engine == null) {
        return null;
      }
      return RecipeMissingShoppingController(
        engine: engine,
        shoppingRepository: ref.watch(shoppingRepositoryProvider),
        executeShoppingMutation:
            ref.watch(shoppingMutationControllerProvider).execute,
        readPantry: () => ref.read(pantryProvider),
        clock: ref.watch(appClockProvider),
      );
    });
