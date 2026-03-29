# Fork Notes

This repository tracks a course-oriented `logisim-evolution` 4.1.0 build.

Scope of this repository:
- Preserve the upstream 4.1.0 application behavior used in teaching materials.
- Package a classroom-ready distribution.
- Preserve upstream license and attribution.

Current implementation details:
- `gradle.properties` sets `excludeLocales = zh`.
- `processResources` in `build.gradle.kts` already supports locale exclusion, so packaged JARs omit:
  - `resources/logisim/strings/*_zh.properties`
  - `doc/zh/**`
- `src/main/resources/resources/logisim/settings.properties` is aligned so the app no longer advertises `zh`.

Recommended GitHub publishing rules:
- Keep `LICENSE.md`, `README.md`, and upstream copyright notices.
- Publish both source and compiled artifacts together.
- Distinguish course releases by repository owner, release notes, and tag metadata.

Suggested release naming:
- Tag: `v4.1.0-course1`
- Release title: `Logisim-evolution 4.1.0`

Build command:

```bash
./gradlew shadowJar
```

Expected output:

```text
build/libs/logisim-evolution-4.1.0-all.jar
```
