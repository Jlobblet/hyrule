;;; Hy tail-call optimization

"The loop/recur macro allows you to construct functions that use tail-call
optimization to allow arbitrary levels of recursion.


.. versionadded:: 0.10.0

The ``loop`` / ``recur`` macro gives programmers a simple way to use
tail-call optimization (TCO) in their Hy code.

    A tail call is a subroutine call that happens inside another
    procedure as its final action; it may produce a return value which
    is then immediately returned by the calling procedure. If any call
    that a subroutine performs, such that it might eventually lead to
    this same subroutine being called again down the call chain, is in
    tail position, such a subroutine is said to be tail-recursive,
    which is a special case of recursion. Tail calls are significant
    because they can be implemented without adding a new stack frame
    to the call stack. Most of the frame of the current procedure is
    not needed any more, and it can be replaced by the frame of the
    tail call. The program can then jump to the called
    subroutine. Producing such code instead of a standard call
    sequence is called tail call elimination, or tail call
    optimization. Tail call elimination allows procedure calls in tail
    position to be implemented as efficiently as goto statements, thus
    allowing efficient structured programming.

    -- Wikipedia (https://en.wikipedia.org/wiki/Tail_call)
"

(require
  hyrule.macros [defmacro/g!])

(import
  hyrule.contrib.walk [prewalk])

(defn _trampoline [f]
  "Wrap f function and make it tail-call optimized."
  ;; Takes the function "f" and returns a wrapper that may be used for tail-
  ;; recursive algorithms. Note that the returned function is not side-effect
  ;; free and should not be called from anywhere else during tail recursion.

  (setv result None)
  (setv active False)
  (setv accumulated [])

  (fn [#* args]
    (nonlocal active)
    (.append accumulated args)
    (when (not active)
      (setv active True)
      (while (> (len accumulated) 0)
        (setv result (f #* (.pop accumulated))))
      (setv active False)
      result)))


(defmacro/g! loop [bindings #* body]
  "``loop`` establishes a recursion point. With ``loop``, ``recur``
  rebinds the variables set in the recursion point and sends code
  execution back to that recursion point. If ``recur`` is used in a
  non-tail position, an exception is raised. which
  causes chaos.

  Usage: ``(loop bindings #* body)``

  Examples:
    ::

       => (require hyrule.contrib.loop [loop])
       => (defn factorial [n]
       ...  (loop [[i n] [acc 1]]
       ...    (if (= i 0)
       ...      acc
       ...      (recur (dec i) (* acc i)))))
       => (factorial 1000)"
  (setv [fnargs initargs] (if bindings (zip #* bindings) [[] []]))
  (setv new-body (prewalk
    (fn [x] (if (= x 'recur) g!recur-fn x))
    body))
  `(do
    (import hyrule.contrib.loop [_trampoline :as ~g!t])
    (setv ~g!recur-fn (~g!t (fn [~@fnargs] ~@new-body)))
    (~g!recur-fn ~@initargs)))
