# 🜏 Elizabethan Lispies 🜏

### *Cryptography, Kabbalah & Classical Ciphers in Common Lisp*

> *« There are more things in Heaven and Earth, Horatio,*  
> *Than are dreamt of in your philosophy. »*  
> — William Shakespeare


**A Common Lisp laboratory for Gematria, Notarikon, Temurah, Baconian cryptography and classical cryptanalysis.**

[![Language](https://img.shields.io/badge/language-Common%20Lisp-6A5ACD.svg)](#)
[![Paradigm](https://img.shields.io/badge/paradigm-symbolic%20programming-orange.svg)](#)
[![Cryptography](https://img.shields.io/badge/cryptography-classical%20%26%20historical-darkred.svg)](#)
[![Unicode](https://img.shields.io/badge/Unicode-Hebrew-blue.svg)](#)


---

## 🜂 What is *Elizabethan Lispies*?

**Elizabethan Lispies** is an experimental Common Lisp repository situated at the intersection of:

- 🔢 **Gematria**
- 🔤 **Notarikon**
- 🔄 **Temurah**
- 🪞 **Atbash**
- 🔁 **Albam**
- 🥓 **Bacon's cipher**
- 🕵️ **Classical cryptanalysis**
- 🔐 **Caesar and Vigenère ciphers**
- 📊 **Frequency analysis**
- 🫥 **Textual steganography**

The project explores symbolic systems and historical cryptographic techniques through one of the oldest and most expressive families of programming languages:

> **Lisp.**

The repository contains both an **original historical/experimental implementation** and a significantly expanded **KABBALA-CRYPTO v2** toolkit, accompanied by a detailed tutorial.

The objective is not modern production cryptography.

> ⚠️ **This project is intended for historical, educational, symbolic and experimental purposes.**  
> Classical ciphers such as Caesar, Vigenère or Bacon must not be used to protect modern sensitive information.

---

# 🏛️ Repository Architecture

```text
elizabethan-lispies/
│
├── kabbala-crypto-v2.lisp
│   │
│   ├── General utilities
│   ├── Gematria
│   │   ├── Standard Hebrew values
│   │   ├── Extended final-letter values
│   │   └── Digital-root reduction
│   │
│   ├── Notarikon
│   │   ├── First-letter extraction
│   │   ├── Last-letter extraction
│   │   └── Middle-letter extraction
│   │
│   ├── Temurah
│   │   ├── Hebrew Atbash
│   │   ├── Hebrew Albam
│   │   └── Latin Atbash
│   │
│   ├── Bacon Cipher
│   │   ├── Encoding
│   │   ├── Decoding
│   │   ├── Case-based steganography
│   │   └── Hidden-message extraction
│   │
│   └── Classical Cryptanalysis
│       ├── Letter frequencies
│       ├── Frequency-based substitution guesses
│       ├── Substitution decryption
│       ├── Caesar
│       └── Vigenère
│
├── original_sixteen_century,lisp
│   └── Original implementation / historical source
│
└── tutoriel-lisp-kabbala-crypto.md
    └── Detailed tutorial and pedagogical material
```

---

# ✨ Features

## 🔢 1. Gematria

Gematria associates numerical values with letters.

The library implements Hebrew letter values and supports several calculation modes.

### Standard Gematria

```lisp
(gematria "שלום")
```

Example result:

```text
376
```

### Digital Root

The numerical result can be recursively reduced to a single digit.

```lisp
(gematria "שלום" :method :digital-root)
```

Conceptually:

```text
376
 ↓
3 + 7 + 6 = 16
 ↓
1 + 6 = 7
```

Result:

```text
7
```

### Modulo 9

```lisp
(gematria "שלום" :method :mod9)
```

### Final Hebrew Letters

Two conventions are supported.

#### Standard convention

Final letters have the same values as their ordinary forms.

```text
ך = כ
ם = מ
ן = נ
ף = פ
ץ = צ
```

#### Extended final-letter convention

Final forms receive their own values:

```text
ך → 500
ם → 600
ן → 700
ף → 800
ץ → 900
```

Usage:

```lisp
(gematria "..." :finals :extended)
```

---

# 🔤 2. Notarikon

**Notarikon** is a symbolic technique based on extracting letters from words.

For example:

```text
Iesus Nazarenus Rex Iudaeorum
```

Can produce:

```text
INRI
```

### First letters

```lisp
(notarikon "Iesus Nazarenus Rex Iudaeorum")
```

Result:

```text
INRI
```

### Last letters

```lisp
(notarikon "Iesus Nazarenus Rex Iudaeorum"
           :position :last)
```

### Middle letters

```lisp
(notarikon "Iesus Nazarenus Rex Iudaeorum"
           :position :middle)
```

### Verification

```lisp
(notarikon-p "INRI"
             "Iesus Nazarenus Rex Iudaeorum")
```

Result:

```lisp
T
```

---

# 🪞 3. Temurah

**Temurah** transforms text through systematic substitutions.

The project implements several traditional substitution systems.

---

## Hebrew Atbash

Atbash reverses the alphabet.

Conceptually:

```text
1st  ↔ last
2nd  ↔ penultimate
3rd  ↔ third from last
...
```

For Hebrew:

```text
א ↔ ת
ב ↔ ש
ג ↔ ר
```

Usage:

```lisp
(temurah-atbash-hebrew "...")
```

The implementation also normalizes Hebrew final forms before performing substitutions.

For example:

```text
ך → כ
ם → מ
ן → נ
ף → פ
ץ → צ
```

This ensures that final characters can participate correctly in the transformation.

---

## Hebrew Albam

Albam divides the 22-letter Hebrew alphabet into two groups of 11 letters.

Each letter is replaced by its counterpart in the opposite half.

Conceptually:

```text
א ↔ ל
ב ↔ מ
ג ↔ נ
...
```

Usage:

```lisp
(temurah-albam-hebrew "...")
```

---

## Latin Atbash

The project also implements Latin Atbash.

```text
A ↔ Z
B ↔ Y
C ↔ X
D ↔ W
...
```

Usage:

```lisp
(temurah-atbash-latin "HELLO")
```

The implementation preserves character case:

```text
Hello
 ↓
Svool
```

---

# 🥓 4. Bacon's Cipher

The **Bacon cipher** is a historical biliteral cipher associated with Francis Bacon.

Each letter is represented using five symbols:

```text
A / B
```

For example:

```text
A → AAAAA
B → AAAAB
C → AAABA
```

The implementation follows the historical 24-character convention in which:

```text
I / J
```

share a representation, as do:

```text
U / V
```

---

## Encoding

```lisp
(bacon-encode "HELLO")
```

Produces a sequence of groups composed of:

```text
A
B
```

---

## Decoding

```lisp
(bacon-decode "AABBB...")
```

---

# 🫥 5. Baconian Steganography

One of the most interesting parts of the project is the ability to hide Baconian information inside the **capitalization pattern** of an apparently ordinary text.

The principle is simple:

```text
lowercase → A
UPPERCASE → B
```

A carrier text such as:

```text
tHis Is An Apparently Ordinary Text
```

can therefore encode a hidden binary-like A/B sequence.

---

## Hide a message

First encode the secret:

```lisp
(defparameter *secret*
  (bacon-encode "HELLO"))
```

Then inject it into a carrier text:

```lisp
(bacon-hide
 "This is a sufficiently long innocent looking text."
 *secret*)
```

---

## Extract the hidden A/B stream

```lisp
(bacon-extract-case carrier-text)
```

---

## Reveal a known-length message

```lisp
(bacon-reveal extracted-bits 5)
```

This is particularly useful when the carrier contains more alphabetic characters than necessary.

Without a length limit, remaining carrier characters could generate meaningless trailing Bacon groups.

---

# 📊 6. Frequency Analysis

The project includes basic classical cryptanalysis tools.

Text can first be normalized:

```lisp
(normalize-latin-text
 "Hello, World! 123")
```

Result:

```text
HELLOWORLD
```

---

## Letter frequencies

```lisp
(letter-frequencies
 "THIS IS A TEST MESSAGE")
```

Returns an ordered collection of letter/count pairs.

For human-readable output:

```lisp
(print-letter-frequencies
 "THIS IS A TEST MESSAGE")
```

Example:

```text
S : 4
T : 3
E : 3
...
```

This functionality provides a foundation for attacking classical monoalphabetic substitution ciphers.

---

# 🔐 7. Caesar Cipher

The Caesar cipher shifts letters by a fixed number of positions.

```text
A + 3 → D
B + 3 → E
C + 3 → F
```

---

## Encrypt

```lisp
(caesar-encrypt "HELLO" 3)
```

Result:

```text
KHOOR
```

---

## Decrypt

```lisp
(caesar-decrypt "KHOOR" 3)
```

Result:

```text
HELLO
```

---

## Brute force

A Caesar cipher has a small key space.

The library therefore provides a brute-force facility capable of exploring possible shifts.

```lisp
(caesar-bruteforce "KHOOR")
```

This is useful for educational cryptanalysis and for discovering unknown shifts.

---

# 🔑 8. Vigenère Cipher

The Vigenère cipher uses a repeating keyword to generate a sequence of alphabetic shifts.

Encryption:

```lisp
(vigenere-encrypt "ATTACKATDAWN" "KEY")
```

Decryption:

```lisp
(vigenere-decrypt encrypted-text "KEY")
```

The core transformation can also be accessed directly through:

```lisp
(vigenere ...)
```

with explicit encryption/decryption behaviour.

---

# 🕵️ 9. Monoalphabetic Substitution

The toolkit includes helper functions for working with substitution ciphers.

Among them:

```lisp
(frequency-guess-mapping ...)
```

Generates a preliminary substitution hypothesis based on frequency ordering.

The resulting mapping can then be applied:

```lisp
(apply-mapping ciphertext mapping)
```

A higher-level helper is also available:

```lisp
(substitution-decrypt ciphertext mapping)
```

This is not intended to replace modern statistical cryptanalysis, but provides an accessible symbolic approach to one of the foundational problems of classical cryptography.

---

# 📦 Installation

## Requirements

You need a Common Lisp implementation.

Recommended options include:

- **SBCL**
- CLISP
- CCL
- ECL

The project is written in portable Common Lisp and deliberately avoids requiring external dependencies for its core functionality.

---

## Clone the repository

```bash
git clone https://github.com/KareyPyer/elizabethan-lispies.git
cd elizabethan-lispies
```

---

# 🚀 Quick Start

Launch SBCL:

```bash
sbcl
```

Load the toolkit:

```lisp
(load "kabbala-crypto-v2.lisp")
```

Switch to the package:

```lisp
(in-package #:kabbala-crypto)
```

You are now ready to explore.

---

## Example session

### Gematria

```lisp
(gematria "שלום")
```

### Notarikon

```lisp
(notarikon "Iesus Nazarenus Rex Iudaeorum")
```

### Latin Atbash

```lisp
(temurah-atbash-latin "Hello World")
```

### Caesar

```lisp
(caesar-encrypt "HELLO" 3)
```

### Bacon

```lisp
(bacon-encode "HELLO")
```

### Vigenère

```lisp
(vigenere-encrypt "ATTACKATDAWN" "KEY")
```

---

# 🎭 Demonstration Mode

The library includes a demonstration function:

```lisp
(demo)
```

The demonstration executes representative examples from the principal components of the toolkit.

It is an excellent starting point for quickly discovering the API.

---

# 📚 Public API

The package explicitly exports its public interface.

## Utilities

```lisp
chars-from-codes
whitespacep
split-words
```

---

## Gematria

```lisp
hebrew-letter-value
gematria
digital-root

*hebrew-standard*
*hebrew-final-extended*
```

---

## Notarikon

```lisp
first-letter
last-letter
middle-letter

notarikon
notarikon-p
```

---

## Temurah

```lisp
normalize-hebrew-final

temurah-atbash-hebrew
temurah-atbash-hebrew-char

temurah-albam-hebrew
temurah-albam-hebrew-char

latin-letter-p

temurah-atbash-latin
temurah-atbash-latin-char
```

---

## Bacon

```lisp
bacon-encode
bacon-decode
bacon-reveal

bacon-hide
bacon-extract-case
```

---

## Cryptanalysis

```lisp
normalize-latin-text

letter-frequencies
print-letter-frequencies

frequency-guess-mapping
apply-mapping
substitution-decrypt

vigenere
vigenere-encrypt
vigenere-decrypt

caesar-encrypt
caesar-decrypt
caesar-bruteforce
```

---

## Demonstration

```lisp
demo
```

---

# 🧠 Lisp Concepts Explored

Beyond cryptography and symbolic systems, **Elizabethan Lispies** is also a practical exploration of Common Lisp.

The source demonstrates concepts including:

### Packages

```lisp
(defpackage ...)
(in-package ...)
```

### Explicit public APIs

```lisp
(:export ...)
```

### Keyword arguments

```lisp
(defun example (&key option)
  ...)
```

### Variable-length arguments

```lisp
(defun example (&rest arguments)
  ...)
```

### Hash tables

```lisp
(make-hash-table ...)
(gethash ...)
```

### Functional sequence processing

```lisp
(map ...)
(remove-if-not ...)
```

### Iteration

```lisp
(loop ...)
(dolist ...)
```

### String streams

```lisp
(with-output-to-string ...)
```

### Unicode manipulation

```lisp
(code-char ...)
(char-code ...)
```

### Explicit validation

```lisp
(ecase ...)
```

### Documentation

The v2 implementation makes extensive use of function docstrings.

These can be queried interactively:

```lisp
(documentation 'gematria 'function)
```

or:

```lisp
(documentation 'bacon-encode 'function)
```

---

# 🜁 Historical & Symbolic Perspective

The project deliberately brings together traditions that are usually studied separately.

```text
                    SYMBOLIC TEXT
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
      GEMATRIA       NOTARIKON       TEMURAH
          │              │              │
          └──────────────┼──────────────┘
                         │
                         ▼
                  TRANSFORMATION
                         │
                         ▼
                CLASSICAL CIPHERS
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
        BACON          CAESAR        VIGENÈRE
          │              │              │
          └──────────────┼──────────────┘
                         │
                         ▼
                   CRYPTANALYSIS
                         │
                         ▼
                  INTERPRETATION
```

The common thread is **transformation**.

A text may be:

- converted into numbers;
- reduced numerically;
- transformed into initials;
- reflected through an alphabet;
- substituted according to a permutation;
- hidden inside another text;
- encrypted;
- statistically analysed;
- reconstructed.

In that sense, the repository is as much a laboratory for **symbolic transformations** as it is a collection of cipher implementations.

---

# 🏺 The Elizabethan Connection

The title **Elizabethan Lispies** is an invitation to imagine a collision between:

```text
16th-century cryptography
        ×
Hebrew symbolic traditions
        ×
Baconian steganography
        ×
classical cryptanalysis
        ×
20th-century Lisp
        ×
modern Unicode computing
```

If Common Lisp had existed in the libraries, courts and secret correspondence networks of the Renaissance, perhaps some of its programs would have looked like this.

```lisp
(loop
  for symbol across text
  collect (transform symbol))
```

The same abstraction can describe:

- a cipher;
- a substitution;
- a symbolic correspondence;
- a numerical transformation;
- an alphabetic reflection.

The centuries change.

The transformation remains.

---

# 🧪 Educational Uses

This repository can be used as a basis for studying:

- 📜 History of cryptography
- 🔤 Classical substitution ciphers
- 🥓 Baconian steganography
- 🔢 Gematria and symbolic numerology
- 🪞 Alphabetic transformations
- 🕵️ Introductory cryptanalysis
- 🧠 Functional programming
- 🧬 Symbolic computation
- 🪄 Common Lisp metaprogramming extensions
- 🌍 Unicode text processing

Possible exercises include:

1. Implement additional Temurah systems.
2. Add Greek alphabet support.
3. Add automated Caesar scoring using language statistics.
4. Implement Index of Coincidence calculations.
5. Add Kasiski examination for Vigenère analysis.
6. Build a Baconian text encoder that automatically generates carrier text.
7. Add a command-line interface.
8. Create a REPL-based interactive cryptographic workbench.
9. Add ASDF system definitions.
10. Develop a web interface around the symbolic transformations.

---

# 🔮 Possible Future Directions

## ASDF integration

A future version could provide:

```lisp
(defsystem "elizabethan-lispies"
  ...)
```

allowing:

```lisp
(ql:quickload :elizabethan-lispies)
```

---

## Test suite

Possible testing frameworks include:

- FiveAM
- Parachute
- Prove

Example conceptual test:

```lisp
(test gematria-shalom
  (is (= 376 (gematria "שלום"))))
```

---

## Cryptanalysis scoring

Frequency analysis could be extended with:

```text
Chi-square scoring
Index of Coincidence
N-gram scoring
Dictionary scoring
Language detection
```

---

## Interactive REPL

A symbolic workbench could expose commands such as:

```text
ELIZABETHAN> gematria שלום
376

ELIZABETHAN> atbash HELLO
SVOOL

ELIZABETHAN> caesar decrypt KHOOR 3
HELLO

ELIZABETHAN> notarikon "Iesus Nazarenus Rex Iudaeorum"
INRI
```

---

# ⚠️ Security Notice

**Elizabethan Lispies is not a modern cryptographic library.**

The algorithms implemented here are historically and educationally valuable but are generally unsuitable for contemporary security requirements.

Do **not** use:

```text
Caesar
Vigenère
Simple substitution
Bacon cipher
```

to protect:

- passwords;
- private keys;
- authentication tokens;
- financial information;
- personal data;
- confidential communications.

For real-world cryptographic applications, use modern, reviewed cryptographic libraries and algorithms.

---

# 🤝 Contributing

Contributions, experiments and extensions are welcome.

Interesting areas include:

- Additional historical ciphers
- New symbolic alphabets
- Improved cryptanalysis
- Automated tests
- ASDF packaging
- Documentation improvements
- Examples and notebooks
- REPL interfaces
- Visualization of symbolic transformations

A good contribution should ideally preserve the project's spirit:

> **Readable code, explicit transformations, historical curiosity and Lisp elegance.**

---

# 📖 Documentation

The repository includes a dedicated tutorial:

```text
tutoriel-lisp-kabbala-crypto.md
```

It provides additional pedagogical material around the implementation and the Common Lisp concepts used throughout the project.

The source code itself is also heavily documented through comments and docstrings.

---

# 🗺️ Roadmap

- [x] Gematria
- [x] Standard Hebrew values
- [x] Extended final-letter values
- [x] Digital-root calculations
- [x] Notarikon
- [x] Hebrew Atbash
- [x] Hebrew Albam
- [x] Latin Atbash
- [x] Bacon encoding
- [x] Bacon decoding
- [x] Case-based Bacon steganography
- [x] Frequency analysis
- [x] Caesar cipher
- [x] Caesar brute force
- [x] Vigenère cipher
- [x] Monoalphabetic substitution helpers
- [x] Interactive demonstration
- [ ] ASDF packaging
- [ ] Automated test suite
- [ ] Statistical language scoring
- [ ] Kasiski examination
- [ ] Index of Coincidence
- [ ] Interactive CLI
- [ ] Web interface

---


# 🜏 *Finis coronat opus.* 🜏

### *The end crowns the work.*


**Elizabethan Lispies**

*Where ancient alphabets meet symbolic computation.*

```text
Aleph → Number
Letter → Pattern
Pattern → Cipher
Cipher → Transformation
Transformation → Meaning
```


⭐ **If the repository intrigues you, consider giving it a star.**
