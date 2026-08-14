# Releasing Aeolus

1. Обновить `MARKETING_VERSION` и `CURRENT_PROJECT_VERSION` в `project.yml`,
   записать изменения в `CHANGELOG.md`. Закоммитить.
2. `git tag vX.Y.Z && git push origin main --tags`
3. `Scripts/release.sh X.Y.Z` — соберёт `dist/Aeolus-X.Y.Z.zip`,
   напечатает `sparkle:edSignature` и sha256.
4. `gh release create vX.Y.Z dist/Aeolus-X.Y.Z.zip --title "Aeolus X.Y.Z" --notes "<заметки из CHANGELOG>"`
5. Добавить `<item>` в `appcast.xml` (шаблон ниже), закоммитить в main:

   ```xml
   <item>
     <title>X.Y.Z</title>
     <sparkle:version>N</sparkle:version>
     <sparkle:shortVersionString>X.Y.Z</sparkle:shortVersionString>
     <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
     <enclosure
       url="https://github.com/moverq1337/Aeolus/releases/download/vX.Y.Z/Aeolus-X.Y.Z.zip"
       sparkle:edSignature="ПОДПИСЬ_ИЗ_ШАГА_3"
       length="РАЗМЕР_ФАЙЛА_В_БАЙТАХ"
       type="application/octet-stream"/>
   </item>
   ```
6. Обновить `version` и `sha256` в каске своего tap-репозитория
   (`moverq1337/homebrew-aeolus`, см. docs/dist/aeolus.rb).

Приватный ключ Sparkle живёт в Keychain этой машины (искать «Sparkle»
в Keychain Access). Сделать офлайн-бэкап: `generate_keys -x sparkle-private.key`
и убрать файл в надёжное место ВНЕ репозитория.
Потеря ключа = существующие установки не смогут обновиться.
