require Hok
Hok.defmodule Comp do

  #defh soma(x,y) do
  #  x + y
  #end

  defk map_kernel(a1,r,size,f) do
    id = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      r[id] = f(a1[id])
    end
  end
  def map(t1,t2,size,func) do
      threadsPerBlock = 128;
      numberOfBlocks = div(size + threadsPerBlock - 1, threadsPerBlock)
      Hok.spawn(&Comp.map_kernel/4,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[t1,t2,size,func])
  end

  def comp(array,func) do
    {_l,size} = Matrex.size(array)

    result_gpu =Hok.new_gmatrex(1,size)
    array_gpu = Hok.new_gmatrex(array)

    Comp.map(array_gpu, result_gpu, size,func)

    r_gpu = Hok.get_gmatrex(result_gpu)
    r_gpu
  end

def replicate(n, x), do: (for _ <- 1..n, do: x)
end

Hok.include [Comp]


size = 10000

array = Matrex.new([Comp.replicate(size,1)])


prev = System.monotonic_time()

#result = Comp.comp(array, Hok.hok (fn (a) ->  a + 10.0 end))

result = Hok.gpufor x<- array,  do: x + 10.0

next = System.monotonic_time()

IO.puts "Hok\t#{size}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"

IO.inspect result
