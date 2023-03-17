;; the straight.el bits here are for a "portable" setup -- one that
;; shouldn't interefere with a user's existing emacs setup

;; XXX: if not using in a portable setup, skip the following bits
;;      until the first `require` below

;; get straight.el and friends to live in a custom location
(defvar straight-base-dir
  (file-name-directory (locate-file "gen-clru-list.el" '("."))))

;; via:
;;   https://github.com/radian-software/straight.el#getting-started
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el"
                         ;; XXX: customized above
                         straight-base-dir))
      (bootstrap-version 6))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         (concat
          "https://raw.githubusercontent.com/radian-software/straight.el"
          "/develop/install.el")
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; via:
;;   https://github.com/radian-software/straight.el#integration-with-use-package
(straight-use-package 'use-package)
(setq straight-use-package-by-default t)

(straight-use-package
  '(parseedn :host github
             :repo "clojure-emacs/parseedn"
             :files ("*.el")))

(use-package parseedn
  :straight t)

;; XXX: don't evaluate stuff above here unless using in a "portable"
;;      setup

(require 'parseedn)

(defmacro gcl-comment (&rest body)
  "Ignore BODY."
  nil)

(defun gcl-version-string-compare (str1 str2)
  "Compare version strings STR1 and STR2.

Return:
  -1 if STR1 < STR2
   0 if STR1 = STR2
   1 if STR1 > STR2

where <, =, and > have version-comparing semantics.
STR1 and STR2 have the constraints that:
  1) start and end with digit(s)
  2) if contain dots, each dot has a digit on either side
Examples:
  OK: 1.0.0, 8, and 0.2.3
  NOT OK: .1, 3., and 0..2"
  (let* ((l1 (mapcar #'string-to-number
                     (split-string str1 "\\.")))
         (l2 (mapcar #'string-to-number
                     (split-string str2 "\\.")))
         (len-1 (length l1))
         (len-2 (length l2))
         (diff-len (abs (- len-1 len-2))))
    ;; if either list is shorter, pad with enough zeros
    (unless (zerop diff-len)
      (dotimes (i diff-len)
        (if (< len-1 len-2)
            (setq l1 (append l1 (list 0)))
          (setq l2 (append l2 (list 0))))))
    ;; compare each element until no longer necessary
    (let ((rounds (max len-1 len-2))
          (j 0)
          (result 0))
      (while (and (zerop result)
                  (< j rounds))
        (let ((left (nth j l1))
              (right (nth j l2)))
          (cond ((< left right)
                 (setq result -1))
                ((> left right)
                 (setq result 1))))
        (setq j (1+ j)))
      result)))

(gcl-comment

 (gcl-version-string-compare "1.0" "2.0")
 ;; => -1

 (gcl-version-string-compare "3.0" "2.2")
 ;; => 1

 (gcl-version-string-compare "1.0.0" "1")
 ;; => 0

 )

(defvar gcl-numeric-version-string-re
  (rx string-start
      (seq (one-or-more digit)
           (zero-or-more (seq "." (one-or-more digit))))
      string-end)
    "Regular expression to match version strings with numbers and dots only.")

(gcl-comment

 (string-match-p gcl-numeric-version-string-re "1.0.0")
 ;; => 0

 (string-match-p gcl-numeric-version-string-re "2")
 ;; => 0

 (string-match-p gcl-numeric-version-string-re ".")
 ;; => nil

 (string-match-p gcl-numeric-version-string-re "8.")
 ;; => nil

 )

(defun gcl-feed-item->url (feed-item)
  "Create a Clojars url for FEED-ITEM.

FEED-ITEM is a string representing a Clojure map.

The string is typically a line from feed.clj."
  (let ((tbl (parseedn-read-str feed-item)))
    (when tbl
      (let* ((versions (append (gethash :versions tbl) nil)) ; -> list
             (group-id (gethash :group-id tbl))
             (artifact-id (gethash :artifact-id tbl)))
        (unless (seq-empty-p versions)
          (setq versions
                (seq-filter
                 (lambda (elt)
                   (string-match-p gcl-numeric-version-string-re elt))
                 versions))
          (unless (seq-empty-p versions)
            (let ((max-version (nth 0 versions)))
              (dotimes (i (1- (length versions)))
                (let ((current-version (nth i versions)))
                  (when (= -1
                           (gcl-version-string-compare max-version
                                                       current-version))
                    (setq max-version current-version))))
              (concat "https://repo.clojars.org/"
                      (string-replace "." "/" group-id)
                       "/" artifact-id
                       "/" max-version
                       "/" artifact-id "-" max-version ".jar"))))))))

(gcl-comment

 (setq sample-feed-item
       (concat "{"
               ":group-id \"viz-cljc\","
               ":artifact-id \"viz-cljc\","
               ":description \"Clojure and Clojurescript support for Viz.js\","
               ":scm {:tag \"73b1e3ffcbad54088ac24681484ee0f97b382f1b\","
               ":url ""},"
               ":homepage \"http://example.com/FIXME\","
               ":url \"http://example.com/FIXME\","
               ":versions [\"0.1.3\" \"0.1.2\" \"0.1.0\"]"
               "}"))

 (gcl-feed-item->url sample-feed-item)
 ;; => "https://repo.clojars.org/viz-cljc/viz-cljc/0.1.3/viz-cljc-0.1.3.jar"

 )

(defun gcl-process-feed-clj ()
  "Create a list of clojars urls based on current buffer.

The current buffer should contain data in the format of feed.clj."
  (save-excursion
    (goto-char (point-min))
    (let ((urls (list))
          done)
      (while (not (eobp))
        (let* ((start (point))
               (end (or (end-of-line) (point))))
          (when (and start end)
            (let ((url (gcl-feed-item->url
                        (buffer-substring-no-properties start end))))
              (when url
                (setq urls
                      ;; XXX: better to not append repeatedly?
                      (append urls (list url)))))))
        (forward-line))
      urls)))

(defun gcl-make-and-save-list (src dest)
  "Read and process SRC, then write url list to DEST."
  (let ((src-buffer (find-file src)))
    (when src-buffer
      (let ((url-list (gcl-process-feed-clj)))
        (when (not (seq-empty-p url-list))
          (let ((dest-buffer (find-file dest)))
            (when dest-buffer
              (goto-char (point-min))
              (dolist (url url-list)
                (insert url)
                (insert "\n"))
              (save-buffer))))))))

(gcl-comment

 (gcl-make-and-save-list "feed.clj" "latest-release-jar-urls.txt")

 )

(provide 'gen-clru-list)
;;; gen-clru-list.el ends here
