;;; sunrise-x-modeline.el --- Navigable mode line for the Sunrise Commander File
;;  Manager.

;; Copyright (C) 2009-2010 José Alfredo Romero Latouche.

;; Author: José Alfredo Romero L. <escherdragon@gmail.com>
;; Keywords: Sunrise Commander Emacs File Manager Path Mode Line

;; This program is free software: you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation,  either  version  3 of the License, or (at your option) any later
;; version.
;;
;; This  program  is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR  A  PARTICULAR  PURPOSE.  See the GNU General Public License for more de-
;; tails.

;; You  should have received a copy of the GNU General Public License along with
;; this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This  extension  modifies  the  format  of  the  mode lines under the Sunrise
;; Commander panes so they display only the paths to the current directories (or
;; the tail if the whole path is longer can be displayed on the mode line) and a
;; small icon  indicating  the  current  mode  (normal,  virtual,  synchronized,
;; editable) of its respective pane.

;; The regular mode line format remains available: press C-c m to toggle between
;; one format and the other.

;; The  extension  is  provided  as a minor mode, so you can enable / disable it
;; totally by issuing the command (M-x) sr-modeline.

;; This is version 2 $Rev$ of the Sunrise Commander Modeline Extension.

;; It  was  written  on GNU Emacs 23 on Linux, and tested on GNU Emacs 22 and 23
;; for Linux and on EmacsW32 (version 22) for  Windows.

;;; Installation and Usage:

;; 1) Put this file somewhere in your emacs load-path.

;; 2)  Add  a  (require  ’sunrise‐x‐modeline)  expression  to  your  .emacs file
;; somewhere after the (require ’sunrise‐commander) one.

;; 3) Evaluate the new expression, or reload your .emacs file, or restart emacs.

;; 4) Enjoy ;-)

;;; Code:

