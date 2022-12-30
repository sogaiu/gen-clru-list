(comment

  (def feed-item
    ``
    {:group-id "viz-cljc",
     :artifact-id "viz-cljc",
     :description "Clojure and Clojurescript support for Viz.js",
     :scm {:tag "73b1e3ffcbad54088ac24681484ee0f97b382f1b",
           :url ""},
     :homepage "http://example.com/FIXME",
     :url "http://example.com/FIXME",
     :versions ["0.1.3" "0.1.2" "0.1.0"]}
    ``)

  # XXX: almost works...commas screw things up
  (def parsed-j
    (parse feed-item))

  # XXX: "corrupts" data but may be ok for some purposes
  (def massage-then-parse-as-jdn
    (->> feed-item
         (string/replace-all "," " ")
         parse))
  # =>
  {:artifact-id "viz-cljc"
   :description "Clojure and Clojurescript support for Viz.js"
   :group-id "viz-cljc"
   :homepage "http://example.com/FIXME"
   :scm {:tag "73b1e3ffcbad54088ac24681484ee0f97b382f1b"
         :url ""}
   :url "http://example.com/FIXME"
   :versions ["0.1.3" "0.1.2" "0.1.0"]}

  )

(defn is-numeric-version?
  [version]
  (truthy?
    (peg/match ~(sequence (some :d)
                          (any (sequence "." (some :d)))
                          -1)
               version)))

(comment

  (is-numeric-version? "1.0")
  # =>
  true

  (is-numeric-version? "1.0-SNAPSHOT")
  # =>
  false

  (is-numeric-version? "1.")
  # =>
  false

  (is-numeric-version? "0.8")
  # =>
  true

  (is-numeric-version? ".8")
  # =>
  false

  )

(defn is-higher-version?
  [left-version right-version]
  (var left-bits
    (map scan-number
         (string/split "." left-version)))
  (var right-bits
    (map scan-number
         (string/split "." right-version)))
  (let [left-len (length left-bits)
        right-len (length right-bits)
        diff-len (math/abs (- left-len right-len))
        rounds (max left-len right-len)]
    # if there is a shorter thing, pad it with zeros
    (unless (zero? diff-len)
      (for i 0 diff-len
        (if (< left-len right-len)
          (array/push left-bits 0)
          (array/push right-bits 0))))
    # compare as much as necessary to determine answer
    (var j 0)
    (var result 0)
    (while (and (zero? result)
                (< j rounds))
      (let [left (get left-bits j)
            right (get right-bits j)]
        (cond
          (< left right)
          (set result -1)
          #
          (> left right)
          (set result 1))
        (++ j)))
    # return true only if the left thing was higher
    (if (one? result)
      true
      false)))

(comment

  (is-higher-version? "1.0" "2.0")
  # =>
  false

  (is-higher-version? "2.0" "1.0")
  # =>
  true

  (is-higher-version? "3.0" "2.2")
  # =>
  true

  (is-higher-version? "1.0.0" "1")
  # =>
  false

  )

(defn determine-max-version
  [versions]
  (->> versions
       (filter is-numeric-version?)
       (extreme is-higher-version?)))

