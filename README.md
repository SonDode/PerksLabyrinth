# Ghid complet de învățare — The Perks's Labyrinth

Document de studiu pentru prezentare. Acoperă: modelul mental Godot, fiecare concept
de motor și de limbaj folosit, fiecare script linie-cu-idee, algoritmii, matematica
și deciziile de design (motorul de gândire din spate).

---

## PARTEA 0 — Cum „gândește" Godot (modelul mental)

Godot e un motor bazat pe un **arbore de noduri** (Scene Tree). Trebuie să înțelegi 4 idei:

1. **Nod (Node)** = o piesă care face un singur lucru (afișează un mesh, redă sunet,
   detectează coliziuni, ține o cameră etc.). Fiecare nod are un tip care îi dă
   capabilitățile.
2. **Scenă (.tscn)** = un arbore de noduri salvat pe disc. O scenă poate fi instanțiată
   (clonată) oriunde. La noi: `MainMenu.tscn`, `Game.tscn`, `GameOver.tscn`, `Victory.tscn`.
3. **Script (.gd)** = cod atașat unui nod care îi extinde comportamentul. Scriptul
   `extends` tipul nodului (ex. `extends CharacterBody3D` → scriptul ESTE un CharacterBody3D
   cu logica ta în plus).
4. **Arborele activ** = la un moment dat rulează o singură „scenă curentă" (plus
   autoload-urile, care sunt mereu prezente). Schimbi nivelul/ecranul înlocuind scena curentă.

**Bucla de joc**: Godot apelează automat, pe fiecare nod, funcții speciale (callback-uri):
- `_ready()` — o dată, când nodul intră în arbore (inițializare).
- `_process(delta)` — în fiecare **cadru desenat** (frecvență variabilă; pentru animații vizuale).
- `_physics_process(delta)` — în fiecare **tic de fizică** (frecvență fixă; pentru mișcare/coliziuni).
- `_input(event)` / `_unhandled_input(event)` — la fiecare eveniment de intrare (tastă, mouse).

`delta` = timpul (în secunde) scurs de la cadrul anterior. Înmulțești cu el ca mișcarea
să fie **independentă de framerate** (la 30 sau 144 FPS te miști la fel).

---

## PARTEA 1 — Concepte de MOTOR folosite în proiect

### 1.1. Tipuri de noduri folosite (trebuie să știi ce face fiecare)

**3D:**
- `Node3D` — nod 3D de bază (are poziție/rotație/scală). Rădăcina scenei `Game` și containerele.
- `CharacterBody3D` — corp pentru personaje controlate de cod (jucătorul). Are `velocity` și
  metoda `move_and_slide()` care îl mută respectând coliziunile și alunecă pe pereți.
- `StaticBody3D` — corp fix (pereți, podea, tavan). Nu se mișcă, dar oprește alte corpuri.
- `Area3D` — zonă care **detectează** intrarea/ieșirea altor corpuri (nu blochează). La noi:
  obiectele de cules — știu când jucătorul intră în raza lor.
- `CollisionShape3D` — forma de coliziune a unui corp/area (capsulă la jucător, cuburi la
  pereți, sferă la obiecte). **Fără ea, corpul nu se ciocnește și Area nu detectează nimic.**
- `MeshInstance3D` — afișează o formă vizibilă (mesh) cu un material.
- `Camera3D` — ochiul jucătorului (copil al Player → se rotește odată cu el).
- `OmniLight3D` — lumină punctuală (felinarul jucătorului, lumina gardianului).
- `DirectionalLight3D` — lumină globală direcțională (ca soarele), cu umbre.
- `WorldEnvironment` — setează mediul: culoare de fundal, lumină ambientală, ajustări (luminozitate).
- `Label3D` — text 3D care poate sta mereu cu fața la cameră (billboard).

**Mesh-uri și forme (resurse):** `BoxMesh`, `SphereMesh`, `CapsuleMesh` (vizibil),
`BoxShape3D`, `SphereShape3D`, `CapsuleShape3D` (coliziune). Mesh = ce VEZI, Shape = ce SIMTE fizica.

