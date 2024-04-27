require Hok
Hok.defmodule Comp do

  #defh soma(x,y) do
  #  x + y
  #end

  defk map_2kernel(a1,a2,a3,size,f) do
    var id int = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      a3[id] = f(a1[id],a2[id])
    end
  end
  def map2(t1,t2,t3,size,func) do
      threadsPerBlock = 128;
      numberOfBlocks = div(size + threadsPerBlock - 1, threadsPerBlock)
      Hok.spawn(&PMap2.map_2kernel/5,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[t1,t2,t3,size,func])
  end

  def comp(array,func) do
    size = Matrex.size(array)

    indices_gpu = Hok.new_gmatrex([0..(size-1)])

    result_gpu =Hok.new_gmatrex(size)
    array_gpu = Hok.new_gmatrex(array)

    Comp.map2(array_gpu, indices_gpu, result_gpu,func)

    r_gpu = Hok.get_gmatrex(result_gpu)
    r_gpu
  end
def replicate(n, x), do: (for _ <- 1..n, do: x)
end

size = 10000

array = Matrex.new([Comp.replicate(size,1)])


prev = System.monotonic_time()

result = Comp.comp(array, Hok.hok fn a i -> a[i] + i end)

next = System.monotonic_time()

IO.puts "Hok\t#{size}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"

IO.inspect result
