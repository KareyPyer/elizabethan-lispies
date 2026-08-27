# Tutoriel ultra-détaillé de Common Lisp
## À travers une boîte à outils de cryptographie kabbalistique (`kabbala-crypto`)

---

## 0. Avant de commencer

### 0.1 Verdict sur le fichier original

Le fichier `sixteen.lisp_txt` fourni a été **compilé et exécuté réellement** (sous SBCL 2.2.9, `sbcl --script`), pas seulement relu. Résultat : **zéro warning de compilation, zéro erreur à l'exécution**, et tous les algorithmes vérifiés donnent le résultat mathématiquement attendu :

| Test | Résultat obtenu | Résultat attendu |
|---|---|---|
| Gematria de שלום (Shalom) | 376 | 300+30+6+40 = 376 ✅ |
| Atbash hébreu (Alef) | code U+05EA | Tav (U+05EA) ✅ |
| Albam hébreu (Alef) | code U+05DC | Lamed (U+05DC) ✅ |
| Atbash latin "HELLO" | "SVOOL" | "SVOOL" ✅ |
| Bacon encode/decode "HELLO" | round-trip exact | ✅ |
| Vigenère "ATTACKATDAWN" / clé "LEMON" | round-trip exact | ✅ |
| César déchiffrement décalage 3 | "HELLO" | "HELLO" ✅ |

