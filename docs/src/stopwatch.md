# Stop watch for MPI

It is often important to time operations in MPI. The `StopWatch` object will do that for you by recording the current MPI time (with `MPI.Wtime`) when you ask for a "stamp" given a label. The "start" stamp is recorded automatically when the StopWatch is created. You add more stamps with the `stamp` function. If you want to transport the StopWatch over MPI, then you can turn it into a NamedTuple with `asNamedTuple` (the NamedTuple will be `isbits` compatible).

```@repl
using IRMA

sw = StopWatch()  # The start stamp is automatically recorded

# Do stuff
sleep(0.2)
stamp(sw, "A")

# Do more stuff
sleep(0.2)
stamp(sw, "B")

# Now we want to do MPI.Gather or something similar
nt = asNamedTuple(sw)
# allTimes = MPI.Gather(nt, root, comm)
```