(comment

  (determine-max-version ["1.0" "2.0" "1.0-SNAPSHOT"])
  # =>
  "2.0"

  (determine-max-version ["0.3.6-SNAPSHOT" "0.3.5" "0.3.5-SNAPSHOT"
                          "0.3.4" "0.3.3" "0.3.3-SNAPSHOT" "0.3.2"
                          "0.3.2-SNAPSHOT" "0.3.1" "0.3.0" "0.3.0-SNAPSHOT"
                          "0.2.0" "0.2.0-SNAPSHOT" "0.1.3-SNAPSHOT" "0.1.2"
                          "0.1.1" "0.1.1-SNAPSHOT" "0.1.0"])
  # =>
  "0.3.5"

  (determine-max-version ["0.1.24" "0.1.23" "0.1.22" "0.1.21" "0.1.20"
                          "0.1.19" "0.1.18" "0.1.17" "0.1.16" "0.1.15"
                          "0.1.14" "0.1.13" "0.1.12" "0.1.11" "0.1.10"
                          "0.1.9" "0.1.8" "0.1.7" "0.1.6" "0.1.5" "0.1.4"
                          "0.1.3" "0.1.2" "0.1.1" "0.1.0"])
  # =>
  "0.1.24"

  (determine-max-version ["1.0-SNAPSHOT"])
  # =>
  nil

  # XXX
  (determine-max-version ["0.19.0-1" "0.19.0-0"])
  # =>
  nil

  (determine-max-version ["20181204" "20180722" "20180721" "20180327"
                          "0.4.4" "0.4.3" "0.4.2" "0.4.1" "0.4" "0.3"
                          "0.2.3" "0.2.2" "0.2.1" "0.2" "0.1.0"])
  # =>
  "20181204"

  # XXX
  (determine-max-version ["3.0.0-dre" "3.0.0-dre-SNAPSHOT"])
  # =>
  nil

  # XXX
  (determine-max-version ["20221222.234117.41b3150" "20221222.204442.8fbb766"
                          "20221222.001341.75dcd7b" "20220604.173626.6da6a4d"])
  # =>
  nil

  )

# XXX
#
# dash and then a decimal number
#
#   1.0.2-3
#
# last number (after period) is hex
#
#   20221222.234117.41b3150
#
# looks like commit hash fragment in some cases:
#   https://github.com/yetibot/core/commit/41b315047101183db4f3c17fa9f4581700692d40
#
# dash followed by hex at end
#
#   0.2.1-55b562b
#
# looks like commit hash fragment in some cases:
#   https://github.com/trhura/clojure-humanize/commit/55b562ba8e1d2aa3c61f7b99d3218b5d73a61603

(defn feed-string->struct
  [feed-str]
  (->> feed-str
       (string/replace-all "," " ")
       parse))

(comment

  (def feed-item-str
    ``
    {:group-id "viz-cljc",
     :artifact-id "viz-cljc",
     :description "Clojure and Clojurescript support for Viz.js",
     :scm {:tag "73b1e3ffcbad54088ac24681484ee0f97b382f1b",
           :url ""},
     :homepage "http://example.com/FIXME",
     :url "http://example.com/FIXME",
     :versions ["0.1.3" "0.1.2" "0.1.0"]}
    ``)

  (feed-string->struct feed-item-str)
  # =>
  {:artifact-id "viz-cljc"
   :description "Clojure and Clojurescript support for Viz.js"
   :group-id "viz-cljc"
   :homepage "http://example.com/FIXME"
   :scm {:tag "73b1e3ffcbad54088ac24681484ee0f97b382f1b"
         :url ""}
   :url "http://example.com/FIXME"
   :versions ["0.1.3" "0.1.2" "0.1.0"]}

  )

(defn feed-item->url
  [feed-item]
  (def {:group-id group-id
        :artifact-id artifact-id
        :versions versions}
    feed-item)
  (def max-version
    (determine-max-version versions))
  (when max-version
    (string "https://repo.clojars.org/"
            (string/replace-all "." "/" group-id) "/"
            artifact-id "/"
            max-version "/"
            artifact-id "-" max-version ".jar")))

(comment

  (def feed-item
    {:artifact-id "viz-cljc"
     :description "Clojure and Clojurescript support for Viz.js"
     :group-id "viz-cljc"
     :homepage "http://example.com/FIXME"
     :scm {:tag "73b1e3ffcbad54088ac24681484ee0f97b382f1b"
           :url ""}
     :url "http://example.com/FIXME"
     :versions ["0.1.3" "0.1.2" "0.1.0"]})

  (feed-item->url feed-item)
  # =>
  "https://repo.clojars.org/viz-cljc/viz-cljc/0.1.3/viz-cljc-0.1.3.jar"

  )

(when-let [fc (file/open "feed.clj" :r)
           clru (file/open "latest-release-jar-urls.txt" :w)]
  (while true
    (def line (file/read fc :line))
    (unless line
      (break))
    (def url
      (feed-item->url (feed-string->struct line)))
    (when url
      (file/write clru url)
      (file/write clru "\n")))
  #
  (file/close fc)
  (file/close clru))
