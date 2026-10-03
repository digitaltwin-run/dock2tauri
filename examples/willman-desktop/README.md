# Willman Desktop App (Tauri Packaging)

Ten przykład pokazuje, jak za pomocą `dock2tauri` spakować lokalną konsolę Willmana (`http://127.0.0.1:8780/`) w natywną aplikację okienkową desktop (RPM, AppImage) dla systemu Fedora na Lenovo.

## Uruchomienie deweloperskie

```bash
# 1. Uruchom Willman Hub w tle
willman start

# 2. Uruchom podgląd Tauri
taurido --project-root . --app-name "Willman Desktop" --launch
```

## Budowanie natywnej paczki RPM dla Fedory

```bash
taurido --project-root . --app-name "Willman Desktop" --build
```

Paczka binarna zostanie wygenerowana w katalogu `dist/bundle/rpm/`.
