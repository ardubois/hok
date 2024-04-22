require Hok
Hok.defmodule PMap2 do
  deft sum float ~> float ~> float
  defh sum(a,b)do
    return a+b
  end
  deft map2 gmatrex ~> gmatrex ~> gmatrex ~> integer ~> [ float ~> float ~> float]  ~> unit
  defk map2(a1,a2,a3,size,f) do
    var id int = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      a3[id] = f(a1[id],a2[id])
    end
  end
  def inc(x), do: x + 1
end


IO.puts PMap2.inc(10)
PMap2.sum(1,2)