**2D / UI (toate sub `CanvasLayer` ca să stea peste 3D):**
- `CanvasLayer` — strat 2D desenat peste lume (HUD-ul, meniul de pauză).
- `Control` — nod de bază pentru UI (are ancore, mărime, poziție).
- `Label` — text. `ProgressBar` — bară (blestemul). `HSlider` — slider (setări).
- `Button` — buton clicabil. `ColorRect` — dreptunghi colorat (fundal, dimmer).
- `PanelContainer`, `VBoxContainer`, `HBoxContainer`, `MarginContainer` — containere care
  aranjează automat copiii (vertical, orizontal, cu margini).

### 1.2. Ancorele și layout-ul UI (de ce meniul era descentrat)
Un `Control` se poziționează prin **ancore** (procent din ecran: 0=stânga/sus, 1=dreapta/jos)
+ **offset-uri** (pixeli față de ancoră). `layout_mode` decide cum se interpretează:
- `0` = „Position" (poziție liberă) — ignoră ancorele → bug-ul de centrare.
- `1` = „Anchors" (corect pentru centrare).
`grow_horizontal/vertical = 2` (BOTH) = nodul crește simetric în jurul ancorei → centrare perfectă.
`anchors_preset = 8` = preset „centru". Așa am reparat meniul.

### 1.3. Autoload (Singleton) — starea care supraviețuiește scenelor
Un script declarat în `Project Settings > Autoload` devine un nod global, creat o dată,
prezent în orice scenă, accesibil pe nume. La noi:
- **GameManager** — ține nivelul, viețile, perks, blestemul, setările. Dacă schimbi scena
  (Game → Victory), nodurile scenei dispar, dar GameManager rămâne → viețile se păstrează.
- **AudioManager** — redă sunete de oriunde, prin `AudioManager.play_...()`.

De ce autoload și nu o variabilă în Game? Pentru că la `change_scene_to_file` scena veche e
distrusă. Starea de joc TREBUIE să trăiască în afara scenei.

### 1.4. Semnale (Signals) — pattern-ul Observer
Un semnal e un „anunț" pe care un nod îl emite, iar alte noduri se „abonează" la el.
Exemplu real: `GameManager.lives_changed` e emis când se schimbă viețile; HUD-ul s-a abonat
(`GameManager.lives_changed.connect(_on_lives_changed)`) și își actualizează inimile.

**De ce e important (motorul de gândire):** decuplare. GameManager NU știe că există un HUD;
doar „strigă" că s-a schimbat ceva. Poți adăuga/șterge ascultători fără să modifici emițătorul.
Semnalele noastre: `lives_changed`, `perk_unlocked`, `game_over`, `level_complete`,
`curse_timer_started/tick/ended`. Plus semnalul propriu al jucătorului: `cell_entered`.

### 1.5. Grupuri (Groups)
Un nod poate fi pus într-un „grup" (`add_to_group("hud")`) și găsit de oriunde cu
`get_tree().get_nodes_in_group("hud")`. Folosim asta ca ItemPickup și Guardian să găsească
HUD-ul fără să știe calea exactă în arbore (mai robust dacă muți nodurile).

### 1.6. Input Map (acțiuni de input)
În loc să verifici tasta brută, definești **acțiuni** în Project Settings și le verifici pe nume.
La noi (în `project.godot`, secțiunea `[input]`):
- `move_forward` = W, `move_backward` = S, `move_left` = A, `move_right` = D
- `interact` = E, `jump` = Space
- `ui_cancel` = ESC (acțiune predefinită de Godot)
Le testezi cu `Input.is_action_pressed("nume")` (ținut apăsat) sau
`Input.is_action_just_pressed("nume")` (apăsat exact în cadrul ăsta).
**De ce:** poți schimba tastele dintr-un loc, fără să atingi codul.

### 1.7. Project Settings relevante
- `display/window` — rezoluție 1600×900, mod fullscreen, stretch `canvas_items` (UI-ul se
  scalează cu fereastra).
