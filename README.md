# RT-Extension-AttachmentsColored

## Funkciók
- csatolmányok táblázatos megjelenítése
- csatolmányok színezése 
  - ![#C61800](https://placehold.it/15/C61800/000000?text=+) piros
  - ![#1851CE](https://placehold.it/15/1851CE/000000?text=+) kék 
  - ![#FFCF00](https://placehold.it/15/FFCF00/000000?text=+) zöld 
  - ![#31B639](https://placehold.it/15/31B639/000000?text=+) sárga
- csatolmányok elrejtése
- csatolmányok kategorizálása
- csatolmányokhoz megjegyzés hozzáfűzése
- kép-csatolmányoknak miniatűr megjelenítése

## RT kompatibilitás
- RT 5.0.x

## Telepítés
1. végrehaitani a következő parancsokat
````bash
cd /opt/rt5/local/plugins
git clone https://github.com/DOCCA-CO/RT-Extension-AttachmentsColored.git
````

2. importálni az `initaldata` fájlt.
````bash
/opt/rt5/sbin/rt-setup-database --action insert --datafile /opt/rt5/local/plugins/RT-Extension-AttachmentsColored/etc/initialdata
````

Ez létrehoz egy polcot: `Lista: Alapdokumentum` egy üggyel. Ennek az ügynek a számát kell a `DefaultFolderStructureTicketID` konfigparaméterben  megadni
3. beállítani a megfelelő paramérereket a `./etc/AttachmentsColored_Config.pm` fájlban. Lásd a `Konfigurálás` szekciót.

4. az  `/opt/rt5/etc/RT_SiteConfig.pm` fájlba beírni
````perl
Plugin('RT::Extension::AttachmentsColored');
````

5. töröli a cache-t
````bash
rm -rf /opt/rt5/var/mason_data/obj
````

6. újraindítani a web-szervert.

### Függőségek

A modul a `JSON` perl-modultól függ. A modult a `cpan` paranccsal lehet telepíteni.

````cpan
cpan -i JSON
````

## Konfigurálás
a plugin működéséhez szükséges paraméterek:
| Paraméter neve | Típus | Lehetséges értékek | Megjegyzés |
|---|---|---|---|
| `AttachmentCategories` | hash | | Csatolmányok színei, RGB formátumban |
| `DefaultFolderStructureTicketID` | integer | | Az ügyszám, ahol az alapértelmezett kategóriák vannak |

#### Példa
````perl

Set(%AttachmentCategories, (
  'A' => '#FF6347',
  'B' => '#90EE90',
  'C' => '#87CEFA',
  'D' => '#fCDC8C',
  'hidden' => '#DCDCDC'
));

Set($DefaultFolderStructureTicketID, 123);

1;
````
