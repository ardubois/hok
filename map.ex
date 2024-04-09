defmodule PMap do
  import Hok
  deft inc float ~> float
  deff inc(a)do
    return 1+a
  end
  deft map gmatrex ~> gmatrex ~> integer ~> [ float ~> float]  ~> unit
  defk map(a1,a2,size,f) do
    var id int = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      a2[id] = f(a1[id])
    end
  end
end


n = 10000000

list = [Enum.to_list(1..n)]

vet1 = Matrex.new(list)
ref1= Hok.new_gmatrex(vet1)
ref2= Hok.new_gmatrex(1,n)

map=GPotion.load(&PMap.map/4)

threadsPerBlock = 128;
numberOfBlocks = div(n + threadsPerBlock - 1, threadsPerBlock)


prev = System.monotonic_time()

Hok.spawn(map,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[ref1,ref2,n, Hok.load_fun(&Map.inc/1)])
Hok.synchronize()

next = System.monotonic_time()
IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"

result = Hok.get_gmatrex(ref3)
IO.inspect result
