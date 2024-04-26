require Hok
Hok.defmodule Reduce do
  include CAS
  defh soma(x,y) do
    x + y
  end

  defk reduce(ref4, a, f,n) do

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
    while (i != 0 ) do  ###&& tid < n) do
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
def replicate(n, x), do: for _ <- 1..n, do: x
end

{n, _} = Integer.parse(Enum.at(System.argv, 0))

#list = [Enum.to_list(1..n)]

list = [Reduce.replicate(n,1)]

vet1 = Matrex.new(list)
vet2 = Matrex.new([[0]])

threadsPerBlock = 256
blocksPerGrid = div(n + threadsPerBlock - 1, threadsPerBlock)
numberOfBlocks = blocksPerGrid
IO.puts blocksPerGrid



prev = System.monotonic_time()


ref1=Hok.new_gmatrex(vet1)
ref2=Hok.new_gmatrex(vet2)

Hok.spawn(&Reduce.reduce/4,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[ref2, ref1, &Reduce.soma/2,n])
Hok.synchronize()

result_gpu = Hok.get_gmatrex(ref2)
result = result_gpu[1]

next = System.monotonic_time()

IO.puts "Hok\t#{n}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"

result_elixir = Matrex.sum(vet1)
IO.puts "Resultado Elixir: #{result_elixir}, resultado Hok: #{result}"
