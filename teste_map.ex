require Hok
Hok.defmodule PMap do
  deft inc float ~> float
  defh inc(a)do
    return 1*a
  end
  deft map_ske gmatrex ~> gmatrex ~> integer ~> [ float ~> float]  ~> unit
  defk map_ske(a1,a2,size,f) do
    var id int = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      a2[id] = f(a1[id])
    end
  end
  deft sum float ~> float ~> float
  defh sum(a,b)do
    return a+b
  end
  deft map2_ske gmatrex ~> gmatrex ~> gmatrex ~> integer ~> [ float ~> float ~> float]  ~> unit
  defk map2_ske(a1,a2,a3,size,f) do
    var id int = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      a3[id] = f(a1[id],a2[id])
    end
  end
  def map2(v1,v2,f) do
    {_l,size} = Hok.gmatrex_size(v1)
    threadsPerBlock = 128;
    numberOfBlocks = div(size + threadsPerBlock - 1, threadsPerBlock)
    result_gpu =Hok.new_gmatrex(1,size)

    Hok.spawn(&PMap.map2_ske/5,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[v1,v2,result_gpu,size, f])
    result_gpu
  end
end

Hok.include [PMap]

n = 100000000

list = [Enum.to_list(1..n)]

vet1 = Matrex.new(list)
vet2 = Matrex.new(list)
ref1= Hok.new_gmatrex(vet1)
ref2 = Hok.new_gmatrex(vet2)


prev = System.monotonic_time()

result = PMap.map2(ref1,ref2,Hok.lt &PMap.sum/2)

#result = PMap.map2(ref1,ref2, Hok.hok fn (x,y) -> x + y end)

next = System.monotonic_time()
IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"

result = Hok.get_gmatrex(result)
IO.inspect result
