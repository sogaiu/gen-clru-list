#! /usr/bin/env bb

(require
  '[babashka.curl :as bc]
  '[clojure.edn :as ce]
  '[clojure.java.io :as cji]
  '[clojure.java.shell :as cjs]
  '[clojure.string :as cs])

(def clojars-repo-root
  "https://repo.clojars.org")

;; https://github.com/clojars/clojars-web/wiki/Data#useful-extracts-from-the-poms
(def feed-url
  "http://clojars.org/repo/feed.clj.gz")

;; XXX: factor out logging?
(defn fetch-to-file
  [url out-fpath]
  ;; XXX: how to check whether success?
  ;; XXX: waiting for redirects
  #_(cji/copy (bc/get url {:as :stream})
      (cji/file out-fpath))
  (let [exit (:exit (cjs/sh "curl"
                      url "-L" "-o" out-fpath))]
    (spit "log.txt"
      (str exit ":" url "\n")
      :append true)))

(comment

  (fetch-to-file feed-url "feed.clj.gz")

  )

;; XXX: how about things like 1.2.0-3?
;;      ignore for now
(defn triple-num-version?
  [ver-str]
  (let [[_ left mid right] (re-find #"^(\d+)\.(\d+)\.(\d+)$" ver-str)]
    (when (and left mid right)
      (mapv (fn [item]
              (Integer/parseInt item))
        [left mid right]))))

(comment

  (triple-num-version? "1.2.0")
  ;; => [1 2 0]

  (triple-num-version? "7.0-20160503141241")
  ;; => nil

  )

(defn compare-triple-num-versions
  [[a1 a2 a3] [b1 b2 b3]]
  (if (< a1 b1) -1
    (if (> a1 b1) 1
      (if (< a2 b2) -1
        (if (> a2 b2) 1
          (if (< a3 b3) -1
            (if (> a3 b3) 1
              0)))))))

(comment

  (compare-triple-num-versions [0 1 0] [0 2 0])
  ;; => -1

  (compare-triple-num-versions [0 8 0] [0 3 0])
  ;; => -1

  (compare-triple-num-versions [0 7 0] [0 7 0])
  ;; => 0

  )

;; XXX: 'normal' here means uses a version string of
;;      of the form <number>.<number>.<number>
(defn latest-normal-version
  [versions]
  (let [normal-versions (filter triple-num-version? versions)]
    (->> normal-versions
      (sort-by triple-num-version?
        (fn [a b]
          (compare-triple-num-versions b a)))
      first)))

(comment

  (def versions
    ["1.7.0"])
  
  (latest-normal-version versions)
  ;; => "1.7.0"
  
  (def versions
    ["0.4.0"
     "0.4.0-beta1"
     "0.3.2"
     "0.3.1"
     "0.3.0"
     "0.3.0-SNAPSHOT"
     "0.2.2"
     "0.2.1"
     "0.2.0b3"
     "0.2.0b2"
     "0.2.0b1"])

  (latest-normal-version versions)
  ;; => "0.4.0"

  (def versions
    ["0.2.0-SNAPSHOT"
     "0.2.0-alpha7"
     "0.2.0-alpha3-SNAPSHOT"
     "0.2.0-alpha1"
     "0.1.19-SNAPSHOT"
     "0.1.18.2"
     "0.1.18.1"
     "0.1.18"
     "0.1.15"
     "0.1.0-SNAPSHOT"
     "0.1.0-alpha13"
     "0.1.0-alpha1"])

  ;; XXX: should this have been 0.1.18.2?
  (latest-normal-version versions)
  ;; => "0.1.18"

  ;; no latest-normal-version
  (def versions
    ["0.1.9-SNAPSHOT"
     "0.1.9-beta3"
     "0.1.9-beta2"
     "0.1.9-beta1"])

  (latest-normal-version versions)
  ;; => nil

  )

;; XXX: platform-dependent?
(defn feed-map->ext-line
  [{:keys [:artifact-id :group-id :versions]} ext]
  (when-let [ver (latest-normal-version versions)]
    (let [group-path (cs/replace group-id "." "/")]
      (str "./"
        group-path "/"
        artifact-id "/"
        ver "/"
        artifact-id "-" ver "." ext))))

(comment

  (def feed-map
    {:group-id "viz-cljc",
     :artifact-id "viz-cljc",
     :description "Clojure and Clojurescript support for Viz.js",
     :scm {:tag "73b1e3ffcbad54088ac24681484ee0f97b382f1b", :url ""},
     :homepage "http://example.com/FIXME",
     :url "http://example.com/FIXME",
     :versions ["0.1.3" "0.1.2" "0.1.0"]})

  (feed-map->ext-line feed-map "pom")
  ;; => "./viz-cljc/viz-cljc/0.1.3/viz-cljc-0.1.3.pom"

  )

(defn feed-map->pom-line
  [m]
  (feed-map->ext-line m "pom"))

(comment

  (def feed-map
    {:group-id "viz-cljc",
     :artifact-id "viz-cljc",
     :description "Clojure and Clojurescript support for Viz.js",
     :scm {:tag "73b1e3ffcbad54088ac24681484ee0f97b382f1b", :url ""},
     :homepage "http://example.com/FIXME",
     :url "http://example.com/FIXME",
     :versions ["0.1.3" "0.1.2" "0.1.0"]})

  (feed-map->pom-line feed-map)
  ;; => "./viz-cljc/viz-cljc/0.1.3/viz-cljc-0.1.3.pom"

  )

(defn feed-map->jar-line
  [m]
  (feed-map->ext-line m "jar"))

(comment

  (def feed-map
    {:group-id "viz-cljc",
     :artifact-id "viz-cljc",
     :description "Clojure and Clojurescript support for Viz.js",
     :scm {:tag "73b1e3ffcbad54088ac24681484ee0f97b382f1b", :url ""},
     :homepage "http://example.com/FIXME",
     :url "http://example.com/FIXME",
     :versions ["0.1.3" "0.1.2" "0.1.0"]})

  (feed-map->jar-line feed-map)
  ;; => "./viz-cljc/viz-cljc/0.1.3/viz-cljc-0.1.3.jar"

  )

(defn feed-map->jar-url
  [m]
  (when-let [jar-line (feed-map->jar-line m)]
    (let [[_ dot-less-line] (re-find #"^\.(.*)" jar-line)]
      (str clojars-repo-root dot-less-line))))

(comment

  (def feed-map
    {:group-id "viz-cljc",
     :artifact-id "viz-cljc",
     :description "Clojure and Clojurescript support for Viz.js",
     :scm {:tag "73b1e3ffcbad54088ac24681484ee0f97b382f1b", :url ""},
     :homepage "http://example.com/FIXME",
     :url "http://example.com/FIXME",
     :versions ["0.1.3" "0.1.2" "0.1.0"]})

  (feed-map->jar-url feed-map)
  ;; => "https://repo.clojars.org/viz-cljc/viz-cljc/0.1.3/viz-cljc-0.1.3.jar"

  )
  
(defn write-latest-jar-urls
  [feed out-file]
  (doseq [feed-map feed]
    (when-let [jar-url (feed-map->jar-url feed-map)]
      (.write out-file jar-url)
      (.write out-file "\n"))))

(comment

  (fetch-to-file feed-url "feed.clj.gz")

  (:exit (cjs/sh "gunzip" "feed.clj.gz"))
  ;; => 0

  (with-open [out-file (cji/writer "latest-release-jar-urls.txt")]  
    (write-latest-jar-urls
      (ce/read-string
        (str "[" (slurp (cji/file "feed.clj")) "]"))
      out-file))

  )

;; main

(println "Fetching feed.clj.gz from clojars...")
(fetch-to-file feed-url "feed.clj.gz")

(when (= (:exit (cjs/sh "gunzip" "feed.clj.gz"))
         0)
  (println "Writing latest release jars url list...")
  (with-open [out-file (cji/writer "latest-release-jar-urls.txt")]  
    (write-latest-jar-urls
     (ce/read-string
      (str "[" (slurp (cji/file "feed.clj")) "]"))
     out-file)))
