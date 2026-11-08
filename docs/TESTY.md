# Co sprawdzono w wersji 0.2

Testy wykonano dla Steam App ID **2229820**, build **25682708**, z oryginalnym `HOSPITAL.EXE` i DOSBoxem. Instalator uruchamiano w Windows PowerShell 5.1.

## Pliki i instalator

Sprawdzono strukturę wszystkich 2610 wpisów, kodowanie, argumenty formatowania oraz podziały `//`. W 44 rodzinach czcionek zweryfikowano polskie glify. Dwie z tych rodzin są oryginalnie przeznaczone wyłącznie do wielkich liter; pozostałe 42 mają wszystkie 18 polskich znaków.

Testy instalatora objęły:

- sprawdzanie zgodności bez zapisu do gry;
- instalację 93 plików i kontrolę wszystkich kopii zapasowych;
- odmowę ponownej instalacji oraz nadpisania obcej zmiany;
- wykrycie uszkodzonego backupu i nieznanej wersji EXE;
- odzyskanie danych po przerwaniu instalacji;
- automatyczne wycofanie zmian po wymuszonym błędzie podmiany;
- powtarzane cykle instalacji i przywrócenia oryginalnych sum kontrolnych;
- aktualizację z 0.1 do 0.2 oraz zachowanie poprzedniej wersji.

Zbiorczy wynik testów instalatora jest w [tests.json](tests.json). Nie zawiera ścieżek komputera, nazw profili gracza ani sum zapisów rozgrywki.

## Testy w grze

Na oddzielnej kopii otwarto szpitale **1–12** parametrem `-L`. Każdy poziom się wczytał; obejrzano polskie odprawy i ich ułożenie w oknach. Potwierdzono także start patcha przez Steam i działanie szpitala z polskim interfejsem.

Na ekranie trudności obejrzano napis „Lekarz (średni)”. Pozostałe nazwy trudności sprawdzono w danych i kodowaniu. W czterech plikach `LEVELS/*00.SAM` zmienia się tylko angielska etykieta `&0`. Reszta plików jest identyczna z oryginałem.

## Czego te testy nie potwierdzają

Nie przechodzono całej kampanii. Nie sprawdzono każdego okna, wszystkich rozdzielczości ani rozgrywki wieloosobowej. Rzadkie etykiety diagnostyczne zweryfikowano w danych; nie uruchamiano wszystkich ukrytych funkcji diagnostycznych.

Wydanie pozostaje beta. Potrzebne są dalsze zgłoszenia dotyczące korekty językowej, uciętych etykiet i łamania wierszy w rzadziej używanych oknach.
