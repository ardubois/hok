defmodule PMap2 do
  import Hok
  deft saxpy float ~> float ~> float
  deff saxpy(a,b)do
    return 2*a+b
  end
  deft map_2kernel gmatrex ~> gmatrex ~> gmatrex ~> integer ~> [ float ~> float ~> float]  ~> unit
  defk map_2kernel(a1,a2,a3,size,f) do
    var id int = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      a3[id] = f(a1[id],a2[id])
    end
  end
  def map2(t1,t2,t3,size,func) do
      threadsPerBlock = 128;
      numberOfBlocks = div(size + threadsPerBlock - 1, threadsPerBlock)
      Hok.spawn(&map_2kernel,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[t1,t2,t3,size,func])
  end
end

n = 10000000

list = [Enum.to_list(1..n)]

vet1 = Matrex.new(list)
vet2 = Matrex.new(list)

ref1= Hok.new_gmatrex(vet1)
ref2 = Hok.new_gmatrex(vet2)
ref3= Hok.new_gmatrex(1,n)


prev = System.monotonic_time()

PMap2.map2(ref1,ref2,ref3,n, &PMap2.saxpy/2)
#Hok.synchronize()

next = System.monotonic_time()
IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"

result = Hok.get_gmatrex(ref3)
IO.inspect result
