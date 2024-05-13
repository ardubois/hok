require Hok
Hok.defmodule PMap do
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
end

Hok.include [PMap]

n = 10000000

list = [Enum.to_list(1..n)]

vet1 = Matrex.new(list)
vet2 = Matrex.new(list)
ref1= Hok.new_gmatrex(vet1)
ref2 = Hok.new_gmatrex(vet2)
ref3= Hok.new_gmatrex(1,n)

#map=Hok.load(&PMap.map2/4)

threadsPerBlock = 128;
numberOfBlocks = div(n + threadsPerBlock - 1, threadsPerBlock)


prev = System.monotonic_time()

Hok.spawn(&PMap.map2/4,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[ref1,ref2,ref3,n, Hok.hok (fn (x,y) -> type x float; type y float; return 10*x+y end)])
#Hok.synchronize()

next = System.monotonic_time()
IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"

result = Hok.get_gmatrex(ref3)
IO.inspect result
