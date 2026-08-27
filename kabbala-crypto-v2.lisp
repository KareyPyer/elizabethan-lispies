;;;; ===========================================================================
;;;; KABBALA-CRYPTO — v2
;;;; ===========================================================================
;;;;
;;;; Boîte à outils Common Lisp pour :
;;;;   1. La Gematria (valeur numérique des lettres hébraïques)
;;;;   2. Le Notarikon (acrostiches / initiales de mots)
;;;;   3. La Temurah (substitutions de lettres : Atbash, Albam)
;;;;   4. Le chiffre de Bacon (stéganographie bi-littérale)
;;;;   5. La cryptanalyse classique (fréquences, substitution, Vigenère, César)
;;;;
;;;; Ce fichier est la version 2 du fichier fourni ("sixteen.lisp"). Après
;;;; relecture ET vérification empirique (compilation + exécution sous SBCL,
;;;; zéro warning, résultats vérifiés à la main : Gematria de שלום = 376,
;;;; Atbash(Alef)=Tav, Albam(Alef)=Lamed, Bacon HELLO round-trip, Vigenère
;;;; round-trip, César 3 -> HELLO, etc.), le code original s'est révélé
;;;; FONCTIONNELLEMENT CORRECT : aucune erreur de logique n'a été trouvée.
;;;;
;;;; Les changements apportés ici sont donc des AMÉLIORATIONS et des AJOUTS
;;;; (pas des corrections de bugs cassants) :
;;;;
;;;;   - Docstrings sur toutes les fonctions (pédagogie + `(documentation ...)`)
;;;;   - `defpackage` complété avec une clause `:export` (API publique explicite)
;;;;   - Préservation de la casse dans César / Vigenère / substitution
;;;;     (le code original mettait tout en MAJUSCULES en sortie)
;;;;   - Ajout de `caesar-encrypt` (seul `caesar-decrypt` existait)
;;;;   - Ajout de `vigenere-encrypt` / `vigenere-decrypt` (alias explicites
;;;;     de `vigenere` + mot-clé `:decrypt`, plus lisibles à l'usage)
;;;;   - `bacon-decode` / `bacon-reveal` : gestion propre des messages cachés
;;;;     de longueur connue (le stegano d'origine ne savait pas où s'arrêter)
;;;;   - `notarikon` réécrit pour réutiliser `first-letter` / `last-letter`
;;;;     (au lieu de dupliquer leur logique — principe DRY)
;;;;   - Validation d'arguments (erreurs explicites plutôt que résultats
;;;;     silencieusement faux)
;;;;   - Une fonction `demo` qui exécute et affiche un exemple par fonctionnalité
;;;;
;;;; ===========================================================================

