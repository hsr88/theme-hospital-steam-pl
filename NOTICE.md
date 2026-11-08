# Pochodzenie i zakres licencji

Nowy kod instalatora i narzędzi jest udostępniony na licencji [MIT](LICENSE). Tłumaczenie i wykorzystany kod CorsixTH zachowują własne noty praw autorskich i warunki MIT w [LICENSES](LICENSES).

Pliki `src/upstream/polish.lua` oraz `src/upstream/original_strings.lua` pochodzą z projektu [CorsixTH](https://github.com/CorsixTH/CorsixTH), z rewizji `55989c8ccd760e863ea35df831f5a8621b39c638`. Mapowanie z tego drugiego pliku posłużyło do powiązania tekstów CorsixTH z oryginalnym `LANG-0.DAT`.

Źródła dekompresora są w `src/rnc`. Plik `rnc_decode.exe` jest narzędziem zbudowanym z tego kodu, nie plikiem wykonywalnym gry. Kopia w `aktualizacja-z-0.1` służy do odtworzenia poprzedniego patcha, jeśli aktualizacja się nie powiedzie.

`patch.json` zawiera polskie zamienniki i instrukcje odczytania fragmentów własnych plików użytkownika oraz wstawienia zmian. Kompletne zmodyfikowane zasoby powstają dopiero przy instalacji. W paczce nie ma oryginalnych plików gry ani zapisów rozgrywki.

Licencje tego repozytorium nie udzielają praw do Theme Hospital, jego oryginalnych zasobów ani znaków towarowych. Zrzuty w `docs/images` pokazują działanie patcha podczas testów; nie są objęte deklaracją MIT dotyczącą nowego kodu.

Projekt jest nieoficjalny i wymaga własnej zgodnej kopii gry.
