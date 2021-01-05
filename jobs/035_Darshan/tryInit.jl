module TryInit

println("AA")
const a = Ref{String}("Joe")

function __init__()
    println("BB")
    println(a[])
    a[] = "Fred"
end


end # TryInit