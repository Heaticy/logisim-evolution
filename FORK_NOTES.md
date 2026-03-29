# Fork Notes

This repository is an unofficial fork of `logisim-evolution` 4.1.0.

Scope of this fork:
- Exclude the `zh` locale from packaged builds.
- Exclude Chinese help files from packaged builds.
- Preserve upstream license and attribution.

Current implementation:
- `gradle.properties` sets `excludeLocales = zh`.
- `processResources` in `build.gradle.kts` already supports locale exclusion, so packaged JARs omit:
  - `resources/logisim/strings/*_zh.properties`
  - `doc/zh/**`
- `src/main/resources/resources/logisim/settings.properties` is aligned so the app no longer advertises `zh`.

Recommended GitHub publishing rules:
- Keep `LICENSE.md`, `README.md`, and upstream copyright notices.
- Mark releases as unofficial.
- Publish both source and compiled artifacts together.
- Avoid using the fork as if it were an official upstream release.

Suggested release naming:
- Tag: `v4.1.0-no-zh`
- Release title: `4.1.0 no-zh (unofficial)`

Build command:

```bash
./gradlew shadowJar
```

Expected output:

```text
build/libs/logisim-evolution-4.1.0-all.jar
```
