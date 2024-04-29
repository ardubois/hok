require Hok

Hok.defmodule DP do
include CAS
#deft saxpy float ~> float ~> float
defh mult(a,b)do
    a*b
  end
defh sum(a,b), do: a+ b

  #deft map_2kernel gmatrex ~> gmatrex ~> gmatrex ~> integer ~> [ float ~> float ~> float]  ~> unit
  defk map_2kernel(a1,a2,a3,size,f) do
    var id int = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      a3[id] = f(a1[id],a2[id])
    end
  end
  def map2(t1,t2,func) do


      {_r,{_l,size}} = t1
      result_gpu =Hok.new_gmatrex(1,size)

      threadsPerBlock = 256;
      numberOfBlocks = div(size + threadsPerBlock - 1, threadsPerBlock)

      Hok.spawn(&DP.map_2kernel/5,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[t1,t2,result_gpu,size,func])

      Hok.synchronize()

      result_gpu
  end
  def reduce(ref4,  f) do

      {_r,{_l,size}} = ref4
      result_gpu =Hok.new_gmatrex(Matrex.new([[0]]))


      threadsPerBlock = 256
      blocksPerGrid = div(size + threadsPerBlock - 1, threadsPerBlock)
      numberOfBlocks = blocksPerGrid
      Hok.spawn(&DP.reduce_kernel/4,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[ref4, result_gpu, f, size])
      result_gpu
  end
  defk reduce_kernel(a, ref4, f,n) do

    __shared__ cache[256]

    tid = threadIdx.x + blockIdx.x * blockDim.x;
    cacheIndex = threadIdx.x

    temp =0.0

    if (tid < n) do
      temp = a[tid]
      tid = blockDim.x * gridDim.x + tid
    end

    while (tid < n) do
      temp = f(a[tid], temp)
      tid = blockDim.x * gridDim.x + tid
    end

    cache[cacheIndex] = temp
      __syncthreads()

    i = blockDim.x/2
    #tid = threadIdx.x + blockIdx.x * blockDim.x;
    up = blockDim.x * gridDim.x *256
    while (i != 0 &&  (cacheIndex + up)< n) do  ###&& tid < n) do
      #tid = blockDim.x * gridDim.x + tid
      if (cacheIndex < i) do
        cache[cacheIndex] = f(cache[cacheIndex + i] , cache[cacheIndex])
      end

    __syncthreads()
    i = i/2
    end

  if (cacheIndex == 0) do
    current_value = ref4[0]
    while(!(current_value == atomic_cas(ref4,current_value,f(cache[0],current_value)))) do
      current_value = ref4[0]
    end
  end

  end
  def replicate(n, x), do: (for _ <- 1..n, do: x)
end

Hok.include DP

n = 10000000

#list = [Enum.to_list(1..n)]

list = [DP.replicate(n,1)]

vet1 = Matrex.new(list)
vet2 = Matrex.new(list)

ref1= Hok.new_gmatrex(vet1)
ref2 = Hok.new_gmatrex(vet2)


prev = System.monotonic_time()

#PMap2.map2(ref1,ref2,ref3,n, &PMap2.saxpy/2)
#PMap2.map2(ref1,ref2,ref3,n, Hok.hok(fn (a,b) -> type a float; type b float; return 2*a+b end))
#PMap2.map2(ref1,ref2,ref3,n, Hok.hok(fn (a,b) -> a*b end))

#IO.inspect ref1
#raise "hell"

#result_gpu = ref1
#    |> DP.map2(ref2, &DP.mult/2)
#    |> DP.reduce(&DP.sum/2)

result_gpu = ref1
    |> DP.map2(ref2, Hok.hok fn (a,b) -> a * b end)
    |> DP.reduce(Hok.hok fn (a,b) -> a + b end)



result = Hok.get_gmatrex(result_gpu)


next = System.monotonic_time()
IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"

IO.inspect result