- `physics/common/physics_ticks_per_second = 120` — fizica rulează de 120 ori/sec. **De ce:**
  camera e copil al corpului mișcat în `_physics_process`; la 60 Hz pe un monitor rapid apărea
  „stutter" (mișcarea sacadată). 120 Hz dublează rata de actualizare → fluid.
- `[autoload]` — GameManager, AudioManager.

### 1.8. Resurse (Resources)
Date partajabile, separate de noduri: `Mesh`, `Material` (`StandardMaterial3D`), `Shape3D`,
`Environment`, `Texture2D`/`ImageTexture`, `Gradient`. Un material poate fi reutilizat pe mai
multe mesh-uri. Texturile `.jpg` devin resurse `Texture2D` după **import** (vezi 1.10).

### 1.9. Tween — animații prin cod
Un `Tween` interpolează o proprietate în timp (ex. transparența unei notificări de la 0 la 1).
`create_tween().tween_property(nod, "modulate:a", 1.0, 0.2)` = „du alfa la 1 în 0.2s".
Folosit la: notificări (apar/dispar), titlul care pulsează, obiectul care se micșorează la cules.

### 1.10. Importul resurselor (gotcha important)
Godot nu folosește direct `.jpg`-ul, ci o versiune **importată** (`.import` + cache în `.godot`).
La rularea directă a jocului (`.exe`), dacă imaginea nu e importată, `load()` eșuează. De aceea,
după ce am adăugat texturile, am rulat un import headless (`--editor --quit`).
Același lucru pentru `class_name` nou → trebuie regenerat `global_script_class_cache.cfg`.

---

## PARTEA 2 — Concepte de LIMBAJ (GDScript)

GDScript e un limbaj cu tipuri opționale, asemănător Python (indentare semnificativă).

- **Tipuri statice**: `var x: int = 0`, `func f(a: float) -> Vector3:`. Le-am folosit peste tot
  → erori prinse mai devreme, autocompletare, cod mai clar.
- `const` = constantă (nu se schimbă): `const MAX_LIVES: int = 3`.
- `@export var move_speed: float = 5.0` — variabilă editabilă în Inspector (din editor).
- `@onready var camera = $Camera3D` — se inițializează când nodul e gata; `$Nume` = ia un copil.
- **Colecții**: `Array` (listă), `Array[int]` (listă tipată), `Dictionary` (cheie→valoare).
- **Tipuri matematice**: `Vector2`, `Vector2i` (întreg), `Vector3`, `Color`.
- **Clasă internă**: `class MazeCell:` definită în MazeGenerator — un mic „obiect" cu câmpuri.
- **`class_name Player`** — face clasa globală (o poți folosi ca tip oriunde, ex.
  `var p: Player`). Necesită cache-ul de clase regenerat.
- **`match`** = switch elegant: `match item_type: "trap": ...`.
- **Operator ternar**: `var box := 208.0 if level >= 2 else 160.0`.
- **For**: `for i in 4:` (0,1,2,3) sau `for c in lista:`.
- **Lambda / Callable**: funcție anonimă, ex. la AudioManager
  `func(): _beep(...)` pasată unui timer.
- **Semnale**: `signal nume(arg)`, `emit_signal("nume", val)`, `nume.connect(functie)`.
- `await` — așteaptă (ex. `await get_tree().create_timer(1.2).timeout` = pauză de 1.2s
  fără să blochezi jocul).

---

## PARTEA 3 — Fluxul jocului (de la buton la victorie)

1. **MainMenu.tscn** pornește (e `run/main_scene`). `MainMenu.gd` conectează butoanele și
   încarcă setările salvate din GameManager în slidere.
2. Apeși **Joacă** → `GameManager.start_new_game()` (nivel=1, vieți=3, perks resetate) →
   `change_scene_to_file("Game.tscn")`.
3. **Game.tscn** se încarcă; `Game.gd._ready()` rulează:
   - `_setup_environment()` — creează mediul/luminile după configurația nivelului.
   - `_connect_signals()` — se abonează la `game_over`, `level_complete`, `cell_entered`.
   - `_generate_level()` — generează labirintul (DFS), îl construiește 3D, poziționează
     jucătorul, creează obiectele și gardianul, pregătește HUD-ul, afișează intro-ul.
