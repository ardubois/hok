defmodule PMap2 do
  import Hok
  deft saxpy float ~> float ~> float
  deff saxpy(a,b)do
    return 2*a+b
  end
  deft map2 gmatrex ~> gmatrex ~> gmatrex ~> integer ~> [ float ~> float ~> float]  ~> unit
  defk map2(a1,a2,a3,size,f) do
    var id int = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      a3[id] = f(a1[id],a2[id])
    end
  end
end

n = 10000000

list = [Enum.to_list(1..n)]

vet1 = Matrex.new(list)
vet2 = Matrex.new(list)
ref1= Hok.new_gmatrex(vet1)
ref2 = Hok.new_gmatrex(vet2)
ref3= Hok.new_gmatrex(1,n)

map=Hok.load(&PMap2.map2/4)

threadsPerBlock = 128;
numberOfBlocks = div(n + threadsPerBlock - 1, threadsPerBlock)

prev = System.monotonic_time()

Hok.spawn(map,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[ref1,ref2,ref3,n, Hok.load_fun(&PMap2.saxpy/2)])
#Hok.synchronize()

next = System.monotonic_time()
IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"

result = Hok.get_gmatrex(ref3)
IO.inspect result
