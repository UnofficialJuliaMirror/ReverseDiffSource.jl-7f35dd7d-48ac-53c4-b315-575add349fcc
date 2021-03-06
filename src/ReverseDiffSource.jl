#########################################################################
#
#   Julia Package for reverse mode automated differentiation (from source)
#
#########################################################################

module ReverseDiffSource

    import Base.show, Base.copy, Base.length

    using Compat  # for compatibility across julia versions

    # naming conventions
    const TEMP_NAME = "_tmp"   # prefix of new variables
    const DERIV_PREFIX = "d"   # prefix of gradient variables

    ## misc functions
    dprefix(v::Union{Symbol, AbstractString, Char}) = Symbol("$DERIV_PREFIX$v")

    isSymbol(ex)   = isa(ex, Symbol)
    isDot(ex)      = isa(ex, Expr) && ex.head == :.   && isa(ex.args[1], Symbol)
    isRef(ex)      = isa(ex, Expr) && ex.head == :ref && isa(ex.args[1], Symbol)

    ## temp var name generator
    let
        vcount = Dict()
        global newvar
        function newvar(radix::Union{AbstractString, Symbol}=TEMP_NAME)
            vcount[radix] = haskey(vcount, radix) ? vcount[radix]+1 : 1
            return Symbol("$(radix)$(vcount[radix])")
        end

        global resetvar
        function resetvar()
            vcount = Dict()
        end
    end

    ######  Includes  ######
    include("node.jl")
    include("bidict.jl")
    include("graph.jl")
    include("plot.jl")
    include("simplify.jl")
    include("tograph.jl")
    include("tocode.jl")
    include("zeronode.jl")
    include("reversegraph.jl")
    include("deriv_rule.jl")
    include("base_rules.jl")
    include("rdiff.jl")
    include("frdiff.jl")

    ######  Exports  ######
    export
        rdiff,
        @deriv_rule, deriv_rule

end # module ReverseDiffSource