4. **Joci**: în `_physics_process`, Player citește tastele, calculează direcția, aplică
   gravitația, `move_and_slide()`. Mouse-ul rotește privirea în `_unhandled_input`. Când treci
   într-o celulă nouă, Player emite `cell_entered` → Game actualizează minimapa. În fiecare
   cadru, Game actualizează busola. Gardianul te urmărește (BFS).
5. **Obiecte**: intri în raza unui Area3D → dacă e bun, apare „[ E ]"; apeși E → efect. Dacă e
   capcană/blestem → efect automat. Efectul concret e în `GameManager.collect_item()`.
6. **Final**: vieți=0 → semnal `game_over` → ecran GameOver. Ajungi la ieșire → `level_complete`
   → dacă mai sunt nivele, `next_level()` + reîncarci Game; altfel ecran Victory.
7. **ESC** → PauseMenu (oprește jocul, eliberează mouse-ul): Continuă / Restart nivel / Meniu.

---

## PARTEA 4 — Fiecare script în detaliu

### 4.1. GameManager.gd (Autoload) — „creierul" stării
- **Ce ține**: `current_level`, `lives`, `perks_unlocked` (dicționar), `items_collected`,
  starea blestemului, setările (`brightness`, `volume`, `mouse_sensitivity`).
- **Semnale**: anunță restul jocului despre orice schimbare.
- `_process(delta)`: dacă blestemul e activ, scade `_curse_timer`; la 0 → `_on_curse_expired()`
  (emite final de blestem + `lose_life`). Aici „trăiește" timerul.
- `start_new_game()` (nivel 1 + reset), `next_level()` (păstrează viețile, resetează perks),
  `restart_level()` (reset, păstrează nivelul), `reset()` (vieți+perks+blestem).
  **De ce 3 funcții diferite:** fiecare tranziție păstrează/resetează altceva — asta E logica
  de progresie.
- `collect_item(tip)`: un `match` care leagă fiecare tip de obiect de efectul lui (deblochează
  perk / +viață / pornește blestem / -viață / nivel complet). **Punct cheie:** efectele sunt
  centralizate aici, nu împrăștiate prin obiecte.
- `lose_life()`: scade, emite `lives_changed`; dacă ≤ 0 emite `game_over`.
- `gain_life()`: `lives += 1` **fără plafon** (cerința ta — fiecare perk adaugă o viață).
- Setări: `set_brightness` (caută WorldEnvironment-ul și ajustează), `set_volume` (bus-ul
  Master prin `AudioServer`, `linear_to_db`), `set_mouse_sensitivity` (multiplicator × valoarea
  de bază). Toate persistă pentru că trăiesc în autoload.

### 4.2. MazeGenerator.gd — generarea procedurală + pathfinding
- **MazeCell** (clasă internă): `walls[N,E,S,V]` (true=perete), `visited`, `item`, `is_start`,
  `is_exit`, `x`, `y`.
- `generate(w,h,...)`: inițializează grila plină de pereți, sapă (`_carve_from`), plasează
  start/ieșire și obiectele.
- `_carve_from(cx,cy)` — **DFS „Recursive Backtracking"** (vezi Partea 5.1).
- `_place_start_exit()`: start (0,0), ieșire în colțul opus.
- `_place_items(...)`: separă fundăturile (3 pereți) de restul, le amestecă, pune întâi
  perks+vieți+blesteme (prioritar în fundături, ca să explorezi), apoi umple cu capcane.
- `next_step_toward(...)` — **BFS** (vezi Partea 5.2): următoarea celulă pe cel mai scurt drum
  spre jucător. Folosit de gardian.
- `get_cell(x,y)`: întoarce celula sau `null` dacă e în afara grilei (verificare de limite).

### 4.3. MazeBuilder.gd — geometria 3D
- `build(maze)`: pregătește materialele texturate, șterge geometria veche, ridică pereții
  fiecărei celule, adaugă podea+tavan.
