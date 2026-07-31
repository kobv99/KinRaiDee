# Recommendation Configuration Guide

Use `RecommendationConfiguration` and `RecommendationWeights` in the domain
layer. Do not place thresholds or weights in Widgets.

Configurable values include:

- all scoring weights;
- expiring-soon day window;
- quick-meal minutes;
- complexity ingredient threshold;
- recently-cooked day window;
- Pantry Friendly match threshold;
- few-missing threshold;
- healthy Recipe tags.
- maximum missing required ingredients for almost-ready candidate visibility.

Weights may be zero. The engine normalizes by their total, so configurations do
not need to sum to one. Configuration should later be loaded from a versioned
local or remote data source behind a repository boundary.