Le code original était donc **déjà fonctionnellement correct**. Ce tutoriel s'appuie sur une **version 2** qui n'introduit pas des "corrections de bugs cassants" (il n'y en avait pas), mais de vraies **améliorations** :

- Docstrings partout, `defpackage` avec `:export` explicite ;
- **préservation de la casse** en sortie du César, du Vigenère et de la substitution (la v1 renvoyait systématiquement du texte en MAJUSCULES) ;
- ajout de `caesar-encrypt` (seul le déchiffrement existait) et d'alias `vigenere-encrypt` / `vigenere-decrypt` ;
- ajout de `bacon-reveal`, qui corrige un vrai défaut d'usage : la stéganographie de Bacon (`bacon-hide` / `bacon-extract-case`) ne mémorisait pas la longueur du message caché, donc décoder un support plus long que le message produisait un résultat pollué de lettres parasites ;
- validations avec messages d'erreur clairs (clé de substitution trop courte, clé Vigenère vide) ;
- une fonction `demo` qui sert à la fois d'exemple d'utilisation et de test de non-régression.

Tous les extraits de code de ce tutoriel proviennent de cette v2 (`kabbala-crypto-v2.lisp`), livrée à côté de ce document.

### 0.2 Comment exécuter le code

```bash
# Charger le fichier et obtenir un REPL interactif
sbcl --load kabbala-crypto-v2.lisp

# Ou, sans REPL, exécuter un script qui l'utilise :
sbcl --script mon-script.lisp
```

Dans `mon-script.lisp` :

```lisp
(load "kabbala-crypto-v2.lisp")
(in-package :kabbala-crypto)
(demo)   ; lance la démonstration complète
```

`(demo)` affiche un exemple concret pour **chaque** fonctionnalité du fichier : c'est le meilleur point d'entrée pour explorer le code en le faisant tourner sous vos yeux.

### 0.3 Plan du tutoriel

Ce document suit la structure du fichier de code, section par section. Chaque section :
1. rappelle **le concept Lisp** illustré ;
2. montre **le code correspondant** ;
3. explique **ligne par ligne** ce qui se passe ;
4. propose un **petit exercice** pour vérifier votre compréhension.

---

## 1. La structure d'un fichier Lisp : les *packages*

### 1.1 Le concept

En Common Lisp, un **package** est un espace de noms : il évite que deux bibliothèques différentes qui définiraient toutes les deux une fonction nommée, disons, `encode`, ne se marchent dessus. Un package possède :

- un **nom** (ici `kabbala-crypto`) ;
- une liste de packages **utilisés** (`:use`), dont on importe tous les symboles externes — ici `#:cl`, le package standard "Common Lisp" (qui contient `defun`, `loop`, `+`, etc.) ;
- éventuellement une liste de symboles **exportés** (`:export`), c'est-à-dire l'API publique du package, celle que les autres fichiers sont censés utiliser.

### 1.2 Le code

```lisp
(defpackage #:kabbala-crypto
  (:use #:cl)
  (:export
   #:chars-from-codes #:whitespacep #:split-words
   #:hebrew-letter-value #:gematria #:digital-root
   ;; ... etc.
   ))

(in-package #:kabbala-crypto)
```

### 1.3 Explication

- `#:kabbala-crypto` : la syntaxe `#:` crée un **symbole non-interné** (« uninterned symbol »). C'est l'idiome standard pour nommer un package dans un `defpackage` : cela évite de polluer le package courant avec un symbole `KABBALA-CRYPTO` dont on n'a pas vraiment besoin en tant que tel (on veut juste sa *chaîne de caractères* comme nom de package).
- `(:use #:cl)` : tous les symboles externes de `CL` (le package Common Lisp standard) deviennent visibles sans préfixe. C'est pourquoi on peut écrire `defun` au lieu de `cl:defun`.
- `(:export ...)` : chaque symbole listé ici devient accessible depuis l'extérieur via `kabbala-crypto:gematria`, ou directement `gematria` si l'utilisateur fait `(use-package :kabbala-crypto)`. Les fonctions **non exportées** (comme `make-hash-from-pairs`, un simple détail d'implémentation) restent des utilitaires internes : on peut toujours y accéder avec `kabbala-crypto::make-hash-from-pairs` (double `::`), mais ce n'est pas l'usage prévu.
- `(in-package #:kabbala-crypto)` : à partir de cette ligne, **tout le code qui suit** est défini *dans* ce package. C'est l'équivalent Lisp d'un `namespace` C++ ou d'un module Python.

> **Amélioration v2** : le fichier original n'avait pas de clause `:export`. Sans elle, le package fonctionne quand même (tout est accessible avec `::`), mais rien n'indique clairement quelle est l'API "publique" par opposition aux détails internes. Ajouter `:export` est une bonne pratique dès qu'un fichier Lisp est pensé comme une bibliothèque réutilisable.

**Exercice** : ouvrez un REPL, chargez le fichier, puis essayez `(gematria "x")` directement (sans `in-package` ni `kabbala-crypto:`). Que se passe-t-il ? Pourquoi ? *(Réponse : erreur "symbole introuvable", parce que vous êtes dans le package `CL-USER`, qui ne connaît pas `GEMATRIA` tant que vous n'avez pas fait `(in-package :kabbala-crypto)` ou utilisé le préfixe `kabbala-crypto:gematria`.)*

---

## 2. Définir des fonctions : `defun`, mots-clés, docstrings

### 2.1 Le concept

`defun` est la forme de base pour définir une fonction. Sa syntaxe générale :

```lisp
(defun NOM (PARAMETRES...)
  "Docstring optionnelle."
  CORPS...)
```

Common Lisp offre plusieurs façons de déclarer des paramètres :

- **paramètres obligatoires** (positionnels) : `(defun f (a b) ...)` — on doit fournir `a` et `b` dans cet ordre ;
- **`&optional`** : paramètres facultatifs, avec valeur par défaut possible ;
- **`&key`** : paramètres nommés (« keyword arguments »), passés dans n'importe quel ordre à l'appel, sous la forme `:nom valeur` ;
- **`&rest`** : capture tous les arguments restants dans une liste.

### 2.2 Le code — `&rest`

```lisp
(defun chars-from-codes (&rest codes)
  "Construit une CHAINE à partir d'une suite de POINTS DE CODE Unicode."
  (map 'string #'code-char codes))
```

Appelé ainsi : `(chars-from-codes #x05E9 #x05DC #x05D5 #x05DD)`, la variable `codes` devient automatiquement la liste `(#x05E9 #x05DC #x05D5 #x05DD)`. On peut appeler cette fonction avec **0, 1, 2, ou 50** arguments — `&rest` absorbe tout.

### 2.3 Le code — `&key`

```lisp
(defun gematria (text &key (finals :normal) (method :standard))
  ...)
```

Ici, `finals` et `method` sont des paramètres **nommés et facultatifs**, chacun avec une **valeur par défaut** entre parenthèses : `(finals :normal)` signifie « si l'appelant ne précise pas `:finals`, utilise `:normal` ». On peut alors écrire :

```lisp
(gematria "שלום")                          ; méthode standard, finales normales
(gematria "שלום" :method :digital-root)    ; on ne précise QUE ce qu'on veut changer
(gematria "שלום" :finals :extended :method :mod9)  ; ordre libre !
```

C'est l'un des grands conforts de Lisp face à des langages où l'ordre des paramètres est figé : avec `&key`, l'appelant ne fournit que ce qui diffère du défaut, dans l'ordre qu'il veut.

### 2.4 Les docstrings

La chaîne juste après la liste de paramètres (avant le corps de la fonction) est une **docstring** : elle est stockée par le système et récupérable en direct :

```lisp
(documentation 'gematria 'function)
;; => "Calcule la Gematria de TEXT ..."
```

Beaucoup d'éditeurs (Emacs+SLIME, VS Code+Alive...) l'affichent automatiquement quand vous survolez le nom de la fonction. C'est pour cela que la v2 en ajoute systématiquement : **la documentation vit à côté du code, jamais dans un fichier séparé qui se désynchronise**.

**Exercice** : ajoutez un paramètre `&optional (verbose nil)` à une fonction de votre choix, qui affiche un message de debug avec `format` seulement si `verbose` est vrai.

---

## 3. Structures de contrôle

Common Lisp n'a pas un unique "if/else" universel : il a une **famille** de formes de contrôle, chacune adaptée à un usage précis. On en croise cinq dans ce fichier.

### 3.1 `if`, `when`, `unless`

```lisp
(if (zerop n)
    0
    (1+ (mod (1- n) 9)))
```

`if` prend **exactement** une branche "vrai" et une branche "faux" (la branche "faux" est facultative). Quand on n'a **qu'une seule branche** à exécuter, on préfère `when` (exécute si vrai) ou `unless` (exécute si faux), qui sont plus lisibles à l'intention :

```lisp
(when (plusp (length word))
  (write-char ... out))     ; pas de "sinon" à écrire : on ne fait rien

(unless (= (length key) 26)
  (error "La clé doit contenir 26 lettres..."))
```

`when`/`unless` acceptent, contrairement à `if`, **plusieurs formes** dans leur corps, exécutées en séquence (implicite `progn`).

### 3.2 `case` et `ecase`

```lisp
(case position
  (:first (first-letter w))
  (:last (last-letter w))
  (:middle (middle-letter w))
  (otherwise (first-letter w)))
```

`case` compare sa valeur (`position`) à chaque étiquette (`:first`, `:last`...) avec `eql`, et exécute la branche correspondante. `otherwise` (ou `t`) est le cas par défaut.

```lisp
(ecase method
  (:standard sum)
  (:digital-root (digital-root sum))
  (:mod9 ...))
```

`ecase` ("exhaustive case") est identique, **sauf qu'il signale une ERREUR si aucune clause ne correspond**, au lieu de renvoyer silencieusement `NIL`. C'est le bon choix dès qu'on valide une valeur censée appartenir à un ensemble fermé de possibilités (ici, une méthode de calcul) : mieux vaut un crash explicite immédiat qu'un `NIL` qui se propage silencieusement et plante ailleurs, loin de sa cause réelle.

**Essayez** : `(gematria "א" :method :inconnu)` → SBCL vous répondra quelque chose comme *":INCONNU fell through ECASE expression"*. C'est exactement le comportement recherché.

### 3.3 `loop` — le couteau suisse d'itération

`loop` est une mini-DSL (langage dédié) à l'intérieur de Lisp. On en voit plusieurs variantes dans le fichier :

**Itérer sur une chaîne et accumuler une somme :**
```lisp
(loop for ch across (string text)
      sum (hebrew-letter-value ch :finals finals))
```
`for ch across SEQ` itère `ch` sur chaque élément de la séquence `SEQ` (ici une chaîne). `sum EXPR` accumule la somme des `EXPR` successifs et la renvoie à la fin de la boucle — pas besoin de variable accumulateur explicite !

**Itérer sur un intervalle numérique et collecter :**
```lisp
(loop for shift from 0 below 26
      collect (cons shift (caesar-decrypt text shift)))
```
`for shift from 0 below 26` fait varier `shift` de 0 à 25 inclus. `collect EXPR` construit et renvoie la **liste** de tous les `EXPR`.

**Itération avec pas explicite (`by`) et variables liées (`for...=`) :**
```lisp
(loop for start from 0 to (- (length clean) 5) by 5
      for group = (string-upcase (subseq clean start (+ start 5)))
      for pair = (assoc group *bacon-decode* :test #'string=)
      when pair
        do (write-char (cdr pair) out))
```
Ici, chaque itération : (1) avance `start` par pas de 5, (2) calcule `group`, le prochain paquet de 5 lettres, (3) cherche sa traduction `pair`, (4) si trouvée (`when pair`), écrit la lettre décodée. Remarquez que `for group = ...` et `for pair = ...` sont réévalués à *chaque* tour de boucle — ce ne sont pas des constantes.

**Boucle infinie contrôlée par `return` :**
```lisp
(loop
  (loop while (and (< start len) (whitespacep (char s start)))
        do (incf start))
  (when (>= start len)
    (return (nreverse words)))
  ...)
```
Un `loop` sans clause `for`/`while`/`until` boucle **indéfiniment** ; c'est à vous de le stopper avec `(return VALEUR)`, qui sort de la boucle en renvoyant `VALEUR`. Ici on a même une boucle imbriquée dans une boucle : la boucle interne (`while ... do (incf start)`) saute les espaces, la boucle externe traite un mot puis recommence.

### 3.4 `dolist`

```lisp
(dolist (pair pairs h)
  (setf (gethash (code-char (car pair)) h) (cdr pair)))
```

`dolist` est plus simple que `loop` quand on veut juste "faire quelque chose pour chaque élément d'une liste" : `(dolist (VAR LISTE [RESULTAT]) CORPS...)`. Le troisième élément optionnel (`h` ici) est la valeur que renverra `dolist` une fois la liste épuisée — un idiome classique pour "construire puis renvoyer" une structure.

**Exercice** : réécrivez la boucle `(loop for shift from 0 below 26 collect ...)` de `caesar-bruteforce` avec `dolist` et une variable accumulatrice manuelle (`push` puis `nreverse`). Comparez la lisibilité.

---

## 4. Tables de hachage : la Gematria comme dictionnaire

### 4.1 Le concept

Une table de hachage (`hash-table`) associe des **clés** à des **valeurs**, avec un accès en temps quasi-constant — l'équivalent d'un `dict` Python ou d'une `HashMap` Java.

### 4.2 Le code

```lisp
(defun make-hash-from-pairs (pairs)
  (let ((h (make-hash-table :test 'eql)))
    (dolist (pair pairs h)
      (setf (gethash (code-char (car pair)) h) (cdr pair)))))
```

- `(make-hash-table :test 'eql)` crée la table. L'argument `:test` précise **comment comparer les clés** entre elles. `eql` convient parfaitement pour des clés de type **caractère** ou **nombre** (deux caractères identiques sont toujours `eql`). Pour des clés de type **chaîne**, il aurait fallu `:test 'equal` (car deux chaînes de mêmes contenus ne sont *pas* forcément `eql`, seulement `equal`).
- `(gethash clé table)` lit la valeur associée à `clé` (renvoie `nil` si absente — ou une valeur par défaut qu'on peut préciser : `(gethash clé table 0)` renvoie `0` si `clé` est absente, comme on le voit dans `hebrew-letter-value`).
- `(setf (gethash clé table) valeur)` **insère ou remplace** l'association. C'est l'idiome `setf` de Lisp : plutôt que d'avoir une fonction séparée `hash-table-set!`, on rend `gethash` "assignable" (*settable place*) et on utilise la macro générique `setf`. Ce principe (des "endroits" — *places* — génériques qu'on peut lire et écrire avec la même syntaxe d'accès) est l'un des traits les plus élégants de Common Lisp ; on le retrouve avec `(setf (car liste) x)`, `(setf (aref vecteur i) x)`, etc.

### 4.3 Deux tables, deux conventions Kabbalistiques

```lisp
(defparameter *hebrew-standard* (make-hash-from-pairs '((#x05D0 . 1) ...)))
(defparameter *hebrew-final-extended* (make-hash-from-pairs '((#x05DA . 500) ...)))
```

`defparameter` (par opposition à `defvar`) définit une **variable spéciale** (globale, dynamiquement liée) et, point important, **réinitialise toujours sa valeur** si le fichier est rechargé — pratique en développement itératif, quand on modifie une table de constantes et qu'on veut être sûr que la nouvelle version est bien prise en compte. `defvar`, lui, ne touche PAS à la valeur si la variable existe déjà (utile pour un état qu'on ne veut pas écraser accidentellement, comme un cache ou une connexion réseau déjà ouverte).

> **Convention de nommage** : le symbole `*hebrew-standard*` est entouré d'astérisques — c'est la convention Lisp pour signaler "ceci est une variable globale/spéciale", afin de la distinguer d'une variable locale au premier coup d'œil.

**Exercice** : que se passe-t-il si vous changez `:test 'eql` en `:test 'eq` dans `make-hash-from-pairs` ? Réponse : pour des caractères simples (`character`), `eq` et `eql` se comportent en général de façon identique dans les implémentations courantes, mais la norme ne le garantit QUE pour `eql` — utiliser `eq` sur des caractères est donc une pratique non portable à éviter.

---

## 5. Les chaînes de caractères sont des séquences

### 5.1 Le concept-clé

En Common Lisp, une **chaîne de caractères** (`string`) est un cas particulier de **vecteur** (`(vector character)`), qui est lui-même un cas particulier de **séquence**. Cela signifie qu'une grande partie des fonctions génériques de manipulation de séquences (`map`, `subseq`, `position`, `position-if`, `length`, `reverse`...) fonctionnent **indifféremment** sur des chaînes, des listes ou des vecteurs.

### 5.2 `map` — transformer une séquence en une autre

```lisp
(map 'string #'code-char codes)
```

`map` prend : (1) le **type de résultat** souhaité (ici `'string` — pourrait être `'list` ou `'vector`), (2) une fonction, (3) une ou plusieurs séquences d'entrée. Elle applique la fonction à chaque position et assemble le résultat dans le type demandé. C'est l'équivalent Lisp d'un `map()` Python ou d'un `.map()` JavaScript, en plus flexible sur le type de sortie.

On le retrouve partout dans le fichier :
```lisp
(map 'string #'temurah-atbash-hebrew-char (string s))   ; chaîne -> chaîne
(map 'string #'code-char '#(#x05D0 ...))                ; vecteur de codes -> chaîne
```

### 5.3 `subseq`, `position`, `position-if`

```lisp
(let ((end (or (position-if #'whitespacep s :start start) len)))
  (push (subseq s start end) words)
  ...)
```

- `(subseq SEQ DEBUT [FIN])` extrait la **sous-séquence** entre les index `DEBUT` (inclus) et `FIN` (exclu). C'est l'équivalent d'un slice Python `seq[debut:fin]`.
- `(position-if PREDICAT SEQ :start N)` cherche l'index du **premier élément** à partir de l'index `N` qui satisfait `PREDICAT`, ou `NIL` si aucun ne convient.
- `(position ELEMENT SEQ :test FN)` fait la même chose mais cherche un élément *égal* (selon `FN`) à `ELEMENT`, plutôt qu'un élément satisfaisant un prédicat.

L'idiome `(or (position-if ...) len)` est très courant en Lisp : « prends le résultat de cette recherche, ou une valeur par défaut si elle échoue (renvoie `NIL`) ». Comme `NIL` est la seule valeur "fausse" en Lisp, `or` s'arrête au premier argument non-`NIL` — exactement le comportement voulu ici : si aucun espace n'est trouvé après `start`, le mot va jusqu'à la fin de la chaîne (`len`).

### 5.4 Caractères : `char`, `char-code`, `code-char`, `char-upcase`

```lisp
(char-code #\A)          ; => 65  (point de code Unicode/ASCII de 'A')
(code-char 65)           ; => #\A (opération inverse)
(char-upcase #\a)        ; => #\A
(char s i)               ; => le caractère à l'index i de la chaîne s
```

Ce quatuor de fonctions est de loin le plus utilisé du fichier : toute la logique arithmétique des chiffrements (César, Vigenère, substitution) repose sur l'idée de convertir une lettre en un nombre entre 0 et 25 (`(- (char-code (char-upcase ch)) (char-code #\A))`), faire de l'arithmétique modulo 26 dessus, puis reconvertir en caractère (`(code-char (+ (char-code #\A) résultat))`).

**Exercice** : sans regarder le code, écrivez vous-même une fonction `(rot13 texte)` qui applique le chiffrement ROT13 (César avec décalage 13) à `texte`, en utilisant uniquement `char-code`/`code-char`/`char-upcase`/`mod`. Comparez ensuite avec `(caesar-encrypt texte 13)`.

---

## 6. Fermetures (*closures*) et portée lexicale

### 6.1 Le concept

Une **fermeture** est une fonction qui "capture" des variables de son environnement lexical (là où elle a été *définie*, pas là où elle est *appelée*). C'est un concept central de Lisp (le "L" de LISP historique, même si l'acronyme signifie autre chose).

### 6.2 Le code

```lisp
(defun vigenere (text key &key decrypt)
  (let* ((key (normalize-latin-text key))
         (klen (length key)))
    (with-output-to-string (out)
      (let ((i 0))                                  ; <-- I est déclarée ICI
        (loop for ch across (string text)
              for u = (char-upcase ch)
              do (if (latin-letter-p u)
                     (let* (...)
                       (write-char ... out)
                       (incf i))                     ; <-- ... et MODIFIÉE ICI
                     (write-char ch out)))))))
```

La variable `i` est déclarée une seule fois, **avant** la boucle, avec `(let ((i 0)) ...)`. Le corps du `loop` — qui s'exécute une fois par caractère — **partage cette même variable** `i` d'un tour de boucle à l'autre : `(incf i)` modifie l'unique compteur, qui persiste entre les itérations. C'est ce qui permet d'avancer dans la clé (`(mod i klen)`) uniquement quand on traite une VRAIE lettre, en ignorant espaces et ponctuation sans "gâcher" une position de la clé.

Comparez avec `bacon-hide`, qui utilise la même technique :

```lisp
(let ((i 0))
  (map 'string
       (lambda (c)                    ; <-- cette lambda est une FERMETURE :
         (if (and (< i (length bits)) (latin-letter-p c))   ; elle "voit" i et bits
             (let ((bit (char bits i)))
               (incf i)               ; <-- elle modifie le i de l'englobante
               ...)
             c))
       (string carrier)))
```

La `lambda` passée à `map` n'a **aucun paramètre** représentant `i` ou `bits` : elle les lit et les modifie directement depuis son environnement englobant. C'est exactement la définition d'une fermeture : une fonction + les variables de son contexte de création, gardées "en vie" tant que la fonction existe.

**Exercice mental** : que se passerait-il si on déclarait `i` **à l'intérieur** du corps du `loop` (donc réinitialisée à chaque tour) plutôt qu'avant ? *(Réponse : la clé ne progresserait jamais, chaque lettre serait décalée par la même première lettre de la clé — un simple César déguisé, pas un vrai Vigenère.)*

---

## 7. Fonctions comme valeurs : `#'`, `funcall` implicite, `assoc`, `lambda`

### 7.1 Le concept

En Lisp, les fonctions sont des **valeurs de première classe** : on peut les stocker dans des variables, les passer en argument, les renvoyer depuis une autre fonction.

### 7.2 La notation `#'`

```lisp
(map 'string #'code-char codes)
```

`#'nom` (raccourci de `(function nom)`) obtient la **fonction** nommée `nom`, pour la passer comme valeur. C'est différent d'écrire juste `nom` (qui, en position d'argument, désignerait la *variable* `nom`, pas la fonction). Lisp a en effet **deux espaces de noms séparés** pour les fonctions et les variables (ce qu'on appelle un "Lisp-2", par opposition à Scheme qui est un "Lisp-1" où fonctions et variables partagent le même espace de noms) — c'est pourquoi `#'` est nécessaire pour lever l'ambiguïté.

### 7.3 `lambda` — une fonction anonyme

```lisp
(remove-if-not
 (lambda (c) (member c '(#\A #\B #\a #\b) :test #'char=))
 (string bits))
```

`(lambda (PARAMS) CORPS)` crée une fonction **sans lui donner de nom**, utile quand elle ne sert qu'une fois, à un seul endroit — ici, comme critère passé à `remove-if-not` (« garde uniquement les caractères qui sont A, B, a ou b »).

### 7.4 `assoc` — chercher dans une liste de paires (une "petite table de hachage" sans overhead)

```lisp
(defun bacon-encode (text)
  (with-output-to-string (out)
    (loop for ch across (string text)
          for u = (char-upcase ch)
          for pair = (assoc u *bacon-encode*)
          when pair
            do (write-string (cdr pair) out))))
```

`(assoc CLE LISTE-DE-PAIRES)` parcourt une liste de cellules `(clé . valeur)` (des **paires pointées**, ou *conses*) et renvoie la **première paire entière** dont le `car` (premier élément) est `eql` à `CLE` — ou `NIL` si aucune ne correspond. On récupère ensuite la valeur avec `(cdr pair)`.

Pour une table aussi petite (26 lettres), `assoc` sur une liste est parfaitement adapté et même plus simple à lire/écrire littéralement (`'((#\A . "AAAAA") (#\B . "AAAAB") ...)`) qu'une table de hachage — un bon rappel que **la structure de données la plus "avancée" n'est pas toujours la meilleure pour un petit volume de données statiques.**

**Exercice** : réécrivez `*bacon-encode*` sous forme de table de hachage (avec `make-hash-from-pairs`, en adaptant le format d'entrée) et `bacon-encode` pour l'utiliser via `gethash` au lieu d'`assoc`. Sur 26 entrées, mesurez-vous une différence de performance perceptible ? *(Indice : non — l'overhead de hachage dépasse le gain pour d'aussi petites tables.)*

---

## 8. Flux de sortie en mémoire : `with-output-to-string`

### 8.1 Le concept

`with-output-to-string` crée un **flux de caractères connecté à une chaîne en mémoire** : tout ce qu'on y écrit (`write-char`, `write-string`, `format`...) s'accumule, et l'expression entière **renvoie la chaîne finale** une fois le corps terminé.

### 8.2 Le code

```lisp
(defun notarikon (text &key (position :first))
  (with-output-to-string (out)
    (dolist (w (split-words text))
      (when (plusp (length w))
        (write-char (first-letter w) out)))))
```

`out` est le nom qu'on donne à ce flux temporaire (à l'intérieur du corps). C'est l'équivalent Lisp d'un `StringBuilder` Java ou d'un `io.StringIO()` Python — sauf qu'ici, la macro s'occupe **automatiquement** de créer le flux, de le fermer, et de récupérer son contenu en une seule expression, sans variable intermédiaire à gérer manuellement.

**Contre-exemple sans `with-output-to-string`** (pour bien voir ce qu'elle évite) :
```lisp
;; Version "manuelle", plus verbeuse — À NE PAS FAIRE, juste pour comparaison
(defun notarikon-manuel (text)
  (let ((result ""))
    (dolist (w (split-words text))
      (when (plusp (length w))
        (setf result (concatenate 'string result (string (first-letter w))))))
    result))
```
Cette version fonctionne, mais **recopie toute la chaîne à chaque itération** (`concatenate` alloue une nouvelle chaîne à chaque appel) — beaucoup moins efficace que d'écrire dans un flux, qui gère un tampon en interne.

---

## 9. Gestion des erreurs : `error`, `handler-case`

### 9.1 Signaler une erreur

```lisp
(defun substitution-decrypt (cipher-text key)
  (let ((key (string-upcase key)))
    (unless (= (length key) 26)
      (error "La clé doit contenir 26 lettres (longueur reçue : ~D)."
             (length key)))
    ...))
```

`(error CONTROL-STRING ARGS...)` construit un message avec la même syntaxe que `format` (voir section 10) et **interrompt l'exécution** en signalant une condition d'erreur. Par défaut, dans un script, cela arrête le programme avec une trace ; dans un REPL, cela ouvre le **débogueur interactif** de Lisp — l'une des grandes forces de l'écosystème (on peut inspecter l'état, corriger, et *reprendre l'exécution exactement où elle s'est arrêtée*, sans tout relancer).

### 9.2 Capturer une erreur

Le fichier lui-même ne le fait pas (il *déclenche* des erreurs, il ne les *attrape* pas — c'est le rôle du code appelant), mais voici comment un appelant prudent s'y prendrait :

```lisp
(handler-case (substitution-decrypt "HELLO" "TROPCOURT")
  (error (e) (format t "Erreur capturée : ~A~%" e)))
;; => Erreur capturée : La clé doit contenir 26 lettres (longueur reçue : 9).
```

`handler-case` essaie d'évaluer sa première forme ; si une condition du type précisé (`error`, ou un type plus spécifique) est signalée pendant l'évaluation, elle est **interceptée** et la clause correspondante s'exécute à la place, avec la condition liée à la variable `e`. C'est l'équivalent Lisp d'un `try/except` Python ou d'un `try/catch` Java — en plus riche, puisque le système de conditions de Common Lisp permet aussi de *reprendre* l'exécution via des "restarts", ce qu'un simple `try/catch` ne permet pas.

> **Amélioration v2** : le fichier original ne validait déjà que `substitution-decrypt` (longueur de clé) et `vigenere` (clé vide). La v2 conserve ces deux validations et les rend plus explicites dans leur message, sans en ajouter de nouvelles superflues — le principe étant de signaler tôt et clairement toute entrée qui rendrait le résultat mathématiquement incohérent (division/indexation impossible), sans sur-valider des cas qui se dégradent déjà proprement (ex : un texte vide donne juste un résultat vide, pas une erreur).

---

## 10. Le mini-langage `format`

### 10.1 Le concept

`format` est une fonction d'impression pilotée par une **chaîne de contrôle** truffée de directives commençant par `~`. On la croise partout dans `demo` :

```lisp
(format t "Gematria(שלום) standard     = ~A~%" (gematria shalom))
```

### 10.2 Les directives utilisées dans ce fichier

| Directive | Signification | Exemple |
|---|---|---|
| `~A` | Affiche l'argument "tel quel" (*aesthetic* — pas de guillemets sur une chaîne) | `(format t "~A" "abc")` → `abc` |
| `~D` | Affiche un nombre en base 10 | `(format t "~D" 42)` → `42` |
| `~2D` | Affiche un nombre en base 10, cadré sur 2 caractères | `(format t "~2D" 3)` → ` 3` |
| `~%` | Saut de ligne | — |
| `~&` | Saut de ligne *seulement si on n'est pas déjà en début de ligne* (utilisé au tout début de `demo`) | — |

Le premier argument de `format`, ici `t`, signifie « écris directement sur la sortie standard » (par opposition à `nil`, qui demande à `format` de **renvoyer une chaîne** au lieu d'imprimer — exactement le principe qu'utilise `with-output-to-string` en interne).

**Exercice** : remplacez, dans une copie du fichier, tous les `(format t "...")` de `demo` par des appels équivalents utilisant `(format nil "...")` accumulés dans une liste, puis affichés d'un coup à la fin avec un seul `dolist`. Le résultat visuel doit être identique.

---

## 11. Étude de cas, module par module

Cette section relie chaque grande partie du fichier à son fondement mathématique/historique, pour comprendre *pourquoi* le code est écrit ainsi.

### 11.1 Gematria (`gematria`, `hebrew-letter-value`, `digital-root`)

La Gematria assigne une valeur numérique à chaque lettre hébraïque (א=1, ב=2, ..., י=10, כ=20, ..., ק=100, ר=200, ש=300, ת=400), puis somme les valeurs des lettres d'un mot. Deux mots de même Gematria sont dits liés numériquement — c'est la base de nombreuses lectures kabbalistiques traditionnelles (ex : נחש/Nahash, le serpent, et משיח/Mashiach ont tous deux 358 en Gematria standard).

Le code gère deux variantes : la Gematria "standard" (lettres finales = même valeur que leur forme normale) et la Gematria "sofit étendue" (lettres finales = valeurs propres 500-900), toutes deux implémentées comme de simples **tables de correspondance**, ce qui rend le calcul lui-même trivial (`hebrew-letter-value` + une somme).

### 11.2 Notarikon (`notarikon`, `notarikon-p`)

Le Notarikon construit un acronyme à partir des initiales (ou d'autres lettres choisies) de chaque mot d'une phrase — exactement le principe de l'acronyme **INRI** (*Iesus Nazarenus Rex Iudaeorum*) ou **PARDES** (*Peshat, Remez, Drash, Sod* — les 4 niveaux d'interprétation kabbalistiques). C'est essentiellement un problème de **découpage de chaîne** (`split-words`) suivi d'une **projection** (garder 1 caractère par mot).

### 11.3 Temurah / Atbash / Albam

La Temurah remplace systématiquement chaque lettre de l'alphabet par une autre, selon une règle de correspondance fixe :
- **Atbash** inverse l'alphabet (miroir) ;
- **Albam** coupe l'alphabet de 22 lettres hébraïques en deux moitiés de 11 et échange chaque lettre avec son homologue.

Ces deux méthodes se réduisent, algorithmiquement, à un **décalage circulaire dans un tableau ordonné** (`*hebrew-base*`) : trouver la position d'une lettre (`position`), calculer sa position "miroir" ou "décalée", et relire la lettre à cette nouvelle position (`aref`). C'est *exactement* la même famille d'algorithmes que le chiffre de César (un décalage circulaire dans l'alphabet latin) — le fichier le montre bien en réutilisant la même logique pour `temurah-atbash-latin-char`.

### 11.4 Le chiffre de Bacon

Historiquement inventé par **Francis Bacon** au début du XVIIe siècle, ce chiffre encode chaque lettre en un groupe de 5 symboles binaires (A/B, ou 0/1). Sa particularité : on peut le **cacher** dans n'importe quel texte anodin en utilisant deux variantes typographiques indiscernables au premier regard (dans l'original de Bacon : deux polices de caractères légèrement différentes ; ici, plus simplement, majuscule/minuscule). C'est un des tout premiers exemples documentés de **stéganographie** (dissimuler l'existence même d'un message, par opposition à la cryptographie qui dissimule seulement son contenu).

### 11.5 Cryptanalyse classique

La dernière section illustre comment on **attaque** un chiffrement par substitution monoalphabétique (chiffre de César compris) : en comptant la fréquence de chaque lettre dans le texte chiffré et en la comparant à la fréquence connue des lettres dans la langue supposée du texte clair (`*english-frequency-order*`). C'est une méthode **heuristique** : elle donne un point de départ souvent imparfait (voir le résultat de `demo`, qui n'est pas un déchiffrement parfait), qu'un cryptanalyste affine ensuite à la main en cherchant des mots probables ("THE", "AND"...) dans le résultat partiel.

---

## 12. Ce que ce code NE fait volontairement PAS (pistes d'extension)

Pour aller plus loin, voici des directions naturelles laissées de côté par le fichier (bon terrain d'exercices) :

1. **Une classe CLOS pour les chiffrements** (`defclass cipher`, méthodes génériques `encrypt`/`decrypt` spécialisées par sous-classe `caesar-cipher`, `vigenere-cipher`...) — pour découvrir le système d'objets de Common Lisp (CLOS), très différent des classes C++/Java (méthodes définies *hors* de la classe, répartition multiple sur plusieurs arguments).
2. **Un score de vraisemblance linguistique** (indice de coïncidence, analyse de n-grammes) pour automatiser le cassage de César/substitution *sans* intervention humaine — actuellement, `caesar-bruteforce` laisse l'humain choisir le bon décalage à l'œil.
3. **Un vrai chiffrement de Vigenère "autoclave"** (la clé s'étend avec le texte clair lui-même) plutôt que la clé répétée classique.
4. **Support Unicode plus large pour Bacon-stéganographie** : au lieu de la casse (fragile — un correcteur orthographique la détruit), encoder les bits dans des espaces insécables vs espaces normaux, ou des variantes homoglyphes.
5. **Tests unitaires formels** avec une bibliothèque comme `fiveam` ou `parachute`, plutôt que la fonction `demo` "à l'œil" fournie ici.

---

## 13. Récapitulatif : v1 → v2

| Aspect | v1 (fichier original) | v2 (ce tutoriel) |
|---|---|---|
| Correction fonctionnelle | ✅ déjà correcte (vérifié par exécution) | ✅ inchangée |
| Docstrings | absentes | sur toutes les fonctions |
| `defpackage` | pas de `:export` | `:export` complet |
| Casse en sortie (César/Vigenère/substitution) | toujours MAJUSCULE | casse d'origine préservée |
| `caesar-encrypt` | absente (seul `-decrypt` existait) | ajoutée |
| `vigenere-encrypt` / `-decrypt` | absentes (seul `:decrypt` mot-clé) | ajoutées comme alias lisibles |
| Bacon + longueur de message caché | `bacon-decode` décode aussi le "bruit" au-delà du message | `bacon-reveal` borne le décodage à la longueur exacte |
| `notarikon` | dupliquait la logique de `first-letter`/`last-letter` | réutilise ces fonctions (DRY) |
| Exemples exécutables | aucun | fonction `demo` complète |

---

*Fin du tutoriel. Pour toute exploration plus poussée, lancez `(demo)` dans un REPL et modifiez un paramètre à la fois pour observer l'effet sur le résultat — c'est la meilleure façon d'apprivoiser un nouveau langage.*
