/// Presentation-only. Must never influence execution state.
enum AnimationStyle {
  neon,
  floating3d,
  liquid,
  particle,
  minimal,
  cinematic;

  static AnimationStyle fromName(String? name) =>
      AnimationStyle.values.firstWhere(
        (s) => s.name == name,
        orElse: () => AnimationStyle.neon,
      );
}