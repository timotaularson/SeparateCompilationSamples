using Libdl

function collect_code_instances(functions)
    code_instances = [] # MethodInstance's to compile
    for func in functions
        m = methods(func)
        mi = m.ms[1].specializations[1]
        push!(code_instances, mi)
    end
    return code_instances
end

function compile_native(functions)
    to_compile = collect_code_instances(functions)

    # Native compile code instances
    native_code = ccall(:jl_simple_create_native, Ptr{Cvoid}, (Vector{Core.MethodInstance},), to_compile)

    # Remember names of native compiled functions
    names = []
    for mi in to_compile
        push!(names, (functionObject=mi.cache.functionObject[1:end-1], specFunctionObject=mi.cache.specFunctionObject[1:end-1]))
    end

    # Produce a shared library containing the native compiled functions
    ccall(:jl_simple_dump_native, Cvoid, (Ptr{Cvoid}, Cstring,), native_code, "test.a")
    run(`ld -shared -fPIC -o test.so --whole-archive test.a`)

    return names
end

function load_native(lib_path)
    # Load the shared library
    lib = Libdl.dlopen(lib_path, RTLD_GLOBAL)
    ccall(:jl_link_ptls, Ptr{Cvoid}, (Ptr{Cvoid},), lib)

    # Get pointers to the native compiled functions
    native_functions = []
    for (functionObject, specFunctionObject) in names
        # jl_fun, julia_fun
        push!(native_functions, (jl_fun=Libdl.dlsym(lib, functionObject), julia_fun=Libdl.dlsym(lib, specFunctionObject)))
    end

    return lib, native_functions
end

function close_native(lib)
    # Close the library
    Libdl.dlclose(lib)
end

# Define a global
chipmunkScriptGlobal = 2

# Define a function/method
test1(a::Int64) = Base.chipmunk_funAddGlobalNoInline(a)
test2(a::Int64) = Base.chipmunk_funAddGlobalNoInline(a) + 1
test3(a::Int64) = Base.chipmunk_funAddGlobalNoInline(a) + chipmunkScriptGlobal
test4(a::Int64) = Base.chipmunk_funAddGlobalNoInline(a) + Base.chipmunk_usedGlobal

# Cause specialization of the method
#r1 = test1(Int64(1)); println("JIT-compiled test1: ", r1)
precompile(test1, (Int64,)); println("precompiled test1")
r2 = test2(Int64(1)); println("JIT-compiled test2: ", r2)
r3 = test3(Int64(1)); println("JIT-compiled test3: ", r3)
r4 = test4(Int64(1)); println("JIT-compiled test4: ", r4)

names = compile_native([test1, test2, test3, test4])

lib, native_functions = load_native("./test.so")

# Define some placeholder functions
native1(a::Int64) = a * 11
native2(a::Int64) = a * 22
native3(a::Int64) = a * 33
native4(a::Int64) = a * 44

# Test the placeholder functions
r1 = native1(Int64(1)); println("JIT-compiled native1: ", r1)
r2 = native2(Int64(1)); println("JIT-compiled native2: ", r2)
r3 = native3(Int64(1)); println("JIT-compiled native3: ", r3)
r4 = native4(Int64(1)); println("JIT-compiled native4: ", r4)

# Link the native code into the placeholder functions
for (idx, func) in enumerate([native1, native2, native3, native4])
    m = methods(func)
    mi = m.ms[1].specializations[1]
    mi.cache.invoke  = native_functions[idx].jl_fun
    mi.cache.specptr = native_functions[idx].julia_fun
end

# Test the native code by calling the placeholder functions again
r1 = native1(Int64(1)); println("Native compiled native1: ", r1)
r2 = native2(Int64(1)); println("Native compiled native2: ", r2)
r3 = native3(Int64(1)); println("Native compiled native3: ", r3)
r4 = native4(Int64(1)); println("Native compiled native4: ", r4)

close_native(lib)
return nothing

