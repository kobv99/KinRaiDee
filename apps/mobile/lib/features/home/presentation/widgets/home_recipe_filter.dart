/// Which subset of the Top Picks list is currently shown, driven by the
/// daily summary card. [expiringSoon] is not a list filter — selecting it
/// navigates to Pantry instead (there is nothing to filter in a recipe
/// list by "ingredients expiring soon").
enum HomeRecipeFilter { all, readyToCook, pantryFriendly, quick }
