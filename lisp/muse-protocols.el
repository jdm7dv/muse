;;; muse-protocols.el --- URL protocols that Muse recognizes.

;; Copyright (C) 2005  Free Software Foundation, Inc.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Here's an example for adding a protocol for the site yubnub, a Web
;; Command line service.
;;
;; (add-to-list 'muse-url-protocols '("yubnub://" muse-browse-url-yubnub
;;                                                muse-resolve-url-yubnub))
;;
;; (defun muse-resolve-url-yubnub (url)
;;   "Resolve a yubnub URL."
;;   ;; Remove the yubnub://
;;   (when (string-match "\\`yubnub://\\(.+\\)" url)
;;     (match-string 1)))
;;
;; (defun muse-browse-url-yubnub (url)
;;   "If this is a yubnub URL-command, jump to it."
;;   (setq url (muse-resolve-url-yubnub url))
;;   (browse-url (concat "http://yubnub.org/parser/parse?command="
;;                       url)))

;;; Contributors:

;; Brad Collins (brad AT chenla DOT org) created the initial version
;; of this.

;;; Code:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Muse URL Protocols
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'info)
(require 'muse-regexps)

(defvar muse-url-regexp nil
  "A regexp used to match URLs within a Muse page.
This is autogenerated from `muse-url-protocols'.")

(defun muse-update-url-regexp (sym value)
  (setq muse-url-regexp
        (concat "\\<\\(" (mapconcat 'car value "\\|") "\\)"
                "[^][" muse-regexp-space "\"'()<>^`{}]*"
                "[^][" muse-regexp-space "\"'()<>^`{}.,;]+"))
  (set sym value))

(defcustom muse-url-protocols
  '(("info://" muse-browse-url-info nil)
    ("man://" muse-browse-url-man nil)
    ("google://" muse-browse-url-google muse-resolve-url-google)
    ("http:/?/?" browse-url identity)
    ("https:/?/?" browse-url identity)
    ("ftp:/?/?" browse-url identity)
    ("gopher://" browse-url identity)
    ("telnet://" browse-url identity)
    ("wais://" browse-url identity)
    ("file://?" browse-url identity)
    ("news:" browse-url identity)
    ("snews:" browse-url identity)
    ("mailto:" browse-url identity))
  "A list of (PROTOCOL BROWSE-FUN RESOLVE-FUN) used to match URL protocols.
PROTOCOL describes the first part of the URL, including the
\"://\" part.  This may be a regexp.

BROWSE-FUN should accept URL as an argument and open the URL in
the current window.

RESOLVE-FUN should accept URL as an argument and return the final
URL, or nil if no URL should be included."
  :type '(repeat (list :tag "Protocol"
                       (string :tag "Regexp")
                       (function :tag "Browse")
                       (function :tag "Resolve")))
  :set 'muse-update-url-regexp
  :group 'muse)

(defun muse-protocol-find (proto list)
  "Return the first element of LIST whose car matches the regexp PROTO."
  (setq list (copy-alist list))
  (let (entry)
    (while list
      (when (string-match (caar list) proto)
        (setq entry (car list)
              list nil))
      (setq list (cdr list)))
    entry))

(defun muse-browse-url (url &optional other-window)
  "Handle URL with the function specified in `muse-url-protocols'.
If OTHER-WINDOW is non-nil, open in a different window."
  (interactive (list (read-string "URL: ")
                     current-prefix-arg))
  ;; Strip text properties
  (when (fboundp 'set-text-properties)
    (set-text-properties 0 (length url) nil url))
  (when other-window
    (switch-to-buffer-other-window (current-buffer)))
  (when (string-match muse-url-regexp url)
    (let* ((proto (concat "\\`" (match-string 1 url)))
           (entry (muse-protocol-find proto muse-url-protocols)))
      (when entry
        (funcall (cadr entry) url)))))

(defun muse-resolve-url (url &rest ignored)
  "Resolve URL with the function specified in `muse-url-protocols'."
  (when (string-match muse-url-regexp url)
    (let* ((proto (concat "\\`" (match-string 1 url)))
           (entry (muse-protocol-find proto muse-url-protocols)))
      (when entry
        (let ((func (car (cddr entry))))
          (if func
              (setq url (funcall func url))
            (setq url nil))))))
  url)

(defun muse-protocol-add (protocol browse-function resolve-function)
  "Add PROTOCOL to `muse-url-protocols'.  PROTOCOL may be a regexp.

BROWSE-FUNCTION should be a function that visits a URL in the
current buffer.

RESOLVE-FUNCTION should be a function that transforms a URL for
publishing or returns nil if not linked."
  (add-to-list 'muse-url-protocols
               (list protocol browse-function resolve-function))
  (muse-update-url-regexp 'muse-url-protocols
                          muse-url-protocols))

(defun muse-resolve-url-google (url)
  "Return the correct Google search string."
  (when (string-match "\\`google:/?/?\\(.+\\)" url)
    (concat "http://www.google.com/search?q="
            (match-string 1 url))))

(defun muse-browse-url-google (url)
  "If this is a Google URL, jump to it."
  (let ((google-url (muse-resolve-url-google url)))
    (when google-url
      (browse-url google-url))))

(defun muse-browse-url-info (url)
  "If this in an Info URL, jump to it."
  (require 'info)
  (cond
   ((string-match "\\`info://\\([^#]+\\)#\\(.+\\)" url)
    (Info-find-node (match-string 1 url)
                    (match-string 2 url)))
   ((string-match "\\`info://\\([^#]+\\)" url)
    (Info-find-node (match-string 1 url)
                    "Top"))
   ((string-match "\\`info://(\\([^)]+\\))\\(.+\\)" url)
    (Info-find-node (match-string 1 url) (match-string 2 url)))
   ((string-match "\\`info://\\(.+\\)" url)
    (Info-find-node (match-string 1 url) "Top"))))

(defun muse-browse-url-man (url)
  "If this in a manpage URL, jump to it."
  (cond ((string-match "\\`man://\\(.+\\):\\(.+\\)" url)
         (manual-entry (concat (match-string 1 url)
                               "(" (match-string 2 url) ")")))
        ((string-match "\\`man://\\(.+\\)" url)
         (manual-entry (concat (match-string 1 url))))))

(provide 'muse-protocols)

;;; muse-protocols.el ends here