(require 'sunrise-commander)
(require 'easymenu)
(eval-when-compile (require 'cl))

(defcustom sr-modeline-use-utf8-marks nil
  "Set to t to use fancy marks (using UTF-8 glyphs) in the mode line."
  :group 'sunrise
  :type 'boolean)

(defconst sr-modeline-norm-mark '(" * " . " ☼ ")) 
(defconst sr-modeline-sync-mark '(" & " . " ⚓ "))
(defconst sr-modeline-edit-mark '(" ! " . " ⚡ "))
(defconst sr-modeline-virt-mark '(" @ " . " ☯ "))
(defconst sr-modeline-tree-mark '(" T " . " ⚘ "))

;;; ============================================================================
;;; Core functions:

(defvar sr-modeline-mark-map (make-sparse-keymap))
(define-key sr-modeline-mark-map [mode-line mouse-1] 'sr-modeline-popup-menu)
(define-key sr-modeline-mark-map [mode-line mouse-2] 'sr-modeline-popup-menu)

(defvar sr-modeline-path-map (make-sparse-keymap))
(define-key sr-modeline-path-map [mode-line mouse-1] 'sr-modeline-navigate-path)
(define-key sr-modeline-path-map [mode-line mouse-2] 'sr-modeline-navigate-path)

(defun sr-modeline-select-mark (mode)
  "Selects the right mark for the given mode depending on whether UTF-8 has been
  enabled in the mode line."
  (let ((select (if sr-modeline-use-utf8-marks #'cdr #'car)))
    (funcall select
             (cond ((eq mode 'sync) sr-modeline-sync-mark)
                   ((eq mode 'edit) sr-modeline-edit-mark)
                   ((eq mode 'virt) sr-modeline-virt-mark)
                   ((eq mode 'tree) sr-modeline-tree-mark)
                   (t sr-modeline-norm-mark)))))

(defun sr-modeline-setup ()
  "Determines  the mode indicator (icon) to display in the mode line. On success
  sets the mode line format by calling sr-modeline-set."
  (let ((mark nil))
    (cond ((eq major-mode 'sr-mode)
           (setq mark (sr-modeline-select-mark
                       (cond ((not buffer-read-only) 'edit)
                             (sr-synchronized 'sync)
                             (t 'norm)))))
          ((eq major-mode 'sr-virtual-mode)
           (setq mark (sr-modeline-select-mark 'virt)))
          ((eq major-mode 'sr-tree-mode)
           (setq mark (sr-modeline-select-mark 'tree))))
    (if mark (sr-modeline-set mark))))

(defun sr-modeline-set (mark)
  "Sets  the mode line format using the given mode indicator and the path to the
  current directory of the pane. Truncates the path  if  it’s  longer  than  the
  available width of the pane."
  (let ((path default-directory)
        (path-length (length default-directory))
        (max-length (- (window-width) 8)))
    (if (< max-length path-length)
        (setq path (concat "..." (substring path (- path-length max-length)))))
    (eval
     `(setq mode-line-format
            '("%[" ,(sr-modeline-mark mark) "%]" ,(sr-modeline-path path))))))

(defun sr-modeline-mark (mark)
  "Prepares  the  propertized string used in the mode line format to display the
  mode indicator."
  (let ((mode-name ""))
    (setq mode-name
          (cond ((eq mark (sr-modeline-select-mark 'sync)) "Synchronized Navigation")
                ((eq mark (sr-modeline-select-mark 'edit)) "Editable Pane")
                ((eq mark (sr-modeline-select-mark 'virt)) "Virtual Directory")
                ((eq mark (sr-modeline-select-mark 'tree)) "Tree View")
                (t "Normal")))
    (propertize mark
                'font 'bold 
                'mouse-face 'mode-line-highlight
                'help-echo (concat "Sunrise Commander: " mode-name " Mode")
                'local-map sr-modeline-mark-map)))

(defun sr-modeline-path (path)
  "Prepares  the  propertized string used in the mode line format to display the
  path to the current directory in the file system."
  (propertize path
              'local-map sr-modeline-path-map
              'mouse-face 'mode-line-highlight
              'help-echo "Click to navigate directory path"
              'sr-selected-window sr-selected-window))

(defun sr-modeline-navigate-path ()
  "Analyzes  all  click  events  detected  on  the  directory  path and modifies
  accordingly the current directory of the corresponding panel."
  (interactive)
  (let* ((event (caddr (cddadr last-input-event)))
         (path (car event)) (pos (cdr event)) (slash) (levels))
    (or (eq sr-selected-window (get-text-property 0 'sr-selected-window path))
        (sr-change-window))
    (setq slash (string-match "/" path pos)
          levels (- (length (split-string (substring path slash) "/")) 2))
    (if (< 0 levels)
        (sr-dired-prev-subdir levels)
      (sr-beginning-of-buffer))))

;;; ============================================================================
;;; Private interface:

(defvar sr-modeline)

(defun sr-modeline-refresh ()
  (setq sr-modeline t)
  (sr-modeline-setup))

(defun sr-modeline-engage ()
  "Activates and enforces the navigation mode line format."
  (add-hook 'sr-refresh-hook 'sr-modeline-refresh)  
  (sr-modeline-setup)
  (sr-in-other (sr-modeline-setup)))

(defun sr-modeline-disengage ()
  "De-activates the navigation mode line format, enforcing the default one."
  (remove-hook 'sr-refresh-hook 'sr-modeline-refresh)
  (setq mode-line-format (default-value 'mode-line-format))
  (sr-in-other (setq mode-line-format (default-value 'mode-line-format))))

(defun sr-modeline-toggle (&optional force)
  "Toggles the usage and enforcement of the navigation mode line format."
  (interactive)
  (cond ((and force (< 0 force)) (sr-modeline-engage))
        ((and force (> 0 force)) (sr-modeline-disengage))
        (t
         (if (eq mode-line-format (default-value 'mode-line-format))
             (sr-modeline-engage)
           (sr-modeline-disengage)))))

;;; ============================================================================
;;; User interface:

(defvar sr-modeline-map (make-sparse-keymap))
(define-key sr-modeline-map "\C-cm" 'sr-modeline-toggle)

(define-minor-mode sr-modeline
  "Navigable  mode  line  for  the  Sunrise Commander. This is a minor mode that
  provides only one keybind:
  
  C-c m ................ Toggle between navigation and default mode line formats
  
  To totally disable this extension do: M-x sr-modeline <RET>"

  nil (sr-modeline-select-mark 'norm) sr-modeline-map
  (unless (memq major-mode '(sr-mode sr-virtual-mode sr-tree-mode))
    (setq sr-modeline nil)
    (error "Sorry, this mode can be used only within the Sunrise Commander."))
  (sr-modeline-toggle 1))

(defvar sr-modeline-menu
  (easy-menu-create-menu
   "Mode Line"
   '(["Toggle navigation mode line" sr-modeline-toggle t]
     ["Turn off navigation mode line" sr-modeline t]
     ["Navigation mode line help" (lambda ()
                                    (interactive)
                                    (describe-function 'sr-modeline))] )))
(defun sr-modeline-popup-menu ()
  (interactive)
  (popup-menu sr-modeline-menu))

(defun sr-modeline-menu-init ()
  (unless (fboundp 'easy-menu-binding) ;;<-- not available in emacs 22
    (defsubst easy-menu-binding (menu &optional item-name) (ignore)))
  (define-key sr-modeline-map
    (vector 'menu-bar (easy-menu-intern "Sunrise"))
    (easy-menu-binding sr-modeline-menu "Sunrise")))

;;; ============================================================================
;;; Bootstrap:

(defun sr-modeline-start-once ()
  "Bootstraps  the  navigation  mode  line on the first execution of the Sunrise
  Commander, after module installation."
  (sr-modeline t)
  (sr-modeline-menu-init)
  (remove-hook 'sr-start-hook 'sr-modeline-start-once)
  (unintern 'sr-modeline-start-once))
(add-hook 'sr-start-hook 'sr-modeline-start-once)

;;; ============================================================================
;;; Desktop support:

(defun sr-modeline-desktop-restore-buffer (desktop-buffer-file-name
                                           desktop-buffer-name
                                           desktop-buffer-misc)
  "Activates the mode line when restoring sunrise buffers using desktop."
  (run-with-timer 0.1 nil 'sr-modeline-toggle 1))
(add-to-list 'sr-desktop-restore-handlers 'sr-modeline-desktop-restore-buffer)

(provide 'sunrise-x-modeline)
