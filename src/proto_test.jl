pwd()
cd("..")
cd("/home/fred/devl")
cd("ReverseDiffSource.jl")

########### load and reload  ##########

    module Proto
        include("src/proto.jl")
        include("src/graph_funcs.jl")
        include("src/reversegraph.jl")
        include("src/graph_code.jl")
        include("src/proto_rules.jl")
    end

    function reversediff(ex, paramsym::Vector{Symbol}, outsym=nothing)
        Proto.resetvar()

        g, d, exitnode = Proto.tograph(ex)
        (outsym != nothing) && !haskey(d, outsym) && error("can't find output var $outsym")
        (outsym == nothing) && (exitnode == nothing) && error("can't identify expression's output")
        
        (exitnode, outsym) = outsym == nothing ? (exitnode, :res) : ( d[outsym], outsym) 

        g.exitnodes = { outsym => exitnode }

        Proto.splitnary!(g)
        Proto.dedup!(g)
        Proto.simplify!(g)
        Proto.prune!(g)
        Proto.evalsort!(g)
        Proto.calc!(g)

        dg, dnodes = Proto.reversegraph(g, g.exitnodes[outsym], paramsym)
        g.nodes = [g.nodes, dg]
        for i in 1:length(paramsym)
            g.exitnodes[Proto.dprefix(paramsym[i])] = dnodes[i]
        end
        # println(g.nodes)

        # g.exitnodes[:dy] == g.nodes[4]
        # g.exitnodes[:dx] == g.nodes[4]
        # g.exitnodes[:res] == g.nodes[3]
        # println(g.nodes)

        # (g2, length(g2))
        Proto.splitnary!(g)
        Proto.dedup!(g)
        Proto.evalconstants!(g)
        Proto.simplify!(g)
        Proto.prune!(g)
        #  (g2, length(g2))
        Proto.evalsort!(g)

        # println(g.nodes)
        Proto.tocode(g)
    end

########### array results  ##########

    a = [1,2,3]
    x = 1.
    ex = :( y = a .* x ; o1 = y[1] ; o2 = y[2] ; o3 = y[3])

    g, d, exitnode = Proto.tograph(ex)
    g.exitnodes = { :out1 => d[:o1],  :out2 => d[:o2], :out3 => d[:o3] }

    Proto.splitnary!(g); Proto.evalconstants!(g); Proto.dedup!(g); 
    Proto.simplify!(g); Proto.prune!(g); Proto.calc!(g)

    dg1, dnodes = Proto.reversegraph(g, g.exitnodes[:out1], [:x])
    g.exitnodes[Proto.dprefix(:x1)] = dnodes[1]
    dg2, dnodes = Proto.reversegraph(g, g.exitnodes[:out2], [:x])
    g.exitnodes[Proto.dprefix(:x2)] = dnodes[1]
    dg3, dnodes = Proto.reversegraph(g, g.exitnodes[:out3], [:x])
    g.exitnodes[Proto.dprefix(:x3)] = dnodes[1]

    g.nodes = [g.nodes, dg1, dg2, dg3]
    # g.nodes[1:20]
    # g.nodes = [g.nodes, dg1]

    Proto.evalconstants!(g); Proto.dedup!(g); 
    Proto.tocode(g); g2 = copy(g.nodes)
    Proto.simplify!(g); 
    Proto.tocode(g)
    Proto.prune!(g); Proto.calc!(g)

    g.nodes
    Proto.tocode(g)


########### testing big func  ##########
    x = 1.5
    a = -4.
    ex = quote
        y = x * a * 1
        y2 = (x * a) + 0
        x += 1
        y3 = x * a
        y + y2 + y3 + 12
    end

    out = reversediff(ex, [:x] )

    @eval function myf(x)
            $out
            (res, dx)
        end

    myf(1.5)
    myf(1.5001)


########### testing big func 2 ##########
    x = 1.5
    y = -4.
    ex = quote
        a = x * y + exp(-sin(4x))
        b = 1 + log(-a)
        b ^ a 
    end

    out = reversediff(ex, [:x, :y])

    @eval function myf(x, y)
            $out
            (res, dx, dy)
    end
    y
    myf(1.5, -4)

    x0 = 1.5
    y0 = -4
    delta = 1e-6
    [ myf(x0,y0)[2]  (myf(x0+delta,y0)[1]- myf(x0,y0)[1])/delta ; 
        myf(x0,y0)[3]  (myf(x0,y0+delta)[1]- myf(x0,y0)[1])/delta]