- `_add_wall(pos,size)`: creează un `StaticBody3D` cu `MeshInstance3D` (cub) + `CollisionShape3D`
  (cub). Poziționat pe muchia celulei, ridicat la jumătate din înălțime.
  **Atenție la prezentare:** poziția pereților N/E/S/V e calculată din centrul celulei ±
  jumătate de celulă.
- `_add_floor_ceiling`: un singur cub mare pentru podea (la y≈0) și unul pentru tavan
  (peste pereți). `uv1_scale` mare → textura se repetă pe celule (tiling).
- `_make_mat(...)`: material standard cu `albedo_texture` (+ `normal_texture` pentru relief).

### 4.4. Player.gd — controlul jucătorului
- `extends CharacterBody3D`. Stochează `grid_x/grid_y` (celula), `_yaw` (rotația), referințe.
- `_unhandled_input`: mișcarea mouse-ului schimbă `_yaw` cu
  `relative.x * GameManager.mouse_sensitivity` → setează `rotation.y`. Rotire continuă, lină.
- `_physics_process(delta)`: (1) E → interact; (2) calculează `wish` (direcția dorită) din
  `forward`/`right` × taste; (3) accelerează lin spre viteză cu `move_toward`; (4) gravitație:
  dacă `is_on_floor()` → y=0 (sau săritură la Space), altfel `velocity.y -= gravity*delta`;
  (5) `move_and_slide()`; (6) `_update_grid_cell()`.
- `_update_grid_cell()`: transformă poziția în celulă (`round(pos/cell_size)`); dacă s-a
  schimbat, emite `cell_entered`. Așa minimapa și busola știu unde ești.
- `set_light()`: reglează felinarul (mai mic pe nivelul 2 = mai întuneric).

### 4.5. Guardian.gd — NPC-ul cu AI
- `extends Node3D` (nu are nevoie de fizică; se mișcă prin interpolare).
- `_build_visuals()`: capsulă cu textură de lavă (albedo+emission mov), doi „ochi" galbeni,
  o lumină mov.
- `_process(delta)`: animație (plutire+rotație); dacă are țintă, se apropie cu `move_toward`,
  altfel cere următorul pas BFS (`_pick_next_step`); apoi `_check_catch`.
- `_check_catch()`: dacă distanța XZ < `catch_dist` și nu e în cooldown → `lose_life`,
  mesaj pe HUD, se retrage la spawn, cooldown 2s (ca să nu-ți ia toate viețile deodată).
- `stop()`: oprește gardianul la final de joc/nivel.

### 4.6. HUD.gd — interfața din joc
- `extends CanvasLayer`, în grupul „hud". Se abonează la semnalele GameManager.
- `_update_lives`: desenează inimi roșii (vieți) + negre (pierdute până la maxim). La > maxim,
  bucla pentru negre nu rulează (range negativ = gol).
- `_on_perk_unlocked`: notificare + activează minimapa/busola.
- Blestem: arată bara, scade la fiecare tic, pulsează roșu sub 5s.
- `show_notification`: tween apariție → 2.5s → dispariție; oprește tween-ul anterior.
- `update_compass`: calculează săgeata (Partea 5.4).
- `setup_minimap`: pe nivelul 2 caseta e cu 30% mai mare.
- `force_show_minimap`: cheat-ul admin (dezvăluie tot).

### 4.7. MinimapUI.gd — minimapa 2D desenată manual
- `extends Control`, desenează în `_draw()` cu `draw_rect`/`draw_line`/`draw_circle`.
- `_revealed` = lista celulelor descoperite; doar ele se văd clar (fog-of-war).
- `setup(maze, target_px)`: calculează `cell_px` adaptiv ca harta să încapă în casetă.
- `update_player`: marchează celula curentă ca descoperită + cere redesenare (`queue_redraw`).
- `_draw()`: pentru fiecare celulă desenează podeaua, marcajul de obiect (dacă e descoperită
  sau ai viziune-tunel), pereții; apoi ieșirea și punctul jucătorului.
- `reveal_all()`: cheat — toate celulele devin descoperite.

