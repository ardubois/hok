require Hok
Hok.defmodule Ex1 do
  #deft square float ~> float
  defh square(x)do
     x*x
  end
  #deft apply_k gmatrex ~> gmatrex ~> integer ~> [ float ~> float]  ~> unit
  defk apply_k(a,r,size,f) do
   id   = blockIdx.x * blockDim.x + threadIdx.x
   if(id < size) do
      r[id] = f(a[id])
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

Hok.spawn(&Ex1.apply_k/4,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[vet1_gpu,resp_gpu,n, &Ex1.square/1])
#Hok.synchronize()

next = System.monotonic_time()
IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"

result = Hok.get_gmatrex(resp_gpu)
IO.inspect result
