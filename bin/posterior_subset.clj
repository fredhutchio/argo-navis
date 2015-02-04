#!/usr/bin/env lein-exec
(ns posterior-subset
  (:require [clojure.tools.cli :refer [parse-opts]]
            [clojure.string :as string]
            [clojure.java.io :as io]))


(def tree-line-regexp #"(?i)tree STATE_.*")
(def log-line-regexp #"(?i)^(sample|[^#]).*")
(def file-type-regexp-map
  {:treefile tree-line-regexp
   :logfile  log-line-regexp})


(defn count-lines
  [file file-type]
  (with-open [rdr (io/reader file)]
    (->> (line-seq rdr)
      ; XXX branch
      (filter (partial re-matches (file-type-regexp-map file-type)))
      (count))))


(defn abs
  [r]
  (Math/abs (float r)))


(defn ratio-tester
  [goal left-out left-in]
  (let [new-base (+ left-out left-in 1)
        closeness (fn [r] (abs (- goal r)))]
    (< (closeness (/ (inc left-in) new-base))
       (closeness (/ left-in new-base)))))


(defn line-writer
  [wtr infile actual-count desired-count]
  (with-open [rdr (io/reader infile)]
    (let [ratio-goal (/ desired-count actual-count)]
      (loop [left-out 0
             left-in  0
             lines-left (line-seq rdr)]
        (when (seq lines-left)
          (let [leave-in? (ratio-tester ratio-goal left-out left-in)]
            (if leave-in?
              (do
                (.write wtr (str (first lines-left) \newline))
                (recur left-out (inc left-in) (rest lines-left)))
              (recur (inc left-out) left-in (rest lines-left)))))))))


(defn rarefy-file
  [[infile outfile :as args] {:keys [out-count out-fraction file-type] :as opts}]
  (when out-fraction (throw "out-fraction not yet supported"))
  ; XXX should merge these `with-open` calls
  (with-open [wtr (io/writer outfile)]
    (with-open [rdr (io/reader infile)]
      (loop [lines-left (line-seq rdr)]
        (let [current-line (first lines-left)]
          ; Fork here
          (when-not (re-matches (file-type-regexp-map file-type) current-line)
            (.write wtr (str current-line \newline))
            (recur (rest lines-left))))))
    (let [infile-line-count (count-lines infile file-type)]
      (line-writer wtr infile infile-line-count out-count))))


(def cli-options
  [["-c" "--out-count COUNT" "Approximate number of lines in output file" :parse-fn #(Integer/parseInt %)]
   ["-f" "--out-fraction FRACTION" "Approximate fraction of lines to keep in output file (not supported yet)" :parse-fn #(Float/parseFloat %)]
   ["-t" "--file-type FTYPE" "Type of file (either 'logfile' or 'treefile')" :parse-fn keyword]
   ["-h" "--help"]])

(defn usage [options-summary]
  (->> ["Rarefy a posterior file, as output by beast. Options --out-count and --out-fraction"
        "respectively rarefy to a total count of lines in the output, or a fraction of lines"
        "present in the output:"
        ""
        options-summary]
    (string/join \newline)))

(defn error-msg [errors]
  (str "The following errors occurred in parsing:\n\n"
       (string/join \newline errors)))

(defn exit [status & msgs]
  (apply println msgs)
  (System/exit status))

(defn -main [& args]
  (let [{:keys [options arguments errors summary]} (parse-opts args cli-options)]
    (cond
      (:help options) (exit 0 (usage summary))
      (not= (count arguments) 2) (exit 1
                                       "Must specify infile and outfile args\n"
                                       (usage summary))
      errors (exit 1 (error-msg errors)))
    (rarefy-file arguments options)))

(apply -main (rest *command-line-args*))

