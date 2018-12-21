Distributed Operating Systems Project
-------------------------------------
Project3 Chord Algorithm
-------------------------------------

Group Members -
  Aditya Dutt 14530933
  Richa Dutt  83877619
-------------------------------------
How to run-
1. Go inside directory Project3.
2. There are two folders - Project and Project_bonus.
(Now, following steps are same for both Project and Project_bonus)
3. Go inside Project. Go inside directory - chord.
4. Now, to compile code type : mix compile
5. To run, type : mix run Project3 arg1 arg2
-------------------------------------

What is working?

Chord algorithm works for both non-failure and failure models.

Non-failure model-
1.(1000,5)-> avg hops=6.588 in 4844 milliseconds
2.(1000,10)-> avg hops=6.755 in 14453 milliseconds
3.(2000,5)-> avg hops=7.102 in 13906 milliseconds
4.(2000,10)-> avg hops=7.2377 in 67734 milliseconds
5.(3000,5)-> avg hops=7.0596 in 17531 milliseconds
6.(3000,10)-> avg hops=7.323 in 129250 milliseconds
7.(4000,5)-> avg hops=7.2121 in 39437 milliseconds
8.(4000,10-> avg hops=7.687 in 323953 milliseconds

Largest network - (10000,5) -> avg hops=14.078 in 299359 milliseconds

------------------------------------

