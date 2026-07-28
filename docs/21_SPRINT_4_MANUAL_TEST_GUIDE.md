# Sprint 4 Manual Test Guide

Product Owner tests with `flutter run -d web-server`.

## Feature: Knowledge-based recommendations

**Test Steps**

1. Open a Recipe that is missing fish sauce, lime, or onion.
2. Ensure Pantry contains one listed substitute.
3. Review all substitute recommendations.

**Expected Results**

- Pantry-available substitutes rank first.
- Multiple substitutes are shown where the Knowledge Base provides them.
- Every result explains flavor, texture, compatibility, and limitations.
- The order is stable when data does not change.
- Users may ignore recommendations and continue cooking.

**Possible Regression Areas**

- Recipe Readiness
- Pantry matching
- Shopping recommendations
- Recipe detail responsive layout

## Feature: Advisory-only behavior

**Test Steps**

1. View and dismiss a substitution.
2. Continue to Start Cooking.
3. Check Pantry and Shopping.

**Expected Results**

- Viewing or dismissing never mutates data.
- Cooking remains available.
- No substitute is added to Pantry or Shopping automatically.

**Possible Regression Areas**

- Start Cooking
- Pantry persistence
- Shopping duplicate prevention
