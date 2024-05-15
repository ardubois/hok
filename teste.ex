require Hok

Hok.defmodule PMap2 do
  deft saxpy float ~> float ~> float
  defh saxpy(a,b)do
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
        Hok.spawn(&PMap2.map_2kernel/5,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[t1,t2,t3,size,func])
    end
  end

  Hok.spawn(&PMap2.map_2kernel/5,[:a,:b,:c],1,1)
