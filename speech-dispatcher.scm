;;; Speech Dispatcher interface

;; Copyright (C) 2003, 2004 Brailcom, o.p.s.

;; Author: Milan Zamazal <pdm@brailcom.org>

;; COPYRIGHT NOTICE

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA.


(require 'util)
(require 'events)
(require 'spell-mode)
(require 'punctuation)
(require 'cap-signalization)
(require 'multiwave)


(defvar speechd-languages
  '(("en" english)
    ("de" german)
    ("cs" czech))
  "Alist mapping ISO language codes to Festival language names.
Each element of the alist is of the form (LANGUAGE-CODE LANGUAGE-NAME), where
both the elements are strings.
See also `speechd-language-voices'.")

(defvar speechd-language-voices
  '((english
     (male1 voice_kal_diphone)
     (male2 voice_ked_diphone))
    (americanenglish
     (male1 voice_kal_diphone)
     (male2 voice_ked_diphone))
    (britishenglish
     (male1 voice_kal_diphone)
     (male2 voice_ked_diphone))
    (german
     (male1 voice_german))
    (czech
     (male1 voice_czech_mbrola_cz2)))
  "Alist mapping Festival language names and voice names to voice functions.
Each element of the alist is of the form (LANGUAGE VOICE-LIST), where elements
of VOICE-LIST are of the form (VOICE-NAME VOICE-FUNCTION CODING).  VOICE-NAME
is a voice name symbol, VOICE-FUNCTION is the name of the function setting the
given voice, and CODING is the text encoding required by the voice
definition.  CODING may be one of the symbols ISO-8859-<N>, where <N> is a
number within the range 1-16.")


(defvar speechd-base-pitch nil)

(define (speechd-set-lang-voice lang voice)
  (let ((spec (assoc_string
               voice
               (cdr (assoc_string lang speechd-language-voices)))))
    (if spec
        (begin
          (apply (second spec) nil)
          (set! speechd-base-pitch nil)
          (or (cadr (assoc 'coding (cadr (voice.description current-voice))))
              'ISO-8859-1))
        (error "Undefined voice"))))

(define (speechd-send-to-client wave)
  (let ((file-type (Param.get 'Wavefiletype)))
    (Param.set 'Wavefiletype 'nist)
    (unwind-protect* (utt.send.wave.client wave)
      (Param.set 'Wavefiletype file-type))))

(define (speechd-maybe-send-to-client wave)
  (unless speechd-multi-mode
    (speechd-send-to-client wave)))

(define (speechd-event-synth type value)
  ((if speechd-multi-mode multi-synth event-synth) type value))

;;; Commands

(defvar speechd-multi-mode nil)
  
(define (speechd-enable-multi-mode mode)
  "(speechd-set-punctuation-mode MODE)
Enable (if MODE is non-nil) or disable (if MODE is nil) sending multiple
synthesized wave forms."
  (set! speechd-multi-mode mode))

(define (speechd-next*)
  (set_backtrace t)
  (let ((wave (multi-next)))
    (when wave
      (wave-utt wave))))
(define (speechd-next)
  "(speechd-next)
Return next synthesized wave form."
  (let ((utt (speechd-next*)))
    (when utt
      (speechd-send-to-client utt))))

(define (speechd-speak* text)
  (speechd-event-synth 'text text))
(define (speechd-speak text)
  "(speechd-speak TEXT)
Speak TEXT."
  (speechd-maybe-send-to-client (speechd-speak* text)))

(define (speechd-spell* text)
  (spell_init_func)
  (unwind-protect
      (prog1 (speechd-event-synth 'text text)
        (spell_exit_func))
    (spell_exit_func)))
(define (speechd-spell text)
  "(speechd-spell TEXT)
Spell TEXT."
  (speechd-maybe-send-to-client (speechd-spell* text)))

(define (speechd-sound-icon* name)
  (speechd-event-synth 'logical name))
(define (speechd-sound-icon name)
  "(speechd-sound-icon NAME)
Play the sound or text bound to the sound icon named by the symbol NAME."
  (speechd-maybe-send-to-client (speechd-sound-icon* name)))

(define (speechd-character* character)
  (speechd-event-synth 'character character))
(define (speechd-character character)
  "(speechd-character CHARACTER)
Speak CHARACTER, represented by a string."
  (speechd-maybe-send-to-client (speechd-character* character)))

(define (speechd-key* key)
  (speechd-event-synth 'key key))
(define (speechd-key key)
  "(speechd-key KEY)
Speak KEY, represented by a string."
  (speechd-maybe-send-to-client (speechd-key* key)))

(define (speechd-set-language language)
  "(speechd-set-language language)
Set current language to LANGUAGE, where LANGUAGE is the language ISO code,
given as a two-letter string."
  (let ((lang (cadr (assoc_string language speechd-languages))))
    (if lang
        (speechd-set-lang-voice lang "male1")
        (error "Undefined language"))))

(define (speechd-set-punctuation-mode mode)
  "(speechd-set-punctuation-mode MODE)
Set punctuation mode to MODE, which is one of the symbols `all' (read all
punctuation characters), `none' (don't read any punctuation characters) or
`some' (default reading of punctuation characters)."
  (if (eq? mode 'some)
      (set! mode 'default))
  (set-punctuation-mode mode))

(define (speechd-set-voice voice)
  "(speechd-set-voice VOICE)
Set voice which must be one of the strings present in `speechd-language-voices'
alist for the current language."
  (speechd-set-lang-voice (Param.get 'Language) voice))

(define (speechd-set-rate rate)
  "(speechd-set-rate RATE)
Set speech RATE, which must be a number in the range -100..100."
  ;; Stretch the rate to the interval 0.5..2 in such a way, that:
  ;; f(-100) = 0.5 ; f(0) = 1 ; f(100) = 2
  (Param.set 'Duration_Stretch (pow 2 (/ (- 0 rate) 100.0))))

(defvar speechd-set-pitch-vars '((int_lr_params target_f0_mean)
                                 (int_simple_params f0_mean)
                                 (int_general_params f0_mean)))

(define (speechd-set-pitch pitch)
  "(speechd-set-pitch PITCH)
Set speech PITCH, which must be a number in the range -100..100."
  ;; Stretch the rate to the interval 0.5*P..2*P, where P is the default pitch
  ;; of the voice, in such a way, that:
  ;; f(-100) = 0.5*P ; f(0) = P ; f(100) = 2*P
  (if (not speechd-base-pitch)
      (let ((vars speechd-set-pitch-vars))
        (while vars
          (let ((var (caar vars))
                (id (car (cdar vars))))
            (if (boundp var)
                (set! speechd-base-pitch
                      (cons (cons var (cadr (assoc id (symbol-value var))))
                            speechd-base-pitch))))
          (set! vars (cdr vars)))))
  (let ((mean-coef (pow 2 (/ pitch 100.0)))
        (vars speechd-set-pitch-vars))
    (while vars
      (let ((var (caar vars))
            (id (car (cdar vars))))
        (if (boundp var)
            (set-symbol-value!
             var
             (assoc-set (symbol-value var) id
                        (list (* mean-coef
                                 (cdr (assoc var speechd-base-pitch))))))))
      (set! vars (cdr vars)))))
  
(define (speechd-set-capital-character-recognition-mode mode)
  "(speechd-set-capital-character-recognition-mode MODE)
Enable (if MODE is non-nil) or disable (if MODE is nil) capital character
recognition mode."
  (set-cap-signalization-mode mode))

(define (speechd-list-voices)
  "(speechd-list-voices)
Return the list of the voice names (represented by strings) available for the
current language."
  (mapcar car (cdr (assoc_string (Param.get 'Language)
                                 speechd-language-voices))))
