# testing new converter method

using Base: Test


module  Alone1 # CloudGraphs equivalence
  import Base: convert
  export UsrType, PackedUsrType, convert, encoder, decoder

  abstract UsrType
  abstract PackedUsrType

  # heavy lift encode and decode dispatch methods==
  # Name conversion, prepend "Packed" convention. Can probably relax further.
  convert{P <: PackedUsrType, T}(::Type{P}, v::T) =
          getfield(T.name.module, Symbol("Packed$(T.name.name)"))

  convert{T <: UsrType, PT}(::Type{T}, ::PT) =
          getfield(PT.name.module, Symbol(string(PT.name.name)[7:end]))

  function encoder(t)
    println("[Alone1]: trying to pack outside type by conversion")
    @show packedusrtype = convert(PackedUsrType, t) # get the outside user packed type
    packeddata = convert(packedusrtype, t)    # do packing to outside
  end
  function decoder(t)
    println("[Alone1]: trying to unpack outside type by conversion")
    @show usrtype = convert(UsrType, t) # get the outside user packed type
    usrdata = convert(usrtype, t)    # do packing to outside
  end

end


module Alone2  # RoME/IIF equivalence
  import Base: convert

  export T1, PackedT1, convert

  # user defines type T1
  type T1
    a::Float64   # very comlicated type protobuf does not immediately understand
  end
  type PackedT1
    pa::Float64   # something protobuf can serialize
  end
  # user defince simple back and forth conversion of specialized type, will become auto macro later
  function convert(::Type{PackedT1}, v::T1)
    println("[Alone2]: user packing T1") # gets called from Alone1
    PackedT1(v.a)
  end
  function convert(::Type{T1}, v::PackedT1)
    println("[Alone2]: user unpacking PackedT1")
    T1(v.pa)
  end

  # Same for user type T2 & PackedT2
end


module Combined # Caesar equivalence
  using Alone1, Alone2

  export T1, PackedT1
  export dopacking, fetchdata

  function dopacking(v)
    encoder(v) # call into Alone1
  end

  function fetchdata(pv)
    decoder(pv)
  end

end


println("test dispatch of packing converters")

using Combined

var = T1(-1.0)

pvar = dopacking(var)
@show var.a, pvar.pa

@test var.a == pvar.pa


println("test dispatch of un-packing converters")

uvar = fetchdata(pvar)

@test uvar.a == pvar.pa
@test uvar.a == var.a






# Juno.breakpoint(@__FILE__, 18)











#
