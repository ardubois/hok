require Hok
Hok.defmodule GPUDP do

  defk dot_product(ref4, a, n) do

  __shared__ cache[256]

  tid = threadIdx.x + blockIdx.x * blockDim.x;
  cacheIndex = threadIdx.x
  temp = 0.0

  while (tid < n) do
    temp = a[tid]  + temp
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
    #ef4[blockIdx.x] = cache[0]
    #atomicAdd(ref4,cache[0])
  end

end
def replicate(n, x), do: for _ <- 1..n, do: x

end

{n, _} = Integer.parse(Enum.at(System.argv, 0))

list = [GPUDP.replicate(n,1)]

vet1 = Matrex.new(list)
#vet2 = Matrex.new(list)
vet3 = Matrex.new([GPUDP.replicate(10,0)])

threadsPerBlock = 256
blocksPerGrid = div(n + threadsPerBlock - 1, threadsPerBlock)
numberOfBlocks = blocksPerGrid


prev = System.monotonic_time()

kernel=Hok.load(&GPUDP.dot_product/4)

ref1=Hok.new_gmatrex(vet1)
#ref2=Hok.new_gmatrex(vet2)
ref3=Hok.new_gmatrex(vet3)

Hok.spawn(kernel,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[ref3, ref1,n])
Hok.synchronize()

resultreal = Hok.get_gmatrex(ref3)
s = Matrex.sum(resultreal)
IO.inspect s
next = System.monotonic_time()
IO.inspect(resultreal)
IO.puts "Hok\t#{n}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"