##############   tests for derivation     #####################

    x = 1.5
    reversediff(:( res = sin(x)), [:x], :res)
    reversediff(:( sin(x)), [:x]) 
    reversediff(:( res = sin(x)), [:x], :y)  # fails and it's ok
    reversediff(:( res = sin(x)), [:x])  # fails and it's ok
    reversediff(:( sin(x)), [:x], :res) # fails and it's ok

    reversediff(:( res = 2^x ), [:x], :res)
    reversediff(:( 2^x ), [:x] )
    reversediff(:( res = x^2 ), [:x], :res)

    a = [1,2,3]
    reversediff(:( res = x * a[2] ), [:x], :res)
    reversediff(:( res = x * a[2] ), [:a], :res)
    reversediff(:( a[2] ), [:a])    
    reversediff(:( x*a[2] ), [:a])  
    reversediff(:( res = a[2] ), [:a], :res)

    x = 2. ; y = 1.
    reversediff(:( x + y ), [:x, :y] )
    x = zeros(2)
    reversediff(:( x[1] + x[2] ), [:x])
    x = zeros(3)
    reversediff(:( x[1]^2 + ( x[2] - 2x[3] )^4 ), [:x] )

    x = 1
    reversediff(:( (x>2) * y ), [:x, :y] )
    x = 3
    reversediff(:( (x>2) * y ), [:x, :y] )


    x, y, z = 1.1, 2.3, 1
    reversediff(:( x^2 + ( y - 2z )^4 ), [:x, :y, :z] )

    x = [1.,2,3] ; a = [3.,4,4]
    out = reversediff(:( sum( a .* x) ), [:x] ) # lourd mais juste
    out = reversediff(:( sum( a .* x) ), [:x, :a] ) # lourd mais juste
    @eval test2(x) = ( $out ; (res, dx))
    test2(x)

    a
    reversediff(:( sum(a*x') ), [:x] )

##############   tests for composite types    #####################

    type Test1
        x
        y
    end

    a = Test1(1,2)

    x = 1.5
    Proto.type_decl(Test1, 2)
    Proto.@type_decl Main.Test1 2  # fails

    reversediff(:( sin(x * a.x)), [:x])
    reversediff(:( x * a.x), [:x])
    reversediff(:( x * a.x), [:a])

    norm(t::Test1) = t.x*t.x + t.y*t.y
    norm(a)
    Proto.@deriv_rule norm(t::Main.Test1) t    [ 2*t.x*ds , 2*t.y*ds ]

    out = reversediff( :( norm(a) ), [:a] )

    @eval function myf(a)
            $out
            (res, da)
        end

    myf(a)
    myf(Test1(3,3))


############ higher order  ndiff #####################

    function ndiff(ex, order::Int, paramsym::Symbol, outsym=nothing)
        # ex = :( 2^x ) ; paramsym = [:x] ; outsym = nothing
        g, d, exitnode = Proto.tograph(ex)
        (outsym != nothing) && !haskey(d, outsym) && error("can't find output var $outsym")
        (outsym == nothing) && (exitnode == nothing) && error("can't identify expression's output")
        
        (exitnode, outsym) = outsym == nothing ? (exitnode, :res) : ( d[outsym], outsym) 

        ndict = { outsym => exitnode, :exitnode => exitnode}
        Proto.splitnary!(g)
        Proto.dedup!(g, ndict)
        Proto.simplify!(g, ndict)
        Proto.prune!(g, ndict)
        Proto.evalsort!(g)

        for i in 1:order
            Proto.calc!(g)
            dg, dnodes = Proto.reversegraph(g, ndict[:exitnode], [paramsym])
            g = [g, dg]
            ndict[ Proto.dprefix("$i$paramsym") ] = dnodes[1]
            ndict[ :exitnode ] = dnodes[1]

            Proto.splitnary!(g)
            Proto.dedup!(g, ndict)
            Proto.evalconstants!(g)
            Proto.simplify!(g, ndict)
            Proto.prune!(g, ndict)
            Proto.evalsort!(g)

            exitnode = dnodes[1]
        end
        #  (g2, length(g2))
        delete!(ndict, :exitnode)
        Proto.tocode(g, ndict)
    end

    a = 1.5
    ndiff(:( sin(x) ), 14, :x) 
    ex = ndiff(:( exp(-x*x) ), 3, :x) 

    @eval function bar(x)
                    $ex
                    (res, d1x, d2x, d3x)
            end

            
    bar(1.0)
    bar(0.1)

    # check that d(bar)/dx is correct
    [ bar(1.0)[2] (bar(1.001)[1]-bar(1.)[1]) / 0.001 ]

################## for loops  #######################

    module Proto
        include("src/reverse/proto.jl")
        include("src/reverse/proto_rules.jl")
        include("src/reverse/graph_funcs.jl")
        include("src/reverse/reversegraph.jl")
        include("src/reverse/graph_code.jl")
    end

    ex = :( acc = 0. ; for i in 1:10 ; acc += b[i] ; end ; acc  )
    dump(ex)
    g, d, outsym = Proto.tograph(ex)
    g
    d
    dump(:( for i in 1:10 ; a = a + b[i] ; end )) 


################### testing graph-code conversion for refs & dots  ###################
    module Proto
        include("src/reverse/proto.jl")
        include("src/reverse/graph_funcs.jl")
        include("src/reverse/reversegraph.jl")
        include("src/reverse/graph_code.jl")
        include("src/reverse/proto_rules.jl")
    end

    function trans(ex)
        g, d, exitnode = Proto.tograph(ex)
        g.exitnodes = { :out => exitnode }

        Proto.splitnary!(g)
        Proto.dedup!(g)
        Proto.evalconstants!(g)
        Proto.simplify!(g)
        Proto.prune!(g)

        println(g.nodes)
        Proto.tocode(g)
    end

    trans(:( a[2] ))
    trans(:( y = a[2] ; y ))
    trans(:( y = a[2] ; y[1] ))
    trans(:( y[1] = a[2] ; y[1] ))
    trans(:( y = a+1 ; y[2]+y[1] ))
    trans(:( a[2] = x ; a[3] )) 
    trans(:( a[2] = x ; y=a[3] ; y ))  
    trans(:( b = a ; b[2] = x; 1 + b[2] ))
    trans(:( b = a ; b[2] = x; 1 + b[1] ))
    trans(:( a[1] + a[2] ))

    trans(:( a.x ))
    trans(:( y = a.x ; y ))
    trans(:( y = a.x + 1 ; y.b + y.c ))
    trans(:( a.x = x ; a[3] )) 
    trans(:( a.x = x ; y = a.y ; y ))  
    trans(:( b = a ; b.x = x ; 1 + b.y ))
    trans(:( a.x + a.y ))
