;;; Generating multiple waves from a single event

;; Copyright (C) 2004 Brailcom, o.p.s.

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


(require 'events)
(require 'tokenize)
(require 'util)


(defvar multi-waiting-waves nil)
(defvar multi-waiting-text nil)

(define (multi-add-wave wave)
  (set! multi-waiting-waves (append multi-waiting-waves (list wave))))

(define (multi-event-synth type value)
  (event-synth-1 type value multi-add-wave))

(define (multi-synth-current-text)
  (let ((new-text (second (next-chunk multi-waiting-text))))
    (multi-event-synth 'text (substring multi-waiting-text
                                        0
                                        (- (length multi-waiting-text)
                                           (length new-text))))
    (set! multi-waiting-text new-text)))

;; External functions

(define (multi-clear)
  (set! multi-waiting-waves '())
  (set! multi-waiting-text ""))

(define (multi-synth type value)
  (multi-clear)
  (if (eq? type 'text)
      (set! multi-waiting-text value)
      (multi-event-synth type value)))

(define (multi-next)
  (cond
   (multi-waiting-waves
    (let ((wave (car multi-waiting-waves)))
      (set! multi-waiting-waves (cdr multi-waiting-waves))
      wave))
   ((not (equal? multi-waiting-text ""))
    (multi-synth-current-text)
    (multi-next))
   (t
    nil)))


(provide 'multiwave)