(defpackage #:kabbala-crypto
  (:use #:cl)
  (:export
   ;; Utilitaires généraux
   #:chars-from-codes #:whitespacep #:split-words
   ;; Gematria
   #:hebrew-letter-value #:gematria #:digital-root
   #:*hebrew-standard* #:*hebrew-final-extended*
   ;; Notarikon
   #:first-letter #:last-letter #:middle-letter
   #:notarikon #:notarikon-p
   ;; Temurah (Atbash / Albam)
   #:normalize-hebrew-final
   #:temurah-atbash-hebrew #:temurah-atbash-hebrew-char
   #:temurah-albam-hebrew #:temurah-albam-hebrew-char
   #:latin-letter-p
   #:temurah-atbash-latin #:temurah-atbash-latin-char
   ;; Bacon
   #:bacon-encode #:bacon-decode #:bacon-reveal
   #:bacon-hide #:bacon-extract-case
   ;; Cryptanalyse / substitution / Vigenère / César
   #:normalize-latin-text #:letter-frequencies #:print-letter-frequencies
   #:frequency-guess-mapping #:apply-mapping
   #:substitution-decrypt
   #:vigenere #:vigenere-encrypt #:vigenere-decrypt
   #:caesar-encrypt #:caesar-decrypt #:caesar-bruteforce
   ;; Démo
   #:demo))

(in-package #:kabbala-crypto)

;;; ===========================================================================
;;; 1. UTILITAIRES GÉNÉRAUX
;;; ===========================================================================

(defun chars-from-codes (&rest codes)
  "Construit une CHAINE à partir d'une suite de POINTS DE CODE Unicode.
Exemple : (chars-from-codes #x05D0 #x05D1) -> \"אב\"

Concept Lisp : &rest capture un nombre variable d'arguments dans une LISTE
(ici nommée CODES). `map' applique ensuite CODE-CHAR à chaque élément et
assemble le résultat dans le type de séquence demandé, ici 'string."
  (map 'string #'code-char codes))

(defun whitespacep (c)
  "Vrai si le caractère C est un espace, une tabulation ou un saut de ligne.
Convention Lisp : un prédicat (fonction qui renvoie vrai/faux) se nomme
traditionnellement avec le suffixe \"-P\" (ou \"P\" tout court)."
  (member c '(#\space #\tab #\newline #\return) :test #'char=))

(defun split-words (s)
  "Découpe la chaîne S en une liste de « mots » séparés par des espaces.
Ne s'appuie sur aucune bibliothèque externe (pas de split-sequence) afin
de rester en Common Lisp standard pur : c'est un bon exercice classique
de manipulation d'index dans une chaîne avec `loop'."
  (let ((words '())
        (start 0)
        (len (length s)))
    (loop
      ;; Ignore les espaces qui précèdent le prochain mot.
      (loop while (and (< start len) (whitespacep (char s start)))
            do (incf start))
      (when (>= start len)
        (return (nreverse words)))
      (let ((end (or (position-if #'whitespacep s :start start) len)))
        (push (subseq s start end) words)
        (setf start end)))))

;;; ===========================================================================
;;; 2. GEMATRIA — valeur numérique des lettres hébraïques
;;; ===========================================================================
;;;
;;; Chaque lettre hébraïque possède une valeur numérique traditionnelle.
;;; On distingue :
;;;   - la Gematria "standard" (מספר הכרחי) : les 5 lettres finales (sofit)
;;;     ont la MÊME valeur que leur forme non-finale ;
;;;   - la Gematria "sofit étendue" : les 5 lettres finales prennent des
;;;     valeurs à part : 500, 600, 700, 800, 900.

(defun make-hash-from-pairs (pairs)
  "Construit une table de hachage (clé = caractère, valeur = nombre) à partir
d'une liste de paires (POINT-DE-CODE . VALEUR).

Concept Lisp : `dolist' itère sur une liste ; la clause finale
`(dolist (pair pairs h) ...)' indique que H (la table déjà remplie) est
la valeur de retour de la boucle, une fois celle-ci terminée."
  (let ((h (make-hash-table :test 'eql)))
    (dolist (pair pairs h)
      (setf (gethash (code-char (car pair)) h) (cdr pair)))))

(defparameter *hebrew-standard*
  (make-hash-from-pairs
   '((#x05D0 . 1)   (#x05D1 . 2)   (#x05D2 . 3)   (#x05D3 . 4)
     (#x05D4 . 5)   (#x05D5 . 6)   (#x05D6 . 7)   (#x05D7 . 8)
     (#x05D8 . 9)   (#x05D9 . 10)
     (#x05DA . 20)  (#x05DB . 20)                  ; ך kaf-sofit / כ kaf
     (#x05DC . 30)
     (#x05DD . 40)  (#x05DE . 40)                  ; ם mem-sofit / מ mem
     (#x05DF . 50)  (#x05E0 . 50)                  ; ן nun-sofit / נ nun
     (#x05E1 . 60)  (#x05E2 . 70)
     (#x05E3 . 80)  (#x05E4 . 80)                  ; ף pe-sofit / פ pe
     (#x05E5 . 90)  (#x05E6 . 90)                  ; ץ tsadi-sofit / צ tsadi
     (#x05E7 . 100) (#x05E8 . 200)
     (#x05E9 . 300) (#x05EA . 400)))
  "Table Gematria standard : les lettres finales valent autant que leur
forme normale (convention la plus courante).")

(defparameter *hebrew-final-extended*
  (make-hash-from-pairs
   '((#x05DA . 500)   ; ך kaf-sofit
     (#x05DD . 600)   ; ם mem-sofit
     (#x05DF . 700)   ; ן nun-sofit
     (#x05E3 . 800)   ; ף pe-sofit
     (#x05E5 . 900))) ; ץ tsadi-sofit
  "Table Gematria \"sofit étendue\" : valeurs spécifiques des 5 lettres
finales (variante utilisée par certaines écoles kabbalistiques).")

(defun hebrew-letter-value (ch &key (finals :normal))
  "Renvoie la valeur Gematria du caractère CH, ou 0 s'il n'est pas une
lettre hébraïque reconnue.
:FINALS :NORMAL   -> utilise toujours *hebrew-standard*
:FINALS :EXTENDED -> utilise *hebrew-final-extended* en priorité pour les
                     lettres finales, puis retombe sur *hebrew-standard*"
  (when (characterp ch)
    (if (eql finals :extended)
        (or (gethash ch *hebrew-final-extended*)
            (gethash ch *hebrew-standard* 0))
        (gethash ch *hebrew-standard* 0))))

(defun digital-root (n)
  "Racine numérique de N (réduction théosophique) : on additionne les
chiffres de N récursivement jusqu'à obtenir un nombre entre 0 et 9.
Formule fermée classique : 1 + ((N - 1) mod 9), avec le cas particulier
N = 0 qui renvoie 0.
Exemple : (digital-root 376) -> 3+7+6=16 -> 1+6=7 -> renvoie bien 7."
  (if (zerop n)
      0
      (1+ (mod (1- n) 9))))

(defun gematria (text &key (finals :normal) (method :standard))
  "Calcule la Gematria de TEXT (chaîne, ou tout ce que `string' accepte).
:METHOD :STANDARD     -> la somme brute des valeurs des lettres
:METHOD :DIGITAL-ROOT -> réduction théosophique de la somme (0-9)
:METHOD :MOD9         -> somme modulo 9, avec 0 remplacé par 9

Concept Lisp : `ecase' est comme `case' mais SIGNALE UNE ERREUR si aucune
clause ne correspond (contrairement à `case', qui renverrait NIL en
silence). C'est le bon réflexe pour valider un mot-clé utilisateur."
  (let ((sum (loop for ch across (string text)
                    sum (hebrew-letter-value ch :finals finals))))
    (ecase method
      (:standard sum)
      (:digital-root (digital-root sum))
      (:mod9 (let ((m (mod sum 9)))
               (if (zerop m) 9 m))))))

;;; ===========================================================================
;;; 3. NOTARIKON — technique des initiales / acrostiches
;;; ===========================================================================

(defun first-letter (word)
  "Première lettre de WORD, ou #\\space si WORD est vide."
  (if (plusp (length word)) (char word 0) #\space))

(defun last-letter (word)
  "Dernière lettre de WORD, ou #\\space si WORD est vide."
  (let ((n (length word)))
    (if (plusp n) (char word (1- n)) #\space)))

(defun middle-letter (word)
  "Lettre du milieu de WORD (arrondi vers le bas si longueur impaire),
ou #\\space si WORD est vide."
  (if (plusp (length word))
      (char word (floor (length word) 2))
      #\space))

(defun notarikon (text &key (position :first))
  "Applique le Notarikon à TEXT : construit un « mot » à partir d'une
lettre choisie dans chaque mot de TEXT (par défaut, la première lettre
de chaque mot — comme un acronyme).
:POSITION :FIRST  -> première lettre de chaque mot (par défaut)
:POSITION :LAST   -> dernière lettre de chaque mot
:POSITION :MIDDLE -> lettre du milieu de chaque mot

Amélioration v2 : réutilise FIRST-LETTER / LAST-LETTER / MIDDLE-LETTER
au lieu de dupliquer leur logique (principe DRY : Don't Repeat Yourself).

Concept Lisp : `with-output-to-string' crée un flux de sortie relié à une
chaîne en mémoire ; tout ce qu'on y écrit avec `write-char' finit dans
la chaîne renvoyée."
  (with-output-to-string (out)
    (dolist (w (split-words text))
      (when (plusp (length w))
        (write-char
         (case position
           (:first (first-letter w))
           (:last (last-letter w))
           (:middle (middle-letter w))
           (otherwise (first-letter w)))
         out)))))

(defun notarikon-p (target phrase &key (position :first))
  "Vrai si appliquer le Notarikon à PHRASE (selon :POSITION) donne
exactement la chaîne TARGET. Utile pour vérifier des acrostiches
(ex : \"INRI\" <- \"Iesus Nazarenus Rex Iudaeorum\")."
  (string= (string target)
           (notarikon phrase :position position)))

;;; ===========================================================================
;;; 4. TEMURAH — substitutions de lettres (Atbash, Albam)
;;; ===========================================================================
;;;
;;; La Temurah remplace chaque lettre par une autre selon une règle fixe.
;;; Les deux méthodes classiques :
;;;   - Atbash : on inverse l'alphabet (1ère <-> dernière, 2e <-> avant-
;;;     dernière, etc.) — Aleph <-> Tav, Bet <-> Shin...
;;;   - Albam  : on coupe l'alphabet de 22 lettres en deux moitiés de 11
;;;     et on échange chaque lettre avec son homologue de l'autre moitié
;;;     — Aleph <-> Lamed, Bet <-> Mem...

(defparameter *hebrew-base*
  (map 'vector #'code-char
       #(#x05D0 #x05D1 #x05D2 #x05D3 #x05D4 #x05D5
         #x05D6 #x05D7 #x05D8 #x05D9 #x05DB #x05DC
         #x05DE #x05E0 #x05E1 #x05E2 #x05E4 #x05E6
         #x05E7 #x05E8 #x05E9 #x05EA))
  "Les 22 lettres hébraïques (formes NON finales), dans l'ordre alphabétique
traditionnel. Sert de référentiel de position pour Atbash et Albam.

Note v2 : un vecteur littéral #(...) s'auto-évalue déjà en Lisp ; le quote
`'#(...)' de la version originale était donc inoffensif mais redondant.
Ici on utilise `(map 'vector #'code-char #(...))', ce qui revient au
même sans quote inutile."
  )

(defun normalize-hebrew-final (ch)
  "Convertit une lettre finale (sofit) vers sa forme normale ; renvoie CH
inchangé si ce n'est pas une lettre finale.
Nécessaire car *HEBREW-BASE* ne contient que les formes non finales :
sans cette normalisation, Atbash/Albam échoueraient silencieusement sur
la dernière lettre d'un mot hébreu (qui est presque toujours écrite sous
sa forme finale)."
  (case (char-code ch)
    (#x05DA (code-char #x05DB))   ; ך -> כ
    (#x05DD (code-char #x05DE))   ; ם -> מ
    (#x05DF (code-char #x05E0))   ; ן -> נ
    (#x05E3 (code-char #x05E4))   ; ף -> פ
    (#x05E5 (code-char #x05E6))   ; ץ -> צ
    (otherwise ch)))

(defun temurah-atbash-hebrew-char (ch)
  "Applique Atbash à un seul caractère hébreu CH. Renvoie CH inchangé si
ce n'est pas une lettre de l'alphabet hébreu."
  (let* ((ch (normalize-hebrew-final ch))
         (pos (position ch *hebrew-base* :test #'char=)))
    (if pos
        (aref *hebrew-base* (- (length *hebrew-base*) 1 pos))
        ch)))

(defun temurah-atbash-hebrew (s)
  "Applique Atbash à chaque caractère de la chaîne S."
  (map 'string #'temurah-atbash-hebrew-char (string s)))

(defun temurah-albam-hebrew-char (ch)
  "Applique Albam à un seul caractère hébreu CH (décalage de 11 positions,
soit la moitié de l'alphabet de 22 lettres). Renvoie CH inchangé si ce
n'est pas une lettre de l'alphabet hébreu."
  (let* ((ch (normalize-hebrew-final ch))
         (pos (position ch *hebrew-base* :test #'char=)))
    (if pos
        (aref *hebrew-base* (mod (+ pos 11) (length *hebrew-base*)))
        ch)))

(defun temurah-albam-hebrew (s)
  "Applique Albam à chaque caractère de la chaîne S."
  (map 'string #'temurah-albam-hebrew-char (string s)))

(defun latin-letter-p (ch)
  "Vrai si CH est une lettre latine A-Z, majuscule ou minuscule."
  (let ((c (char-code (char-upcase ch))))
    (and (>= c (char-code #\A))
         (<= c (char-code #\Z)))))

(defun temurah-atbash-latin-char (ch)
  "Applique Atbash à un caractère latin CH (A<->Z, B<->Y, ...), en
préservant la casse d'origine. Renvoie CH inchangé si ce n'est pas une
lettre latine."
  (if (latin-letter-p ch)
      (let* ((u (char-upcase ch))
             (offset (- (char-code u) (char-code #\A)))
             (new (code-char (+ (char-code #\A) (- 25 offset)))))
        (if (lower-case-p ch)
            (char-downcase new)
            new))
      ch))

(defun temurah-atbash-latin (s)
  "Applique Atbash (alphabet latin) à chaque caractère de la chaîne S."
  (map 'string #'temurah-atbash-latin-char (string s)))

;;; ===========================================================================
;;; 5. CHIFFRE DE BACON — stéganographie bi-littérale (24 lettres, I/J et U/V
;;;    partagent un même code, comme dans le système historique de Francis
;;;    Bacon)
;;; ===========================================================================

(defparameter *bacon-encode*
  '((#\A . "AAAAA") (#\B . "AAAAB") (#\C . "AAABA")
    (#\D . "AAABB") (#\E . "AABAA") (#\F . "AABAB")
    (#\G . "AABBA") (#\H . "AABBB")
    (#\I . "ABAAA") (#\J . "ABAAA")   ; I/J partagent le même code (historique)
    (#\K . "ABAAB") (#\L . "ABABA") (#\M . "ABABB")
    (#\N . "ABBAA") (#\O . "ABBAB") (#\P . "ABBBA")
    (#\Q . "ABBBB") (#\R . "BAAAA") (#\S . "BAAAB")
    (#\T . "BAABA") (#\U . "BAABB") (#\V . "BAABB")   ; U/V idem
    (#\W . "BABAA") (#\X . "BABAB") (#\Y . "BABBA")
    (#\Z . "BABBB"))
  "Table d'encodage du chiffre de Bacon (24 symboles A/B, groupes de 5).")

(defparameter *bacon-decode*
  '(("AAAAA" . #\A) ("AAAAB" . #\B) ("AAABA" . #\C)
    ("AAABB" . #\D) ("AABAA" . #\E) ("AABAB" . #\F)
    ("AABBA" . #\G) ("AABBB" . #\H) ("ABAAA" . #\I)
    ("ABAAB" . #\K) ("ABABA" . #\L) ("ABABB" . #\M)
    ("ABBAA" . #\N) ("ABBAB" . #\O) ("ABBBA" . #\P)
    ("ABBBB" . #\Q) ("BAAAA" . #\R) ("BAAAB" . #\S)
    ("BAABA" . #\T) ("BAABB" . #\U) ("BABAA" . #\W)
    ("BABAB" . #\X) ("BABBA" . #\Y) ("BABBB" . #\Z))
  "Table de décodage inverse (24 entrées : I/J et U/V ne peuvent avoir
qu'UNE seule lettre de décodage puisqu'ils partagent le même code A/B ;
par convention on décode vers I et vers U).")

(defun bacon-encode (text)
  "Encode TEXT en chiffre de Bacon : chaque lettre latine devient un
groupe de 5 lettres A/B. Les caractères non latins sont ignorés."
  (with-output-to-string (out)
    (loop for ch across (string text)
          for u = (char-upcase ch)
          for pair = (assoc u *bacon-encode*)
          when pair
            do (write-string (cdr pair) out))))

(defun bacon-decode (bits)
  "Décode une suite BITS (caractères A/B, tout le reste étant ignoré) en
texte clair, par groupes de 5 symboles.
Attention : si le nombre de symboles A/B n'est pas un multiple de 5, ou
si BITS contient des symboles de « remplissage » au-delà du message réel
(cas typique après extraction depuis un support de stéganographie plus
long que le message caché), le reste sera quand même décodé — voir
BACON-REVEAL ci-dessous pour un décodage borné à une longueur connue."
  (let ((clean (remove-if-not
                (lambda (c) (member c '(#\A #\B #\a #\b) :test #'char=))
                (string bits))))
    (with-output-to-string (out)
      (loop for start from 0 to (- (length clean) 5) by 5
            for group = (string-upcase (subseq clean start (+ start 5)))
            for pair = (assoc group *bacon-decode* :test #'string=)
            when pair
              do (write-char (cdr pair) out)))))

(defun bacon-reveal (bits n-chars)
  "Comme BACON-DECODE, mais s'arrête après avoir décodé exactement
N-CHARS lettres (donc N-CHARS * 5 symboles A/B utiles).

Ajout v2 : le stéganographe original (BACON-HIDE / BACON-EXTRACT-CASE)
ne mémorisait pas la longueur du message caché ; si le support (carrier)
est plus long que nécessaire, BACON-DECODE décode aussi les lettres de
« remplissage » restées en bas de casse -> résultat pollué. BACON-REVEAL
corrige cet usage en tronquant explicitement le flux de bits à la bonne
longueur avant décodage."
  (let ((clean (remove-if-not
                (lambda (c) (member c '(#\A #\B #\a #\b) :test #'char=))
                (string bits))))
    (bacon-decode (subseq clean 0 (min (length clean) (* 5 n-chars))))))

(defun bacon-hide (carrier bits)
  "Cache la suite BITS (symboles A/B) dans la CASSE des lettres latines
de CARRIER : un bit \"B\" -> MAJUSCULE, un bit \"A\" -> minuscule.
Les caractères non latins de CARRIER sont recopiés tels quels et ne
consomment aucun bit. Si CARRIER contient moins de lettres latines que
BITS n'a de symboles, les bits en trop sont simplement ignorés (le
texte porteur doit être assez long).
Voir aussi BACON-EXTRACT-CASE et BACON-REVEAL pour l'opération inverse."
  (let ((bits (remove-if-not
               (lambda (c) (member c '(#\A #\B #\a #\b) :test #'char=))
               (string bits)))
        (i 0))
    (map 'string
         (lambda (c)
           (if (and (< i (length bits)) (latin-letter-p c))
               (let ((bit (char bits i)))
                 (incf i)
                 (if (or (char= bit #\B) (char= bit #\b))
                     (char-upcase c)
                     (char-downcase c)))
               c))
         (string carrier))))

(defun bacon-extract-case (text)
  "Extrait de TEXT la suite de symboles A/B encodée dans la casse de ses
lettres latines (MAJUSCULE -> B, minuscule -> A). Opération inverse de
BACON-HIDE. Combinez avec BACON-REVEAL (pas BACON-DECODE) si TEXT peut
contenir plus de lettres que le message caché n'en occupe réellement."
  (with-output-to-string (out)
    (loop for c across (string text)
          when (latin-letter-p c)
            do (write-char (if (upper-case-p c) #\B #\A) out))))

;;; ===========================================================================
;;; 6. CRYPTANALYSE CLASSIQUE — fréquences, substitution, Vigenère, César
;;; ===========================================================================

(defun normalize-latin-text (s)
  "Renvoie S en MAJUSCULES, débarrassé de tout caractère qui n'est pas
une lettre latine (espaces, ponctuation, chiffres...)."
  (string-upcase (remove-if-not #'latin-letter-p (string s))))

(defun letter-frequencies (s)
  "Calcule l'histogramme des lettres A-Z dans S (casse ignorée), et
renvoie une liste de paires (LETTRE . NOMBRE-D'OCCURRENCES) triée par
fréquence décroissante.

Concept Lisp : `stable-sort' trie en place mais préserve l'ordre relatif
des éléments à égalité (ici : égalité de fréquence) — utile pour avoir
un résultat déterministe et reproductible."
  (let ((counts (make-array 26 :initial-element 0)))
    (loop for ch across (normalize-latin-text s)
          do (incf (aref counts (- (char-code ch) (char-code #\A)))))
    (let ((result '()))
      (loop for i from 0 below 26
            do (push (cons (code-char (+ i (char-code #\A)))
                           (aref counts i))
                     result))
      (stable-sort result #'> :key #'cdr))))

(defun print-letter-frequencies (s)
  "Affiche l'histogramme de fréquences des lettres de S, une ligne par
lettre, triées par fréquence décroissante."
  (dolist (p (letter-frequencies s))
    (format t "~A : ~D~%" (car p) (cdr p))))

(defparameter *english-frequency-order*
  "ETAOINSHRDLCUMWFGYPBVKJXQZ"
  "Ordre de fréquence usuel des lettres en anglais (du plus fréquent au
moins fréquent) — sert de base à une cryptanalyse fréquentielle naïve
d'un chiffrement par substitution monoalphabétique.")

(defun frequency-guess-mapping (cipher-text &optional (expected *english-frequency-order*))
  "Propose un appariement (LETTRE-DU-CHIFFRÉ . LETTRE-CLAIRE-SUPPOSÉE) en
associant les lettres du texte chiffré, triées par fréquence décroissante,
aux lettres de EXPECTED dans le même ordre. C'est une heuristique de
DÉPART pour casser un chiffrement par substitution — elle ne fonctionne
bien que sur des textes assez longs et dans la langue attendue ; elle
demande presque toujours des ajustements manuels ensuite."
  (let* ((freqs (letter-frequencies cipher-text))
         (nonzero (remove-if (lambda (p) (zerop (cdr p))) freqs)))
    (loop for pair in nonzero
          for e across expected
          collect (cons (car pair) e))))

(defun apply-mapping (mapping text)
  "Applique un appariement MAPPING (liste de paires (LETTRE . LETTRE)) à
TEXT : chaque lettre latine de TEXT est remplacée par son image dans
MAPPING (ou laissée telle quelle si absente de MAPPING) ; la casse
d'origine est préservée. Les caractères non latins sont recopiés tels quels."
  (map 'string
       (lambda (ch)
         (let ((u (char-upcase ch)))
           (if (latin-letter-p u)
               (let ((mapped (or (cdr (assoc u mapping)) u)))
                 (if (lower-case-p ch) (char-downcase mapped) mapped))
               ch)))
       (string text)))

(defun substitution-decrypt (cipher-text key)
  "Déchiffre CIPHER-TEXT à l'aide d'une KEY de 26 lettres : la N-ième
lettre de KEY (0-indexée) donne la lettre claire correspondant à la
N-ième lettre de l'alphabet dans le texte chiffré (donc KEY[0] est ce
que devient 'A', KEY[1] ce que devient 'B', etc.). La casse d'origine
est préservée ; les caractères non latins sont recopiés tels quels.
Signale une erreur si KEY ne fait pas exactement 26 lettres."
  (let ((key (string-upcase key)))
    (unless (= (length key) 26)
      (error "La clé doit contenir 26 lettres (longueur reçue : ~D)."
             (length key)))
    (map 'string
         (lambda (ch)
           (let ((u (char-upcase ch)))
             (if (latin-letter-p u)
                 (let ((mapped (char key (- (char-code u) (char-code #\A)))))
                   (if (lower-case-p ch) (char-downcase mapped) mapped))
                 ch)))
         (string cipher-text))))

(defun vigenere (text key &key decrypt)
  "Chiffre (ou déchiffre si :DECRYPT est vrai) TEXT avec le chiffre de
Vigenère et la clé KEY (les caractères non latins de KEY sont ignorés).
La casse d'origine de TEXT est préservée ; les caractères non latins de
TEXT sont recopiés tels quels et ne consomment PAS de position dans la
clé (comportement standard : seules les lettres font avancer la clé).
Signale une erreur si KEY ne contient aucune lettre latine.

Concept Lisp : la fonction interne (lambda) et la variable I forment ici
une FERMETURE (closure) : I est déclarée à l'extérieur de la boucle et
mutée par `incf' à chaque lettre traitée, tout en restant visible dans
tout le corps du `loop'."
  (let* ((key (normalize-latin-text key))
         (klen (length key)))
    (when (zerop klen)
      (error "Clé vide ou sans lettre latine."))
    (with-output-to-string (out)
      (let ((i 0))
        (loop for ch across (string text)
              for u = (char-upcase ch)
              do (if (latin-letter-p u)
                     (let* ((shift (- (char-code (char key (mod i klen)))
                                      (char-code #\A)))
                            (base (char-code #\A))
                            (pos (- (char-code u) base))
                            (new (mod (if decrypt (- pos shift) (+ pos shift))
                                      26))
                            (mapped (code-char (+ base new))))
                       (write-char (if (lower-case-p ch)
                                       (char-downcase mapped)
                                       mapped)
                                   out)
                       (incf i))
                     (write-char ch out)))))))

(defun vigenere-encrypt (text key)
  "Chiffre TEXT avec la clé KEY (chiffre de Vigenère). Alias explicite de
(vigenere TEXT KEY), pour un code appelant plus lisible."
  (vigenere text key))

(defun vigenere-decrypt (text key)
  "Déchiffre TEXT avec la clé KEY (chiffre de Vigenère). Alias explicite
de (vigenere TEXT KEY :decrypt t)."
  (vigenere text key :decrypt t))

(defun caesar-decrypt (text shift)
  "Déchiffre TEXT en décalant chaque lettre de -SHIFT positions dans
l'alphabet (chiffre de César). La casse d'origine est préservée ; les
caractères non latins sont recopiés tels quels."
  (map 'string
       (lambda (ch)
         (if (latin-letter-p ch)
             (let* ((base (char-code #\A))
                    (pos (- (char-code (char-upcase ch)) base))
                    (new (mod (- pos shift) 26))
                    (mapped (code-char (+ base new))))
               (if (lower-case-p ch) (char-downcase mapped) mapped))
             ch))
       (string text)))

(defun caesar-encrypt (text shift)
  "Chiffre TEXT en décalant chaque lettre de +SHIFT positions dans
l'alphabet (chiffre de César).

Ajout v2 : le fichier original ne fournissait que CAESAR-DECRYPT (on
pouvait chiffrer en appelant (caesar-decrypt text (- shift)), mais ce
n'était pas une API évidente). CAESAR-ENCRYPT complète l'API en
s'appuyant simplement sur CAESAR-DECRYPT avec le décalage opposé,
puisque chiffrer avec +SHIFT équivaut à déchiffrer avec -SHIFT."
  (caesar-decrypt text (- shift)))

(defun caesar-bruteforce (text)
  "Renvoie les 26 déchiffrements possibles de TEXT par le chiffre de
César, sous forme de paires (DÉCALAGE . TEXTE-DÉCHIFFRÉ) — pratique pour
repérer à l'œil le bon décalage sur un texte court."
  (loop for shift from 0 below 26
        collect (cons shift (caesar-decrypt text shift))))

;;; ===========================================================================
;;; 7. DÉMONSTRATION
;;; ===========================================================================

(defun demo ()
  "Exécute et affiche un exemple pour chaque fonctionnalité du fichier.
Sert de test de non-régression manuel ET d'aide-mémoire d'utilisation."
  (format t "~&=== GEMATRIA ===~%")
  (let ((shalom (chars-from-codes #x05E9 #x05DC #x05D5 #x05DD))) ; שלום
    (format t "Gematria(שלום) standard     = ~A~%" (gematria shalom))
    (format t "Gematria(שלום) digital-root = ~A~%" (gematria shalom :method :digital-root))
    (format t "Gematria(שלום) mod9         = ~A~%" (gematria shalom :method :mod9)))

  (format t "~%=== NOTARIKON ===~%")
  (format t "INRI <- 'Iesus Nazarenus Rex Iudaeorum' : ~A~%"
          (notarikon-p "INRI" "Iesus Nazarenus Rex Iudaeorum"))

  (format t "~%=== TEMURAH (Atbash / Albam, hébreu et latin) ===~%")
  (let ((alef (chars-from-codes #x05D0)))
    (format t "Atbash hébreu (Alef)     -> code ~A (Tav = ~A)~%"
            (char-code (char (temurah-atbash-hebrew alef) 0)) #x05EA)
    (format t "Albam  hébreu (Alef)     -> code ~A (Lamed = ~A)~%"
            (char-code (char (temurah-albam-hebrew alef) 0)) #x05DC))
  (format t "Atbash latin \"Hello, World!\" -> ~A~%" (temurah-atbash-latin "Hello, World!"))

  (format t "~%=== BACON ===~%")
  (let* ((msg "SOS")
         (bits (bacon-encode msg))
         (carrier "The quick brown fox jumps over the lazy dog near the river bank today")
         (hidden (bacon-hide carrier bits)))
    (format t "Message a cacher : ~A~%" msg)
    (format t "Bits Bacon        : ~A~%" bits)
    (format t "Texte porteur     : ~A~%" hidden)
    (format t "Bits extraits     : ~A~%" (bacon-extract-case hidden))
    (format t "Message revele    : ~A~%" (bacon-reveal (bacon-extract-case hidden) (length msg))))

  (format t "~%=== CESAR ===~%")
  (let* ((clair "HELLO WORLD")
         (chiffre (caesar-encrypt clair 3)))
    (format t "Clair    : ~A~%Chiffre  : ~A~%Dechiffre: ~A~%"
            clair chiffre (caesar-decrypt chiffre 3)))

  (format t "~%=== VIGENERE ===~%")
  (let* ((clair "ATTACKATDAWN")
         (chiffre (vigenere-encrypt clair "LEMON")))
    (format t "Clair    : ~A~%Chiffre  : ~A~%Dechiffre: ~A~%"
            clair chiffre (vigenere-decrypt chiffre "LEMON")))

  (format t "~%=== SUBSTITUTION + FREQUENCES ===~%")
  (let* ((clair "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG")
         (chiffre (caesar-encrypt clair 7))
         (guess (frequency-guess-mapping chiffre)))
    (format t "Chiffre (Cesar 7) : ~A~%" chiffre)
    (format t "Frequences du chiffre :~%")
    (print-letter-frequencies chiffre)
    (format t "Proposition frequentielle (grossiere) : ~A~%" (apply-mapping guess chiffre)))

  (values))
