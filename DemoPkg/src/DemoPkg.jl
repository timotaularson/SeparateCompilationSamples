module DemoPkg

g = Int64(2)

test1(x::Int64) = x * 5
test2(x::Int64) = Base.chipmunk_funAddGlobalNoInline(x)
test3(x::Int64) = Base.chipmunk_funAddGlobalNoInline(x) + 2
test4(x::Int64, y::Float64) = x * 5 + y

precompile(test1, (Int64,))
precompile(test2, (Int64,))
precompile(test3, (Int64,))
precompile(test4, (Int64, Float64))

end # module
