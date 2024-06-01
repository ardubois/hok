require Hok
Hok.defmodule Comp do
  deft map2_xy_kernel gmatrex ~> gmatrex ~> gmatrex ~> integer ~> [gmatrex ~> gmatrex ~> integer] ~> unit
  defk map2_xy_kernel(a1,a2,r,size,f) do
    var int id = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      r[id] = f(a1,a2,id)
    end
  end
  def map2_xy(t1,t2,size,func) do
      threadsPerBlock = 128;
      numberOfBlocks = div(size + threadsPerBlock - 1, threadsPerBlock)
      Hok.spawn(&Comp.map2_xy_kernel/5,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[t1,t2,size,func])
  end

  def comp_xy_2arrays(a1,a2,size,func) do

    result_gpu =Hok.new_gmatrex(1,size)
    a1_gpu = Hok.new_gmatrex(a1)
    a2_gpu = Hok.new_gmatrex(a2)

    Comp.map2_xy(a1,a2,size,func)

    r_gpu = Hok.get_gmatrex(result_gpu)
    r_gpu
  end

def replicate(n, x), do: (for _ <- 1..n, do: x)
end

Hok.include [Comp]


size = 10000

a1 = Matrex.new([Comp.replicate(size,1)])

a2 = Matrex.new([Comp.replicate(size,2)])

prev = System.monotonic_time()

#result = Comp.comp(array, Hok.hok (fn (a) ->  a + 10.0 end))

result = Hok.gpufor x<- 0..size, a1,a2 do: a1[i] + a2[i]

next = System.monotonic_time()

IO.puts "Hok\t#{size}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"

IO.inspect result