(use ./new_gap_buffer)

(def backward-texp-grammar
  ~{:symchars (+ (range "09" "AZ" "az" "\x80\xFF") (set "!$%&*+-./:<?=>@^_"))
    :token (some :symchars)
    :ptuple (* ")" (any (if-not "(" 1)) "(")
    :table (* "}" (any (if-not "{" 1)) "{@")
    :table (* "]" (any (if-not "[" 1)) "{@")
    :struct (* "}" (any (if-not "{" 1)) "{")
    :symbol :token
    :texp (+ :symbol :table :ptuple :struct)
    :main (* (any (not :texp)) (<- :texp))})

(def grammar
  ~{:ws (set " \t\r\f\n\0\v")
    :readermac (set "';~,|")
    :symchars (+ (range "09" "AZ" "az" "\x80\xFF") (set "!$%&*+-./:<?=>@^_"))
    :token (some :symchars)
    :hex (range "09" "af" "AF")
    :escape (* "\\" (+ (set "ntrzfev0\"\\")
                       (* "x" :hex :hex)
                       (* "u" [4 :hex])
                       (* "U" [6 :hex])
                       (error (constant "bad escape"))))
    :comment (<- (* (opt "\n") (any (if-not (+ "#" "\n") 1)) "#"))
    :symbol :token
    :keyword (* ":" (any :symchars))
    :constant (* (+ "true" "false" "nil") (not :symchars))
    :bytes (* "\"" (any (+ :escape (if-not "\"" 1))) "\"")
    :string :bytes
    :buffer (* "@" :bytes)
    :long-bytes {:delim (some "`")
                 :open (capture :delim :n)
                 :close (cmt (* (not (> -1 "`")) (-> :n) ':delim) ,=)
                 :main (drop (* :open (any (if-not :close 1)) :close))}
    :long-string :long-bytes
    :long-buffer (* "@" :long-bytes)
    :number (drop (cmt (<- :token) ,scan-number))
    :raw-value (+ :comment :constant :number :keyword
                  :string :buffer :long-string :long-buffer
                  :parray :barray :ptuple :btuple :dict :struct :symbol)
    :raw-value-ignore-comment (+ :constant :number :keyword
                                 :string :buffer :long-string :long-buffer
                                 :parray :barray :ptuple :btuple :dict :struct :symbol)
    :value (* (any (* (not :comment) (+ :ws :readermac))) :raw-value (any :ws))
    :value-ignore-comment (* (any (+ :ws :readermac)) :raw-value-ignore-comment (any :ws))
    :root (any :value)
    :root2 (any (* :value :value))
    :ptuple (* ")" :root "(")
    :btuple (* "]" :root "[")
    :struct (* "}" :root "{")
    :parray (* :ptuple "@")
    :barray (* :btuple "@")
    :dict (* :struct "@")
    #:dict (* "}" :root "{@")
    :main (<- :value-ignore-comment)})

(def s (-> ``
(* 05 5)
ouae
@{:a (+ 01 10)}
(+ 1 1)
(* 5 1)
{:a}
@{:a (+ 1 "hej" # 123
)}
``
           string/reverse))

(def s (-> ``
123
# 123
(:a # 123)
)

{:a 10 # 123
 :b 20}
``))

# (pp (string/reverse s))

(varfn get-last-sexp
  [s]
  (-?>> s
        string/reverse
        (peg/match grammar)
        last
        string/reverse))

# (pp (get-last-sexp s))

(varfn eval-last-sexp
  [gb]
  (-> gb
      commit!
      (get :text)
      (string/slice 0 (gb :caret))
      get-last-sexp
      eval-string
      pp)

  #  (print "huh?")
)

#(eval-last-sexp gb-data)
#(pp (gb-data :caret))
#(pp (get-last-sexp text))
