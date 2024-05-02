require Hok
Hok.defmodule Ex1 do
  deft inc float ~> float
  defh inc(a)do
    return 1+a
  end
  deft transform_kernel gmatrex ~> gmatrex ~> integer ~> [ float ~> float]  ~> unit
  defk transform_kernel(a1,a2,size,f) do
    var id int = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      a2[id] = f(a1[id])
    end
  end

end

Hok.include [Ex1]

n = 10000000

list = [Enum.to_list(1..n)]

vet1 = Matrex.new(list)
vet1_gpu= Hok.new_gmatrex(vet1)
resp_gpu= Hok.new_gmatrex(1,n)

#map=Hok.load(&PMap.map2/4)

threadsPerBlock = 128;
numberOfBlocks = div(n + threadsPerBlock - 1, threadsPerBlock)


prev = System.monotonic_time()

Hok.spawn(&Ex1.transform_kernel/4,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[vet1_gpu,resp_gpu,n, &Ex1.inc/1])
#Hok.synchronize()

next = System.monotonic_time()
IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"

result = Hok.get_gmatrex(result_gpu)
IO.inspect result