### 4.8. ItemPickup.gd — obiectele
- `extends Area3D`. `_process`: plutire + rotație.
- `_is_auto_trigger()`: capcană/blestem = automat la contact; restul = cu E.
- `_on_body_entered`: dacă jucătorul intră — obiect rău → `_collect(false)` direct; obiect bun →
  memorează „nearby" + prompt „[ E ]".
- `interact()` (apelat de Player la E) → `_collect(true)`.
- `_collect(play_blip)`: oprește detecția, (opțional) sunet, `GameManager.collect_item(tip)`,
  apoi tween de micșorare + `queue_free`.
- `_find_hud()`: prin grup.

### 4.9. AudioManager.gd — sunet 100% procedural
- Generează unde sinusoidale într-un buffer (`PackedVector2Array`, stereo) și le redă printr-un
  `AudioStreamGenerator`. Vezi Partea 5.5.
- Funcții publice: `play_collect_perk/life`, `play_trap/life_lost/curse_start`, `play_interact`,
  `play_victory/game_over`. Volumul global vine din bus-ul Master (setări).

### 4.10. PauseMenu.gd — pauza
- `extends CanvasLayer`, `process_mode = ALWAYS` (în scenă) → funcționează cât timp jocul e
  pe pauză (`get_tree().paused = true` îngheață restul).
- ESC comută pauza; butoane: Continuă (recapturează mouse-ul), Restart nivel
  (`restart_level` + `reload_current_scene`), Meniu.

### 4.11. MainMenu / GameOver / Victory
- **MainMenu**: butoane + 3 slidere de setări (salvează în GameManager). Dimmer = preview live
  de luminozitate. Titlul pulsează (tween).
- **GameOver**: Reia (de la nivel 1) / Meniu.
- **Victory**: arată viețile rămase, Joacă din nou / Meniu, titlu care pulsează.

---

## PARTEA 5 — Algoritmi și matematică (partea „grea", învaț-o bine)

### 5.1. Generarea labirintului — DFS „Recursive Backtracking"
Ideea: pornești cu toate celulele complet închise (4 pereți). Mergi în adâncime:
```
_carve_from(celula):
    marchează celula ca vizitată
    amestecă cele 4 direcții (aleator → labirint diferit de fiecare dată)
    pentru fiecare direcție:
        vecin = celula din acea direcție
        dacă vecinul există și NU e vizitat:
            dărâmă peretele dintre celula curentă și vecin (în AMBELE sensuri)
            _carve_from(vecin)   # recursiv
```
Proprietăți: rezultă un **labirint „perfect"** — există exact UN drum între oricare două
celule (fără bucle, fără zone izolate). De aceea ieșirea e mereu accesibilă.
`OPPOSITE = [2,3,0,1]`: dacă dărâm peretele N la mine, dărâm S la vecin (același gol, două fețe).
Întrebare tipică: „de ce shuffle?" → ca labirintul să fie unic la fiecare joc (procedural).

