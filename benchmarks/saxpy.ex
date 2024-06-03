require Hok

Hok.defmodule PMap2 do
deft saxpy float ~> float ~> float
defh saxpy(a,b)do
    return 2*a+b
  end
  deft map_2kernel gmatrex ~> gmatrex ~> gmatrex ~> integer ~> [ float ~> float ~> float]  ~> unit
  defk map_2kernel(a1,a2,a3,size,f) do
    var id int = blockIdx.x * blockDim.x + threadIdx.x
    var stride int = blockDim.x * gridDim.x;

    for i in range(id,size,stride) do
      if(id < size) do
       a3[id] = f(a1[id],a2[id])
      end
    end
  end
  def map2(t1,t2,t3,size,func) do
      threadsPerBlock = 256;
      numberOfBlocks = 1024;
     # numberOfBlocks = div(size + threadsPerBlock - 1, threadsPerBlock)
      Hok.spawn(Hok.lt(&PMap2.map_2kernel/5),{numberOfBlocks,1,1},{threadsPerBlock,1,1},[t1,t2,t3,size,func])
  end
end

Hok.include [PMap2]

[arg] = System.argv()

n = String.to_integer(arg)


vet1 = Matrex.new(1, n, fn -> :rand.uniform() end)
vet2 = Matrex.new(1, n, fn -> :rand.uniform() end)

prev = System.monotonic_time()

ref1= Hok.new_gmatrex(vet1)
ref2 = Hok.new_gmatrex(vet2)
ref3= Hok.new_gmatrex(1,n)




PMap2.map2(ref1,ref2,ref3,n, Hok.lt(&PMap2.saxpy/2))
#PMap2.map2(ref1,ref2,ref3,n, Hok.hok(fn (a,b) -> type a float; type b float; return 2*a+b end))
#PMap2.map2(ref1,ref2,ref3,n, Hok.hok(fn (a,b) -> 2*a+b end))

#Hok.synchronize()

_result = Hok.get_gmatrex(ref3)

next = System.monotonic_time()
IO.puts "Hok\t#{n}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"


#IO.inspect result
