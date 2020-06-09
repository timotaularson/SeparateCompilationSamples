module PkgC

g = Int64(2)

greet(x::Int64) = x * 5

precompile(greet, (Int64,))

end # module
