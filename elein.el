;;; elein.el -- running leiningen commands from emacs

;; Copyright (C) 2010 R.W van 't Veer

;; Author: R.W. van 't Veer
;; Created: 2 Aug 2010
;; Keywords: tools processes

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;; 
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;; 
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;; Provides support for running leiningen commands like swank and test.

;;; Code:

(require 'cl)

(defgroup elein nil
  "running leiningen commands from emacs"
  :prefix "elein-"
  :group 'applications)

(defcustom elein-swank-timeout
  10
  "Number of seconds for swank to come up."
  :type 'number
  :group 'elein)

(defun elein-project-root ()
  "Look for project.clj file to find project root."
  (let ((cwd default-directory)
        (found nil)
        (max 10))
    (while (and (not found) (> max 0))
      (if (file-exists-p (concat cwd "project.clj"))
        (setq found cwd)
        (setq cwd (concat cwd "../") max (- max 1))))
    (and found (expand-file-name found))))

(defmacro elein-in-project-root (body)
  "Wrap BODY to make `default-directory' the project root."
  (let ((dir (gensym)))
    `(let ((,dir (elein-project-root)))
       (if ,dir
         (let ((default-directory ,dir)) ,body)
         (error "No leiningen project root found")))))

(defun elein-swank ()
  "Lauch lein swank and connect slime to it."
  (interactive)
  (elein-in-project-root (shell-command "lein swank&" "*elein-swank*"))
  (with-current-buffer "*elein-swank*"
    (let ((timeout elein-swank-timeout))
      (while (and (> timeout 0)
                  (not (progn (goto-char (point-min))
                              (search-forward-regexp "Connection opened on local port +\\([0-9]+\\)" nil t)))
                  (not (progn (goto-char (point-min))
                              (search-forward "No project.clj found" nil t))))
        (message "Waiting for swank ..%s.." timeout)
        (sleep-for 1)
        (decf timeout))
      (let ((port (match-string 1)))
        (if port
          (progn
            (goto-char (point-min))
            (search-forward-regexp "Connection opened on local port +\\([0-9]+\\)")
            (slime-connect "localhost" (match-string 1)))
          (message "No swank found.."))))))

(defun elein-kill-swank ()
  "Kill swank process started by lein swank."
  (interactive)
  (let ((swank-process (get-buffer-process "*elein-swank*")))
    (when swank-process
      (ignore-errors (slime-quit-lisp))
      (let ((timeout elein-swank-timeout))
        (while (and (> timeout 0) (eql 'run (process-status swank-process)))
          (message "Waiting for swank to die ..%s.." timeout)
          (sleep-for 1)
          (decf timeout))
        (ignore-errors (kill-buffer "*elein-swank*"))))))

(defun elein-reswank ()
  "Kill current lisp, restart lein swank and connect slime to it."
  (interactive)
  (elein-kill-swank)
  (elein-swank))

(defun elein-run-task (task)
  "Run 'lein TASK' using `compile' in the project root directory."
  (interactive "sTask: ")
  (elein-in-project-root (compile (concat "lein " task))))

(defmacro elein-defun-run-task (task)
  "Define shortcut function for `elein-run-task' with argument TASK."
  `(defun ,(intern (concat "elein-" task)) ()
     ,(concat "Run 'lein " task "' in the project root directory.")
     (interactive)
     (elein-run-task ,task)))

;; define interactive elein-TASK commands for common tasks
(dolist (task '(classpath
                clean
                compile
                deps
                help
                install
                jar
                new
                pom
                repl
                test
                uberjar
                upgrade
                version))
  (eval `(elein-defun-run-task ,(symbol-name task))))

(provide 'elein)

;;; elein.el ends here
