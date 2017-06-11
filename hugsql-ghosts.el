;;; hugsql-ghosts.el --- Display ghostly hugsql defqueries inline

;; Copyright (C) 2017 Roland Kaercher <roland.kaercher@gmail.com>, heavily based on yesql ghosts by Magnar Sveen <magnars@gmail.com>

;; Author: Roland Kaercher <roland.kaercher@gmail.com>
;; URL: https://github.com/rkaercher/hugsql-ghosts
;; Version: 0.1.0
;; Package-Requires: ((s "1.9.0") (dash "2.10.0") (cider "0.14.0"))

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Display ghostly hugsql defqueries inline.

;; The ghostly displays are inserted when cider-mode is entered, and
;; updated every time you save.

;;; Code:

(require 's)
(require 'dash)
(require 'cider)
(require 'nrepl-dict)
(require 'thingatpt)

(defgroup hugsql-ghosts nil
  "Display ghostly hugsql defqueries inline."
  :group 'tools)

(defcustom hugsql-ghosts-show-docstrings 't
  "A non-nil value if you want to show query docstrings."
  :group 'hugsql-ghosts)

(defcustom hugsql-ghosts-newline-before-docstrings nil
  "A non-nil value if you want to print a newline before query docstrings."
  :group 'hugsql-ghosts)

(defcustom hugsql-ghosts-show-ghosts-automatically 't
  "A non-nil value if you want to show the ghosts when a buffer loads.
Otherwise, use `hugsql-ghosts-display-query-ghosts' and
`hugsql-ghosts-remove-overlays' to show and hide them."
  :group 'hugsql-ghosts)

(defface hugsql-ghosts-defn
  '((t :foreground "#686868" :background "#181818"))
  "Face for hugsql ghost defns inserted when in cider-mode."
  :group 'hugsql-ghosts)

(defun hugsql-ghosts-remove-overlays ()
  "Remove all hugsql ghost overlays from the current buffer."
  (interactive)
  (--each (overlays-in (point-min) (point-max))
    (when (eq (overlay-get it 'type) 'hugsql-ghosts)
      (delete-overlay it))))

(defun hugsql-ghosts--fontify-ghost (string)
  (set-text-properties 0 (length string) `(face 'hugsql-ghosts-defn) string)
  string)

(defun hugsql-ghosts--insert-overlay (content)
  (let ((o (make-overlay (point) (point) nil nil t)))
    (overlay-put o 'type 'hugsql-ghosts)
    (overlay-put o 'before-string (hugsql-ghosts--fontify-ghost (concat content "\n")))))

(defun hugsql-ghosts--format-query (query-meta)
  (-let [(name (&plist :doc doc)) query-meta]
    (if (and hugsql-ghosts-show-docstrings doc (not (s-blank? doc)))
	(format "(defn %s [db ...]%s\"%s\")"  name (if hugsql-ghosts-newline-before-docstrings "\n" " ") doc)
      (format "(defn %s [db ...])" name))))

(defun hugsql-ghosts--format-query-fns (query-fns)
  (s-join "\n" (-map 'hugsql-ghosts--format-query query-fns)))

(defconst hugsql-ghosts--clojure-eval-code-template "(map
(fn [[fname {:keys [meta]}]]
    (list (name fname) (mapcat (fn [[kw value]] [kw value]) meta)))
(hugsql.core/%s \"%s\"))")

(defconst hugsql-ghosts--clojure-db-fn-name "map-of-db-fns")
(defconst hugsql-ghosts--clojure-sqlvec-fn-name "map-of-sqlvec-fns")

(defun hugsql-ghosts--find-next-occurrence ()
  (if (search-forward "(hugsql/def-db-fns \"" nil t)
      :hugsql-db-fn
    (when (search-forward "(hugsql/def-sqlvec-fns \"" nil t)
      :hugsql-sqlvec-fn)))

(defun hugsql-ghosts--display-next-queries ()
  (-when-let (def-fns-found (hugsql-ghosts--find-next-occurrence))
    (let* ((path (thing-at-point 'filename))
	   (clojure-fn-name (if (eq :hugsql-db-fn def-fns-found)
				hugsql-ghosts--clojure-db-fn-name
			      hugsql-ghosts--clojure-sqlvec-fn-name))
	   (clojure-cmd (format hugsql-ghosts--clojure-eval-code-template clojure-fn-name path))
	   (cider-result (cider-nrepl-sync-request:eval clojure-cmd))
           (db-fns (read (nrepl-dict-get cider-result "value"))))
      (when db-fns
        (end-of-line)
        (forward-char 1)
	(hugsql-ghosts--insert-overlay (hugsql-ghosts--format-query-fns db-fns))))))

;;;###autoload
(defun hugsql-ghosts-display-query-ghosts ()
  "Displays an overlay after (hugsql/def-db-fns ...) or (hugsql/def-sqlvec-fns ...) showing the names and docstrings of the generated functions from that file."
  (interactive)
  (hugsql-ghosts-remove-overlays)
  (save-excursion
    (goto-char (point-min))
    (while (hugsql-ghosts--display-next-queries))))

(defun hugsql-ghosts-auto-show-ghosts ()
  "Hook function for automatically showing the overlay in cider mode and redisplaying them after each save.  Can be configured by customizing the 'hugsql-ghosts-show-ghosts-automatically' variable."
  (when (and cider-mode hugsql-ghosts-show-ghosts-automatically)
    (hugsql-ghosts-display-query-ghosts)))

;;;###autoload
(add-hook 'cider-mode-hook 'hugsql-ghosts-auto-show-ghosts)
;;;###autoload
(add-hook 'after-save-hook 'hugsql-ghosts-auto-show-ghosts)

(provide 'hugsql-ghosts)
;;; hugsql-ghosts.el ends here
