## 1.2.0+builtin-kotlin

- Local fork for MT5 app: migrate Android build off Kotlin Gradle Plugin (KGP).
- Removes `apply plugin: "kotlin-android"` so Flutter no longer warns about plugins that apply KGP.
- Uses `kotlin { compilerOptions { ... } }` (built-in Kotlin / Flutter 3.44+).

## 1.2.0

- Upstream release (pub.dev).
