require Hok

Hok.defmodule GPUDP do

  defk dot_product(ref4, a, b, n) do

  type ref4 :matrex

  __shared__ cache[256]

  tid = threadIdx.x + blockIdx.x * blockDim.x;
  cacheIndex = threadIdx.x
  temp = 0.0

  while (tid < n) do
    temp = a[tid] * b[tid] + temp
    tid = blockDim.x * gridDim.x + tid
  end

  cache[cacheIndex] = temp
  __syncthreads()

  i = blockDim.x/2
  while (i != 0) do
    if (cacheIndex < i) do
      cache[cacheIndex] = cache[cacheIndex + i] + cache[cacheIndex]
    end
    __syncthreads()
    i = i/2
  end

  if (cacheIndex == 0) do
    #ref4[blockIdx.x] = cache[0]
    atomicAdd(ref4,cache[0])
  end

end
def replicate(n, x), do: for _ <- 1..n, do: x
end

Hok.include [GPUDP]


{n, _} = Integer.parse(Enum.at(System.argv, 0))

#list = [Enum.to_list(1..n)]

list = [GPUDP.replicate(n,1)]

vet1 = Matrex.new(list)
vet2 = Matrex.new(list)
vet3 = Matrex.new([[0]])

threadsPerBlock = 256
blocksPerGrid = div(n + threadsPerBlock - 1, threadsPerBlock)
numberOfBlocks = blocksPerGrid
IO.puts blocksPerGrid



prev = System.monotonic_time()


ref1=Hok.new_gmatrex(vet1)
ref2=Hok.new_gmatrex(vet2)
ref3=Hok.new_gmatrex(vet3)

Hok.spawn(&GPUDP.dot_product/4,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[ref3, ref1,ref2,n])
Hok.synchronize()

result_gpu = Hok.get_gmatrex(ref3)
result = result_gpu[1]

next = System.monotonic_time()

IO.puts "Hok\t#{n}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"

result_elixir = Matrex.sum(Matrex.multiply(vet1,vet2))
IO.puts "Resultado Elixir: #{result_elixir}, resultado Hok: #{result}"
