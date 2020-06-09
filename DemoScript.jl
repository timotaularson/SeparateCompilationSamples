# Define a function/method
function test1(a::Int64)
    r = a * 7
    println("Hello, World!")
    return r
end

# Cause specialization of the method
r1 = test1(Int64(1))
println("JIT-compiled version 1: ", r1)

# Collect specialization for compiling
mis = []
m = methods(test1)
mi = m.ms[1].specializations[1]
push!(mis, mi)

# Native compile specialization
native_code = ccall(:jl_simple_create_native, Ptr{Cvoid}, (Vector{Core.MethodInstance},), mis)

# Remember names of native functions
functionObject = mi.cache.functionObject[1:end-1]
specFunctionObject = mi.cache.specFunctionObject[1:end-1]

# Produce a shared library containing the native code
ccall(:jl_simple_dump_native, Cvoid, (Ptr{Cvoid}, Cstring,), native_code, "test.a")
#run(`ar x test.a`)
#run(`ld -shared -fPIC -o test.so data.so text.so`)
run(`ld -shared -fPIC -o test.so --whole-archive test.a`)

# Load the shared library
using Libdl
lib = Libdl.dlopen("./test.so", RTLD_GLOBAL)

# Get pointers to the native functions
jl_fun = Libdl.dlsym(lib, functionObject)
julia_fun = Libdl.dlsym(lib, specFunctionObject)

# Redefine the function
function test1(a::Int64)
    a * 3
end

# Test the redefined function
r2 = test1(Int64(1))
println("JIT-compiled version 2: ", r2)

# Link the native code into the specialization
m = methods(test1)
mi = m.ms[1].specializations[1]
mi.cache.invoke = jl_fun
mi.cache.specptr = julia_fun

# Test the function with its native code
r3 = test1(Int64(1))
println("Native compiled version 1: ", r3)

# Close the library
Libdl.dlclose(lib)
return nothing

