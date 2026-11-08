# Pliki i narzędzia

## Ręczne wskazanie katalogu gry

Jeśli automatyczne wykrycie biblioteki Steam się nie powiedzie, uruchom PowerShell w folderze paczki i wskaż własny katalog:

```powershell
.\Spolszczenie.ps1 -Action Check -GamePath 'X:\SteamLibrary\steamapps\common\Theme Hospital'
.\Spolszczenie.ps1 -Action Install -GamePath 'X:\SteamLibrary\steamapps\common\Theme Hospital'
.\Spolszczenie.ps1 -Action Uninstall -GamePath 'X:\SteamLibrary\steamapps\common\Theme Hospital'
```

Zastąp przykładową ścieżkę rzeczywistym położeniem gry. Aktualizację z 0.1 uruchom przez `Aktualizuj.ps1 -GamePath '…'`.

Pliki `.cmd` uruchamiają Windows PowerShell bez profilu. Używają `-ExecutionPolicy Bypass` wyłącznie dla własnego procesu; nie zmieniają stałej polityki wykonywania skryptów.

## Jak działa patch

`LANG-0.DAT` zawiera 68 sekcji i 2610 wpisów zakończonych bajtem zerowym. Patch zachowuje liczbę i kolejność wpisów. Zamienniki UTF-8 z `patch.json` są kodowane lokalnie do jednobajtowego formatu gry. Polskie litery używają wartości 176–193.

Czcionki korzystają z par DAT/TAB; rekord TAB ma 6 bajtów: offset, szerokość i wysokość. Indeks znaku odpowiada wartości bajtu pomniejszonej o 31. Instalator w razie potrzeby dekompresuje oryginalny zasób RNC i nakłada operacje `copy` oraz `data` zapisane w manifeście.

W plikach EASY00, FULL00, HARD00 i NET00 z katalogu LEVELS zmieniana jest etykieta `&0`. Parametry gry i pozostałe wersje językowe zostają bez zmian.

Każdy plik ma kontrolną sumę SHA-256 przed i po zmianie. Instalator sprawdza też EXE, dekompresor i backup. Nieznana zawartość powoduje przerwanie operacji. Pliki fontów są wspólne dla języków, dlatego przed zmianą języka w Steam odinstaluj patch.

`patch.json` jest gotową, sprawdzoną postacią danych patcha. Samodzielna edycja tekstów zmieni hash wyniku. Nie usuwaj kontroli sum, żeby wymusić instalację; nowe wydanie wymaga ponownego zbudowania i przetestowania wynikowych plików na własnych oryginałach.

## Źródła

Kod nakładania patcha znajduje się w `Spolszczenie.ps1`. `Aktualizuj.ps1` obsługuje przejście z 0.1. Dane poprzedniej wersji są zachowane wyłącznie na potrzeby jej odinstalowania i odzyskania po błędzie aktualizacji.

`src/upstream` zawiera wykorzystane pliki CorsixTH, z oryginalnymi notami MIT. `src/changes-0.1.json` i `src/changes-0.2.json` dokumentują dodatkowe teksty i poprawki. Robocze skrypty sterujące oknami gry i prywatne raporty z komputera nie są częścią wydania publicznego.

Źródła narzędzia RNC znajdują się w `src/rnc`. Przykładowa kompilacja w wierszu poleceń dewelopera Visual C++, z katalogu źródeł:

```text
cl /nologo /std:c++17 /O2 /EHsc /MT rnc.cpp rnc_decode_cli.cpp /Fe:rnc_decode.exe
```

Wynik innego kompilatora lub zestawu flag może mieć inną sumę. Manifest obecnego wydania akceptuje wyłącznie dostarczony, przetestowany plik EXE. Ponowna kompilacja wymaga aktualizacji sum i testów.

## Kontrola i zbudowanie ZIP-a

Narzędzia korzystają wyłącznie z biblioteki standardowej Pythona 3.9 lub nowszego. Nie odczytują instalacji gry:

```text
python tools/verify_package.py
python tools/build_release.py --output dist/ThemeHospital-PL-0.2-beta-public.zip
```

ZIP powstaje z jawnej listy w `SHA256SUMS.json`. Pliki spoza tej listy, w tym `.git`, zapisy i katalogi robocze, nie trafiają do paczki. Narzędzie odmawia nadpisania istniejącego archiwum.

Przy przygotowaniu kolejnego wydania sprawdź zawartość listy i zaktualizuj sumy dopiero po przeglądzie wszystkich zmian. Nie dodawaj do repozytorium własnej instalacji gry, folderów SAVE i `.thpl` ani prywatnych logów.