### 5.2. Urmărirea gardianului — BFS (Breadth-First Search)
BFS găsește **cel mai scurt drum** într-un graf neponderat (aici: celulele = noduri, golurile
din pereți = muchii). Algoritm:
```
coadă = [start]; vizitat = {start}; came_from = {}
cât timp coada nu e goală:
    cur = scoate din fața cozii
    dacă cur == țintă: gata
    pentru fiecare vecin accesibil (perete dărâmat) și nevizitat:
        marchează vizitat, came_from[vecin] = cur, adaugă în coadă
# reconstruiește drumul mergând înapoi din țintă prin came_from
# întoarce PRIMUL pas dinspre start
```
De ce BFS și nu DFS aici? BFS garantează drumul minim (gardianul nu se rătăcește). Îl rulăm
de fiecare dată când gardianul ajunge într-o celulă nouă (recalculează spre poziția ta curentă →
te „vânează" inteligent). Complexitate O(celule) — ieftin pe 16×16.

### 5.3. Mișcarea jucătorului — vectori și baze
Un nod 3D are o **bază** (basis): 3 vectori care arată încotro e „dreapta" (`basis.x`),
„sus" (`basis.y`), „înapoi" (`basis.z`). Deci:
- `forward = -basis.z` (înainte = opusul lui „înapoi").
- `right = basis.x`.
Le proiectăm pe orizontală (`y=0`) și normalizăm (lungime 1). Apoi:
`wish = forward*(W−S) + right*(D−A)`, normalizat. Înmulțit cu `move_speed` = viteza dorită.
`move_toward(velocity, target, accel*delta)` apropie viteza curentă de cea dorită cu un pas
limitat → accelerare/decelerare lină (nu pornire/oprire bruscă).
**move_toward vs lerp:** `lerp` se apropie asimptotic (nu ajunge niciodată exact), `move_toward`
se apropie cu pas fix și **ajunge exact** la țintă → mai predictibil pentru mișcare.

### 5.4. Busola — trigonometrie cu atan2
Vrem o săgeată care arată spre ieșire, RELATIV la direcția în care privești.
1. Direcția spre ieșire în plan (x,z): `angle_to_exit = atan2(dz, dx)`.
2. Direcția privirii din yaw: `forward = (-sin(yaw), -cos(yaw))` → `facing = atan2(fz, fx)`.
3. Diferența `rel = (angle_to_exit − facing)` adusă în [0,360).
4. `rel` în [315,360)∪[0,45) → ↑ (în față); [45,135) → → (dreapta); [135,225) → ↓ (spate);
   [225,315) → ← (stânga).
`atan2(y,x)` întoarce unghiul vectorului (x,y) — gestionează corect toate cadranele
(spre deosebire de `atan`).

### 5.5. Sunetul procedural — sinusoide și buffer
Sunetul digital = un șir de eșantioane (amplitudini) redate cu o frecvență (22050/s la noi).
Un ton pur: `amplitudine(t) = sin(2π·f·t)`, unde `t = i/SAMPLE_RATE`. Înmulțim cu un
**envelope** `(1 − i/frames)` ca volumul să scadă spre final (altfel un „poc" la tăiere).
- ton simplu = o frecvență; **acord** = suma mai multor sinusoide; **sweep** = frecvența
  alunecă (lerp de la f_start la f_end) → efect de „cădere".
Scriem eșantioanele într-un `PackedVector2Array` (stereo: L,R), le împingem în
`AudioStreamGeneratorPlayback.push_buffer()`, redăm, apoi curățăm player-ul.

### 5.6. Fizica — gravitație, viteză, coliziuni
- `CharacterBody3D.velocity` (Vector3) = viteza curentă. `move_and_slide()` aplică viteza,
  detectează coliziunile și **alunecă** pe pereți (nu te oprești brusc într-un colț).
- Gravitație: când nu ești pe podea, `velocity.y -= gravity*delta` (accelerare în jos);
  pe podea, `velocity.y = 0` sau impuls de săritură.
- `is_on_floor()` = adevărat dacă ultimul `move_and_slide` a atins o suprafață „podea"
  (unghi sub `floor_max_angle`).
- Coliziunea funcționează doar dacă există `CollisionShape3D` cu o formă. (Bug-ul tău inițial:
  jucătorul nu avea formă → trecea prin pereți ȘI Area-urile nu-l detectau.)

### 5.7. Conversia grid ↔ lume
- Grid → lume: `world = (gx*cell_size, înălțime, gy*cell_size)`.
- Lume → grid: `gx = round(world.x/cell_size)`, `gy = round(world.z/cell_size)`.
Esențial: grila e logica (labirint, pathfinding, minimap), lumea e vizualul 3D.

### 5.8. Texturi, UV, normal maps
- **UV** = coordonate (0..1) care spun cum se „lipește" textura pe mesh. `uv1_scale > 1` =
  textura se repetă (tiling) → folosit la podea ca dalele să fie mici, nu întinse.
- **Normal map** = o textură care nu schimbă culoarea, ci „înclină" lumina pe fiecare pixel →
  iluzie de relief (cărămizi ieșite în afară) fără geometrie în plus. De aceea pereții par 3D.
- **Emission** = material care „emite" lumină proprie (obiectele strălucesc, crăpăturile
  gardianului lucesc).

---

## PARTEA 6 — Motorul de gândire (deciziile de design)

- **Grid logic + mișcare continuă**: labirintul e o grilă (ușor de generat/parcurs algoritmic),
  dar te miști liber și fluid (plăcut). Le legăm prin conversia grid↔lume.
- **Autoload pentru stare**: ca să supraviețuiască schimbării de scenă.
- **Semnale pentru comunicare**: decuplare — fiecare sistem își vede treaba, nu se „caută"
  reciproc.
- **collect_item centralizat**: un singur loc decide ce face fiecare obiect → ușor de extins.
- **E pentru bun, automat pentru rău**: n-are sens să „echipezi" o capcană; o calci.
- **Config pe nivel (LEVEL_CONFIG)**: dificultatea (mărime, întuneric, capcane, viteza
  gardianului) se reglează din date, nu din cod împrăștiat.
- **Procedural peste tot** (labirint, sunet, geometrie, materiale generate): mai puține
  fișiere, conținut variabil, bifează criteriul „conținut generat procedural".
- **Pathfinding BFS**: AI corect și ieftin pentru un graf mic; mereu drum minim.
- **120 Hz fizică**: compromis simplu pentru fluiditate fără interpolare complexă.

---

## PARTEA 7 — Întrebări probabile la prezentare (și cum răspunzi)

1. **Cum generezi labirintul?** DFS recursive backtracking; labirint perfect (un singur drum
   între celule); shuffle → unic de fiecare dată.
2. **Cum te asiguri că ieșirea e accesibilă?** Pentru că labirintul e perfect (conectat integral).
3. **Cum funcționează AI-ul gardianului?** BFS pe grila labirintului spre celula ta curentă,
   recalculat la fiecare celulă → cel mai scurt drum, te urmărește real.
4. **Cum e mișcarea fluidă?** CharacterBody3D + move_and_slide, accelerare cu move_toward,
   fizica la 120 Hz ca să nu fie sacadat.
5. **Cum comunică sistemele?** Prin semnale (Observer) și un singleton GameManager.
6. **De ce nu treceau prin obiecte/interacțiunea nu mergea?** Lipsea CollisionShape3D la
   jucător; Area3D detectează doar corpuri cu formă.
7. **Cum se calculează busola?** atan2 pentru unghiul spre ieșire minus unghiul privirii →
   4 cadrane → săgeată.
8. **Cum faci sunetul fără fișiere?** Generez sinusoide într-un buffer și le redau cu
   AudioStreamGenerator; envelope ca să nu poceasă.
9. **Cum persistă viețile între nivele?** GameManager e autoload; `next_level` păstrează
   viețile, resetează doar perks.
10. **Ce sunt normal maps?** Textură care înclină lumina → relief fără geometrie.
11. **De ce 120 Hz fizică?** Camera e copil al corpului mișcat în fizică; 60 Hz dădea stutter.
12. **Cum funcționează minimapa „fog of war"?** Listă de celule descoperite; `_draw` desenează
    clar doar ce e descoperit.

---

## Anexă — recapitulare rapidă a fișierelor
- `project.godot` — config (autoload, input, fizică, display).
- `scripts/` — 13 scripturi (vezi Partea 4).
- `scenes/` — Game, MainMenu, GameOver, Victory (arborii de noduri + UI).
- `assets/textures/` — texturi CC0 (ambientCG) + CREDITS.txt.
- `.godot/` — cache de import și de clase (auto-generat).
```
Concepte de bifat că le-ai înțeles: Scene Tree, noduri/scene/scripturi, _ready/_process/
_physics_process/_input, semnale, autoload, grupuri, input map, CharacterBody3D + move_and_slide,
Area3D + CollisionShape3D, StaticBody3D, materiale/texturi/normal maps/emission, Tween,
DFS, BFS, vectori/basis, atan2, audio procedural, conversie grid↔lume, fizică (gravitație/
is_on_floor), import de resurse, class_name.
```
