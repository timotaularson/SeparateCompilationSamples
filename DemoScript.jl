# Define a function/method
function test0(a::Int64)
    #r = a * 53
    #r = a * Base.chipmunk_funPrecompiledGlobal()
    r = a * Base.chipmunk_funAddGlobalNoInline(a)
    #r = a * Base.chipmunk_funAddGlobal(a)
    #r = a * Base.chipmunk_usedGlobal
    return r
end
function test1(a::Int64)
    #r = a * 53
    #r = a * Base.chipmunk_funPrecompiledGlobal()
    #r = a * Base.chipmunk_funAddGlobal(a)
    #r = a * Base.chipmunk_usedGlobal
    r = test0(a)
    return r
end
test2(a::Int64) = a * Base.chipmunk_test4(a)

# Cause specialization of the method
r0 = test0(Int64(1))
r1 = test1(Int64(1))
r2 = test2(Int64(1))
println("JIT-compiled version 1: ", r1)

println("==>")
#@code_native Base.chipmunk_funAddGlobalNoInline(Int64(1))
@code_native test0(Int64(1))
println("<==")


# Collect specialization for compiling
to_compile = [] # MethodInstance's to compile
for func in [test0, test1, test2]
    m = methods(func)
    mi = m.ms[1].specializations[1]
    push!(to_compile, mi)
end

# Native compile specialization
native_code = ccall(:jl_simple_create_native, Ptr{Cvoid}, (Vector{Core.MethodInstance},), to_compile)

# Remember names of native functions
names = []
for mi in to_compile
    push!(names, (functionObject=mi.cache.functionObject[1:end-1], specFunctionObject=mi.cache.specFunctionObject[1:end-1]))
end

# Produce a shared library containing the native code
ccall(:jl_simple_dump_native, Cvoid, (Ptr{Cvoid}, Cstring,), native_code, "test.a")
#run(`ar x test.a`)
#run(`ld -shared -fPIC -o test.so data.so text.so`)
run(`ld -shared -fPIC -o test.so --whole-archive test.a`)

# Load the shared library
using Libdl
lib = Libdl.dlopen("./test.so", RTLD_GLOBAL)

# Get pointers to the native functions
native_functions = []
for (functionObject, specFunctionObject) in names
    # jl_fun, julia_fun
    push!(native_functions, (jl_fun=Libdl.dlsym(lib, functionObject), julia_fun=Libdl.dlsym(lib, specFunctionObject)))
end

# Redefine the function
function test1(a::Int64)
    a * 3
end

# Test the redefined function
r2 = test1(Int64(1))
println("JIT-compiled version 2: ", r2)

# Link the native code into the specialization
for (idx, func) in enumerate([test0, test1, test2])
    m = methods(func)
    mi = m.ms[1].specializations[1]
    mi.cache.invoke  = native_functions[idx].jl_fun
    mi.cache.specptr = native_functions[idx].julia_fun
end

# Test the function with its native code
r3 = test2(Int64(1))
println("Native compiled test2: ", r3)

r4 = test1(Int64(1))
println("Native compiled test1: ", r4)

# Close the library
Libdl.dlclose(lib)
return nothing

