module DemoPkg

g = Int64(2)

test1(x::Int64) = x * 5

precompile(test1, (Int64,))

end # module
